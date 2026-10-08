import '../../domain/entities/appearance_preference.dart';
import '../../domain/repositories/appearance_repository.dart';
import '../datasources/appearance_local_data_source.dart';

class AppearanceRepositoryImpl implements AppearanceRepository {
  const AppearanceRepositoryImpl(this.localDataSource);

  final AppearanceLocalDataSource localDataSource;

  @override
  Future<AppearancePreference> getPreference() =>
      localDataSource.getPreference();

  @override
  Future<AppearancePreference> savePreference(
    AppearancePreference preference,
  ) => localDataSource.savePreference(preference);

  @override
  Future<AppearancePreference> resetPreference() =>
      localDataSource.resetPreference();
}