import '../entities/appearance_preference.dart';
import '../repositories/appearance_repository.dart';

class AppearanceUseCases {
  const AppearanceUseCases(this.repository);

  final AppearanceRepository repository;

  Future<String?> getActiveAccountId() => repository.getActiveAccountId();

  Future<void> setActiveAccount(String accountId) =>
      repository.setActiveAccount(accountId);

  Future<void> clearActiveAccount() => repository.clearActiveAccount();

  Future<AppearancePreference?> getPreference(String accountId) =>
      repository.getPreference(accountId);

  Future<bool> hasPendingSync(String accountId) =>
      repository.hasPendingSync(accountId);

  Future<AppearancePreference> savePreference(
    String accountId,
    AppearancePreference preference, {
    bool markPendingSync = false,
  }) => repository.savePreference(
    accountId,
    preference,
    markPendingSync: markPendingSync,
  );

  Future<AppearancePreference> resetPreference(String accountId) =>
      repository.resetPreference(accountId);
}
