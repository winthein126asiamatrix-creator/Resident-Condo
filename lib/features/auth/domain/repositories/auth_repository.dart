import '../entities/auth_session.dart';

/// Sign-in, sign-out and the remembered session.
abstract interface class AuthRepository {
  /// Verifies [request] and returns the session on success.
  ///
  /// Throws an [AppException] with a resident-readable message when the
  /// credentials are wrong, so the screen never has to interpret a failure
  /// shape of its own.
  Future<AuthSession> signIn(SignInRequest request);

  /// Ends the current session.
  Future<void> signOut();

  /// The session restored from storage, or null when the resident did not ask
  /// to be remembered, or never signed in.
  Future<AuthSession?> restoreSession();

  /// Persists or clears the remembered session depending on [rememberMe].
  Future<void> persistSession(AuthSession session);
}