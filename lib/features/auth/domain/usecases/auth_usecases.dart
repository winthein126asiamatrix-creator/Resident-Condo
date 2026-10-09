import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class AuthUseCases {
  const AuthUseCases(this.repository);

  final AuthRepository repository;

  Future<AuthSession> signIn(SignInRequest request) => repository.signIn(request);

  Future<AuthSession> currentSession() => repository.currentSession();

  Future<void> signOut() => repository.signOut();

  Future<AuthSession?> restoreSession() => repository.restoreSession();

  Future<void> persistSession(AuthSession session) =>
      repository.persistSession(session);
}