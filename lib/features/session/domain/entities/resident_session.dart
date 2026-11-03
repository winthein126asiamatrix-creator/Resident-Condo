import '../../../../core/models/resident_role.dart';
import '../../../auth/data/models/auth_user.dart';

/// The authenticated resident session.
///
/// Wraps the complete [AuthUser] returned by `/auth/me` rather than copying a
/// hand-picked subset of its fields. Every feature reads the same object, so a
/// profile change cannot leave one screen showing stale information.
class ResidentSession {
  const ResidentSession({required this.user});

  final AuthUser user;

  String get name => user.displayName;

  String get email => user.email ?? '';

  String get phone => user.phone;

  String? get image => user.avatarUrl;

  String get tower => user.unit?.tower ?? '';

  String get unitNumber => user.unit?.number ?? '';

  String get unitLabel {
    final label = user.unit?.label.trim() ?? '';
    if (label.isNotEmpty) return label;
    return [tower, unitNumber].where((part) => part.isNotEmpty).join(' · ');
  }

  ResidentRole get role => switch (user.role.trim().toLowerCase()) {
    'owner' => ResidentRole.owner,
    'tenant' => ResidentRole.tenant,
    _ => ResidentRole.resident,
  };

  String get initials => user.initials;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}
