import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this.localDataSource);

  final ProfileLocalDataSource localDataSource;

  @override
  Future<Profile> getProfile() {
    return localDataSource.getProfile();
  }

  @override
  Future<Profile> updateProfile(Profile profile) {
    return localDataSource.updateProfile(profile);
  }
}
