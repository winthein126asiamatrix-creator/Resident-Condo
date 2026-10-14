import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/session_token_storage.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_user.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required TokenStorage tokenStorage,
    ApiCacheStore? cacheStore,
  }) : _remote = remoteDataSource,
       _local = localDataSource,
       _tokens = tokenStorage,
       _cache = cacheStore;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final TokenStorage _tokens;
  final ApiCacheStore? _cache;

  /// The registered store when it is the switchable one, null otherwise.
  ///
  /// Null in tests that register a plain [TokenStorage] fake, which then keeps
  /// the behaviour it had before Remember Me existed.
  SessionTokenStorage? get _switchable =>
      _tokens is SessionTokenStorage ? _tokens : null;

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    // A new session must not inherit profile data from the previous account.
    await _cache?.clearAll();
    final result = await _remote.signIn(request);

    // Remember Me decides where the pair is allowed to live, and it has to be
    // decided before the write: an in-memory-only sign-in must not leave a
    // pair persisted by an earlier remembered one behind, or the next launch
    // would restore a session this sign-in was told not to keep.
    await _switchable?.useSession(persistent: request.rememberMe);

    // A failed write is not fatal: the resident is signed in for this launch,
    // they just have to sign in again after a restart. It is not logged, because
    // anything logged here would describe a live session.
    await _tokens.writeTokens(result.tokens);

    return AuthSession(
      username: result.user.username,
      displayName: result.user.displayName,
      rememberMe: request.rememberMe,
      user: result.user,
    );
  }

  @override
  Future<AuthSession> updateMe() async {
    const cacheKey = 'auth.me';
    try {
      final user = await _remote.updateMe();
      try {
        await _cache?.save(
          key: cacheKey,
          accountKey: user.id.toString(),
          payload: user.toJson(),
        );
      } on Object {
        // Caching is a local convenience and must not turn a successful API
        // request into a failure.
      }
      return AuthSession(
        username: user.username,
        displayName: user.displayName,
        rememberMe: true,
        user: user,
      );
    } on ApiException catch (error) {
      // Transport-level failures may still allow a stale-but-usable profile read
      // from SQLite. 401/403 are handled by the refresh interceptor and never
      // reach here; only genuine server/network failures are considered offline.
      if (!error.isRetryable) {
        rethrow;
      }
      final cached = await _cache?.read(cacheKey);
      if (cached == null) {
        rethrow;
      }
      try {
        final user = AuthUser.fromJson(
          jsonDecode(cached.payloadJson) as Map<String, dynamic>,
        );
        return AuthSession(
          username: user.username,
          displayName: user.displayName,
          rememberMe: true,
          user: user,
        );
      } on Object {
        rethrow;
      }
    }
  }

  @override
  Future<void> signOut() async {
    // Tokens first, so an interruption between the two cannot leave a usable
    // credential behind for a session the resident believes they have ended.
    await _tokens.clearTokens();
    await _local.signOut();
    // Profile cache is private to the signed-out account and must not survive.
    await _cache?.clearAll();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final tokens = await _tokens.readTokens();

    if (tokens == null) {
      // No tokens at all: there is nothing to validate and no reason to spend a
      // request discovering that.
      await _local.signOut();
      return null;
    }

    try {
      // Validates the session. If the access token has expired, the refresh
      // interceptor renews it and replays this request before it returns, so an
      // expiry is invisible here and only a genuine failure surfaces.
      final session = await updateMe();
      await _local.persistSession(session);
      return session;
    } on AppException catch (error) {
      // A network-level failure says nothing about the session. The tokens are
      // still held and the server simply cannot be reached right now, so ending
      // the session here would sign the resident out for being offline. The
      // stored details are used instead and the session is marked unverified
      // until the server is reachable again.
      //
      // Only a failure that is not retryable is treated as real: the server
      // answered, so what it answered with stands.
      final unreachable = error is ApiException && error.isRetryable;
      if (unreachable) {
        return _restoreFromStorage();
      }
      return await _endSession();
    }
  }

  /// Builds a session from the locally remembered details.
  ///
  /// Used only when the server is unreachable, so the resident is let in on
  /// tokens they already hold rather than on the server's word.
  Future<AuthSession> _restoreFromStorage() async {
    final remembered = await _local.restoreSession();
    if (remembered != null) {
      return remembered.copyWith(unverified: true);
    }
    // The tokens persisted but the name never did. Still better than signing
    // the resident out over a connectivity problem.
    return const AuthSession(
      username: '',
      displayName: 'Resident',
      rememberMe: true,
      unverified: true,
    );
  }

  /// Clears everything and reports no session, for a genuine rejection.
  Future<AuthSession?> _endSession() async {
    await signOut();
    return null;
  }

  @override
  Future<void> persistSession(AuthSession session) =>
      _local.persistSession(session);
}