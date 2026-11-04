import '../../../../core/errors/app_exception.dart';
import '../../data/models/auth_user.dart';
import '../entities/auth_session.dart';

/// Sign-in, sign-out and the remembered session.
abstract interface class AuthRepository {
  /// Verifies [request] against the backend and stores the returned tokens.
  ///
  /// This is credential authentication only. The returned session proves the
  /// tokens were saved but carries no [AuthUser]; call [fetchCurrentUser] to
  /// load the resident's profile.
  ///
  /// Throws an [AppException] with a resident-readable message when the
  /// credentials are wrong, so the screen never has to interpret a failure
  /// shape of its own.
  Future<AuthSession> signIn(SignInRequest request);

  /// Loads the signed-in resident from `/auth/me`.
  ///
  /// Throws when the profile cannot be loaded. Temporary failures leave the
  /// stored tokens untouched so the caller can retry.
  Future<AuthSession> fetchCurrentUser();

  /// The signed-in resident, validated against the backend.
  ///
  /// Kept as an alias of [fetchCurrentUser] for existing callers.
  Future<AuthSession> updateMe();

  /// Updates the signed-in resident's editable profile fields.
  ///
  /// Only [changes] entries are sent. The returned user keeps every field the
  /// backend did not include in its response.
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    required Map<String, Object?> changes,
  });

  /// Changes the signed-in resident's password.
  ///
  /// The active session is left untouched: changing a password does not
  /// invalidate the resident's own access token.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// Uploads a replacement avatar for the signed-in resident.
  ///
  /// The endpoint's success body is not part of the contract, so callers that
  /// need canonical profile data should refresh `/me` after this completes.
  Future<void> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  });

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
