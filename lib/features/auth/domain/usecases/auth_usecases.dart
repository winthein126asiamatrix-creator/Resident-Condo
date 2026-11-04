import '../../data/models/auth_user.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class AuthUseCases {
  const AuthUseCases(this.repository);

  final AuthRepository repository;

  Future<AuthSession> signIn(SignInRequest request) =>
      repository.signIn(request);

  Future<AuthSession> fetchCurrentUser() => repository.fetchCurrentUser();

  Future<AuthSession> updateMe() => repository.updateMe();

  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    required Map<String, Object?> changes,
  }) => repository.updateProfile(currentUser: currentUser, changes: changes);

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) => repository.changePassword(
    oldPassword: oldPassword,
    newPassword: newPassword,
  );

  Future<void> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) => repository.uploadAvatar(
    filePath: filePath,
    filename: filename,
    mimeType: mimeType,
  );

  Future<void> signOut() => repository.signOut();

  Future<AuthSession?> restoreSession() => repository.restoreSession();

  Future<void> persistSession(AuthSession session) =>
      repository.persistSession(session);
}
