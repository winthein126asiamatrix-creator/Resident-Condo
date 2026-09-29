import '../../domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
    required super.name,
    required super.email,
    required super.phone,
    required super.unit,
    required super.role,
    required super.initials,
    required super.language,
    required super.notificationsEnabled,
  });
}
