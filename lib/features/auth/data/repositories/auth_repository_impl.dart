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
  AuthRepositoryImpl({
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

  /// Prevents concurrent duplicate /auth/me calls when the same flow
  /// (sign-in or restore) triggers it more than once.
  Future<AuthSession>? _updateMeInFlight;

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
    await _switchable?.useSession(persistent: request.rememberMe);

    // A failed write is not fatal: the resident is signed in for this launch,
    // they just have to sign in again after a restart. It is not logged, because
    // anything logged here would describe a live session.
    await _tokens.writeTokens(result.tokens);

    // Synchronize the authenticated user's latest profile and resident/unit
    // information with the backend and Drift (cache DB). Do not treat the
    // login response as fully authenticated until this succeeds.
    try {
      final session = await updateMe();
      return session.copyWith(rememberMe: request.rememberMe);
    } catch (_) {
      // The session is not fully established until /auth/me succeeds.
      // The tokens are kept so a temporary failure can be retried on
      // restart, but the controller will not navigate to the dashboard.
      rethrow;
    }
  }

  @override
  Future<AuthSession> updateMe() async {
    if (_updateMeInFlight != null) {
      return await _updateMeInFlight!;
    }
    _updateMeInFlight = _updateMeImpl();
    try {
      return await _updateMeInFlight!;
    } finally {
      _updateMeInFlight = null;
    }
  }

  Future<AuthSession> _updateMeImpl() async {
    // `/auth/me` is the only source of an authenticated profile. A cached copy
    // is written for other features, but it is never read back here to stand in
    // for a successful validation.
    final user = await _remote.updateMe();
    try {
      await _cache?.save(
        key: 'auth.me',
        accountKey: user.id.toString(),
        payload: user.toJson(),
      );
    } on Object {
      // Caching is a local convenience and must not turn a successful API
      // request into a failure.
    }
    return AuthSession(
      username: user.name,
      displayName: user.displayName,
      rememberMe: true,
      user: user,
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) => _remote.changePassword(
    oldPassword: oldPassword,
    newPassword: newPassword,
  );

  @override
  Future<void> signOut() async {
    final tokens = await _tokens.readTokens();
    if (tokens != null && tokens.refreshToken.isNotEmpty) {
      try {
        // The app has no durable device id yet, and the backend accepts an
        // empty string until notification devices are linked to sign-out.
        await _remote.logout(refreshToken: tokens.refreshToken, deviceId: '');
      } on Object {
        // Signing out locally must succeed even when the backend is
        // unreachable; the refresh token is cleared below either way.
      }
    }
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
      // A network-level failure, timeout, or server error says nothing about the
      // tokens: the resident must not be signed out because the backend is
      // temporarily unreachable. The tokens are kept and only the non-sensitive
      // remembered details are loaded, marked unverified, so the caller can
      // retry `/auth/me` without asking for credentials again.
      //
      // Only a failure that proves the session is invalid ends it.
      final transient =
          error is ApiException &&
          (error.isRetryable || error.kind == ApiFailureKind.server);
      if (transient) {
        return _restoreFromStorage();
      }
      return await _endSession();
    }
  }

  /// Builds an unverified result from the locally remembered details.
  ///
  /// Used only when the server is temporarily unreachable. It carries no
  /// [AuthUser], deliberately: remembered details can explain the state to the
  /// resident, but they are not proof of authentication and must not populate
  /// the shared session.
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
