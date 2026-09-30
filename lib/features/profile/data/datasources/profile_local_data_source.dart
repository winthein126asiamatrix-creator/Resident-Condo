import '../../domain/entities/profile.dart';
import '../models/profile_model.dart';

class ProfileLocalDataSource {
  ProfileModel _profile = const ProfileModel(
    name: 'Alex Johnson',
    email: 'alex.johnson@example.com',
    phone: '+959772611100',
    unit: 'Tower A · 1205',
    role: 'Owner',
    initials: 'AJ',
    language: 'English',
    notificationsEnabled: true,
  );

  Future<ProfileModel> getProfile() async {
    return _profile;
  }

  Future<ProfileModel> updateProfile(Profile profile) async {
    _profile = ProfileModel(
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      unit: profile.unit,
      role: profile.role,
      initials: profile.initials,
      language: profile.language,
      notificationsEnabled: profile.notificationsEnabled,
    );
    return _profile;
  }
}
