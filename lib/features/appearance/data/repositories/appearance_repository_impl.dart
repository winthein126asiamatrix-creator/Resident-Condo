import '../../../../core/network/user_preferences_remote_data_source.dart';
import '../../domain/entities/appearance_preference.dart';
import '../../domain/repositories/appearance_repository.dart';
import '../datasources/appearance_local_data_source.dart';

class AppearanceRepositoryImpl implements AppearanceRepository {
  const AppearanceRepositoryImpl(
    this.localDataSource, {
    this.preferencesRemote,
  });

  final AppearanceLocalDataSource localDataSource;
  final UserPreferencesRemoteDataSource? preferencesRemote;

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

    // The local write is what keeps startup fast and the UI responsive. The
    // backend call is made by the controller only when the colour itself
    // changed, so brightness-only saves never reach /me/preferences.
    return stored;
  }

  @override
  Future<void> updateThemeColor(String hexColor) async {
    final remote = preferencesRemote;
    if (remote == null) {
      // No network layer in a local-only test or a pre-ApiBinding context.
      return;
    }
    await remote.updateThemeColor(hexColor);
  }

  @override
  Future<AppearancePreference> resetPreference(String accountId) =>
      localDataSource.resetPreference(accountId);
}
