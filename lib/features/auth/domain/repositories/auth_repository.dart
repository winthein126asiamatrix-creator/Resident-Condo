import '../../../../core/errors/app_exception.dart';
import '../entities/auth_session.dart';

/// Sign-in, sign-out and the remembered session.
abstract interface class AuthRepository {
  /// Verifies [request] against the backend and stores the returned tokens.
  ///
  /// Throws an [AppException] with a resident-readable message when the
  /// credentials are wrong, so the screen never has to interpret a failure
  /// shape of its own.
  Future<AuthSession> signIn(SignInRequest request);

  /// The signed-in resident, validated against the backend.
  ///
  /// Throws when the session cannot be recovered, including when the stored
  /// tokens are absent or have expired past refreshing.
  Future<AuthSession> currentSession();

  /// Ends the current session: tokens and remembered details both cleared.
  Future<void> signOut();

  /// The session restored from storage, or null when the resident never signed
  /// in on this device.
  ///
  /// Storage alone is not enough to trust: the tokens are checked against
  /// `/auth/me` so an expired session sends the resident to the login screen
  /// instead of into a dashboard that would fail on its first request.
  Future<AuthSession?> restoreSession();

  /// Persists or clears the remembered session depending on [rememberMe].
  Future<void> persistSession(AuthSession session);
}