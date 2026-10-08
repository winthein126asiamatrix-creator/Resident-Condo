import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this.localDataSource);

  final AuthLocalDataSource localDataSource;

  @override
  Future<AuthSession> signIn(SignInRequest request) =>
      localDataSource.signIn(request);

  @override
  Future<void> signOut() => localDataSource.signOut();

  @override
  Future<AuthSession?> restoreSession() => localDataSource.restoreSession();

  @override
  Future<void> persistSession(AuthSession session) =>
      localDataSource.persistSession(session);
}