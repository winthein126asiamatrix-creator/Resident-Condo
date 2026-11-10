import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/session_token_storage.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/network/user_preferences_remote_data_source.dart';
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
    UserPreferencesRemoteDataSource? preferencesRemote,
  }) : _remote = remoteDataSource,
       _local = localDataSource,
       _tokens = tokenStorage,
       _cache = cacheStore,
       _preferences = preferencesRemote;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final TokenStorage _tokens;
  final ApiCacheStore? _cache;
  final UserPreferencesRemoteDataSource? _preferences;

  /// Identifies the current credential session.
  ///
  /// A login or logout starts a new generation. Work started for an older
  /// generation can finish later, but it must not be reused by, or written into,
  /// the new session.
  int _sessionEpoch = 0;

  /// Prevents concurrent duplicate /auth/me calls in the same session.
  Future<AuthSession>? _currentUserInFlight;

  /// The generation [_currentUserInFlight] belongs to.
  int _currentUserEpoch = -1;

  /// The registered store when it is the switchable one, null otherwise.
  ///
  /// Null in tests that register a plain [TokenStorage] fake, which then keeps
  /// the behaviour it had before Remember Me existed.
  SessionTokenStorage? get _switchable =>
      _tokens is SessionTokenStorage ? _tokens : null;

  void _startNewSession() {
    _sessionEpoch++;
    _currentUserInFlight = null;
    _currentUserEpoch = -1;
  }

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    // A credential attempt belongs to a new session; any profile request from
    // the previous one is now stale and must not be shared with it.
    _startNewSession();
    // A new session must not inherit profile data from the previous account.
    await _cache?.clearAll();
    final result = await _remote.signIn(request);
    await _switchable?.useSession(persistent: request.rememberMe);

    // A failed write is not fatal: the resident is signed in for this launch,
    // they just have to sign in again after a restart. It is not logged, because
    // anything logged here would describe a live session.
    await _tokens.writeTokens(result.tokens);

    // Login proves the credentials and establishes the token pair. It does not
    // describe the resident: the complete AuthUser comes from fetchCurrentUser.
    return AuthSession(
      username: request.username,
      displayName: request.username,
      rememberMe: request.rememberMe,
    );
  }

  @override
  Future<AuthSession> fetchCurrentUser() {
    final epoch = _sessionEpoch;
    final inFlight = _currentUserInFlight;
    if (inFlight != null && _currentUserEpoch == epoch) {
      return inFlight;
    }

    final future = _fetchCurrentUser(epoch);
    late final Future<AuthSession> tracked;
    tracked = future.whenComplete(() {
      if (identical(_currentUserInFlight, tracked)) {
        _currentUserInFlight = null;
        _currentUserEpoch = -1;
      }
    });
    _currentUserInFlight = tracked;
    _currentUserEpoch = epoch;
    return tracked;
  }

  @override
  Future<AuthSession> updateMe() => fetchCurrentUser();

  Future<AuthSession> _fetchCurrentUser(int epoch) async {
    final user = await _remote.updateMe();
    final mergedUser = await _mergePreferences(user, epoch);
    await _cacheUser(mergedUser, epoch);
    return AuthSession(
      username: mergedUser.name,
      displayName: mergedUser.displayName,
      rememberMe: true,
      user: mergedUser,
    );
  }

  /// Applies the separate preferences endpoint to a successful `/auth/me`.
  ///
  /// Preferences are a convenience, never an authentication requirement: a
  /// failed or malformed response leaves the profile exactly as `/auth/me`
  /// described it.
  Future<AuthUser> _mergePreferences(AuthUser user, int epoch) async {
    final remote = _preferences;
    if (remote == null) {
      return user;
    }
    try {
      final preferences = await remote.fetchPreferences();
      if (epoch != _sessionEpoch) {
        return user;
      }
      return AuthUser.mergeProfile(
        preferences,
        currentUser: user,
        submitted: const <String, Object?>{},
      );
    } catch (_) {
      return user;
    }
  }

  Future<void> _cacheUser(AuthUser user, int epoch) async {
    if (epoch != _sessionEpoch) {
      return;
    }
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
  }

  @override
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    required Map<String, Object?> changes,
  }) async {
    final epoch = _sessionEpoch;
    final user = await _remote.updateProfile(
      currentUser: currentUser,
      changes: changes,
    );
    await _cacheUser(user, epoch);
    return user;
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
  Future<void> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) => _remote.uploadAvatar(
    filePath: filePath,
    filename: filename,
    mimeType: mimeType,
  );

  @override
  Future<void> signOut() async {
    // A late /auth/me response from the session being ended must never be
    // adopted into the next one.
    _startNewSession();
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
    final epoch = _sessionEpoch;
    final tokens = await _tokens.readTokens();
    if (epoch != _sessionEpoch) {
      return null;
    }

    if (tokens == null) {
      // No tokens at all: there is nothing to validate and no reason to spend a
      // request discovering that.
      await _local.signOut();
      return null;
    }

    // Cache-first: tokens plus a profile cached by an earlier `/auth/me` are
    // enough to open the app immediately. The session stays explicitly
    // unverified; the caller revalidates in the background, so a slow or
    // unreachable backend never holds the splash screen.
    final cachedUser = await _cachedAuthUser();
    if (epoch != _sessionEpoch) {
      return null;
    }
    if (cachedUser != null) {
      return AuthSession(
        username: cachedUser.name,
        displayName: cachedUser.displayName,
        rememberMe: true,
        user: cachedUser,
        unverified: true,
      );
    }

    // No cached profile to show, so validation has to happen before a session
    // exists. The caller bounds this with its own timeout.
    try {
      final session = await fetchCurrentUser();
      if (epoch != _sessionEpoch) {
        return null;
      }
      try {
        await _local.persistSession(session);
      } on Object {
        // Remembering the name is a convenience; it must not fail restoration.
      }
      return session;
    } on AppException catch (error) {
      if (epoch != _sessionEpoch) {
        return null;
      }
      // A network-level failure, timeout, or server error says nothing about the
      // tokens, so they are kept. But without a cached profile there is no
      // trusted resident to show, and the caller sends them to sign in.
      if (_isTransientFailure(error)) {
        return null;
      }
      return await _endSession(epoch);
    } on Object {
      // A local read or decode failure is not proof the session is invalid.
      return null;
    }
  }

  /// True when the failure only says the server could not answer right now.
  ///
  /// Such a failure keeps the stored credentials but is not evidence that they
  /// were rejected. Only a response that proves rejection ends the session.
  static bool _isTransientFailure(AppException error) =>
      error is ApiException &&
      (error.isRetryable || error.kind == ApiFailureKind.server);

  /// Reads the cached AuthUser written by a successful `/auth/me`.
  ///
  /// Never throws: a missing, unreadable, or malformed cache entry simply means
  /// there is no cached profile to show.
  Future<AuthUser?> _cachedAuthUser() async {
    try {
      final entry = await _cache?.read('auth.me');
      if (entry == null) return null;
      final decoded = jsonDecode(entry.payloadJson);
      if (decoded is! Map) return null;
      final user = AuthUser.fromJson(Map<String, dynamic>.from(decoded));
      if (user.id <= 0) return null;
      return user;
    } on Object {
      return null;
    }
  }

  /// Clears everything and reports no session, for a genuine rejection.
  Future<AuthSession?> _endSession(int epoch) async {
    if (epoch != _sessionEpoch) {
      return null;
    }
    await signOut();
    return null;
  }

  @override
  Future<void> persistSession(AuthSession session) =>
      _local.persistSession(session);
}
