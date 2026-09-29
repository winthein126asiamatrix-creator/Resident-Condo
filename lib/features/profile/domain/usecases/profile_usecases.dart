import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class ProfileUseCases {
  const ProfileUseCases(this.repository);

  final ProfileRepository repository;

  Future<Profile> getProfile() {
    return repository.getProfile();
  }

  Future<Profile> updateProfile(Profile profile) {
    return repository.updateProfile(profile);
  }
}
