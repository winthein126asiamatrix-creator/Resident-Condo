import '../entities/appearance_preference.dart';

/// The resident's appearance preference.
abstract interface class AppearanceRepository {
  /// The user whose theme was last applied, or null after a sign-out.
  Future<String?> getActiveAccountId();

  /// Remembers [accountId] as the user whose theme is currently applied.
  Future<void> setActiveAccount(String accountId);

  /// Forgets the active user, without deleting any user's saved appearance.
  Future<void> clearActiveAccount();

  /// [accountId]'s saved preference, or null when they have never chosen one.
  Future<AppearancePreference?> getPreference(String accountId);

  /// Whether [accountId] has a local change the backend has not accepted yet.
  Future<bool> hasPendingSync(String accountId);

  /// Persists [preference] for [accountId] and returns what was stored.
  Future<AppearancePreference> savePreference(
    String accountId,
    AppearancePreference preference, {
    bool markPendingSync = false,
  });

  /// Removes [accountId]'s saved appearance and returns the shipped default.
  Future<AppearancePreference> resetPreference(String accountId);
}
