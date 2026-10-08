import '../entities/appearance_preference.dart';
import '../repositories/appearance_repository.dart';

class AppearanceUseCases {
  const AppearanceUseCases(this.repository);

  final AppearanceRepository repository;

  Future<AppearancePreference> getPreference() => repository.getPreference();

  Future<AppearancePreference> savePreference(AppearancePreference preference) =>
      repository.savePreference(preference);

  Future<AppearancePreference> resetPreference() =>
      repository.resetPreference();
}