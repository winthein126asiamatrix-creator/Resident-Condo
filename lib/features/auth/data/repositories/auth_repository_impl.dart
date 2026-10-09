import '../../../../core/network/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required TokenStorage tokenStorage,
  }) : _remote = remoteDataSource,
       _local = localDataSource,
       _tokens = tokenStorage;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final TokenStorage _tokens;

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    final result = await _remote.signIn(request);

    // A failed write is not fatal: the resident is signed in for this launch,
    // they just have to sign in again after a restart. It is not logged, because
    // anything logged here would describe a live session.
    await _tokens.writeTokens(result.tokens);

    return AuthSession(
      username: result.user.username,
      displayName: result.user.displayName,
      rememberMe: false,
      user: result.user,
    );
  }

  @override
  Future<AuthSession> currentSession() async {
    final user = await _remote.currentUser();
    return AuthSession(
      username: user.username,
      displayName: user.displayName,
      rememberMe: true,
      user: user,
    );
  }

  @override
  Future<void> signOut() async {
    // Tokens first, so an interruption between the two cannot leave a usable
    // credential behind for a session the resident believes they have ended.
    await _tokens.clearTokens();
    await _local.signOut();
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
      final session = await currentSession();
      await _local.persistSession(session);
      return session;
    } catch (_) {
      // Anything that stops the session being validated ends it: tokens and
      // remembered details both, so the next launch starts clean.
      await signOut();
      return null;
    }
  }

  @override
  Future<void> persistSession(AuthSession session) =>
      _local.persistSession(session);
}