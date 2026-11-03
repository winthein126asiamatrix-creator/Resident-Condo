import '../../domain/entities/appearance_preference.dart';
import '../../domain/repositories/appearance_repository.dart';
import '../datasources/appearance_local_data_source.dart';

class AppearanceRepositoryImpl implements AppearanceRepository {
  const AppearanceRepositoryImpl(this.localDataSource);

  final AppearanceLocalDataSource localDataSource;

  @override
  Future<String?> getActiveAccountId() => localDataSource.getActiveAccountId();

  @override
  Future<void> setActiveAccount(String accountId) =>
      localDataSource.setActiveAccount(accountId);

  @override
  Future<void> clearActiveAccount() => localDataSource.clearActiveAccount();

  @override
  Future<AppearancePreference?> getPreference(String accountId) =>
      localDataSource.getPreference(accountId);

  @override
  Future<bool> hasPendingSync(String accountId) =>
      localDataSource.hasPendingSync(accountId);

  @override
  Future<AppearancePreference> savePreference(
    String accountId,
    AppearancePreference preference, {
    bool markPendingSync = false,
  }) async {
    final stored = await localDataSource.savePreference(
      accountId,
      preference,
      markPendingSync: markPendingSync,
    );

    // TODO(appearance-api): The backend update endpoint is not ready yet. When
    // its contract is confirmed, call ApiEndPoints.appearance here with this
    // preference and clear the pending-sync flag only after the request
    // succeeds. Do not call it before then: the local write above is what keeps
    // startup fast, and the backend stays the source of truth for the next
    // successful /auth/me.
    return stored;
  }

  @override
  Future<AppearancePreference> resetPreference(String accountId) =>
      localDataSource.resetPreference(accountId);
}
