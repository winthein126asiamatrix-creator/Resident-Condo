import '../entities/appearance_preference.dart';

/// The resident's appearance preference.
abstract interface class AppearanceRepository {
  /// The saved preference, or the shipped default when nothing is stored.
  Future<AppearancePreference> getPreference();

  /// Persists [preference] and returns what was stored.
  Future<AppearancePreference> savePreference(AppearancePreference preference);

  /// Restores the shipped default and returns it.
  Future<AppearancePreference> resetPreference();
}