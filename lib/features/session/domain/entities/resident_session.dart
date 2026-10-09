import '../../../../core/models/resident_role.dart';

/// Lightweight mock of the signed-in resident session.
///
/// A real backend would return these values from the Odoo res.users / partner
/// record. Keeping it in one place lets every feature render role aware UI.
class ResidentSession {
  const ResidentSession({
    required this.name,
    required this.role,
    required this.tower,
    required this.unitNumber,
    required this.email,
    required this.phone,
  });

  final String name;
  final ResidentRole role;
  final String tower;
  final String unitNumber;
  final String email;
  final String phone;

  String get unitLabel => '$tower · $unitNumber';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  ResidentSession copyWith({ResidentRole? role, String? name, String? email}) {
    return ResidentSession(
      name: name ?? this.name,
      role: role ?? this.role,
      tower: tower,
      unitNumber: unitNumber,
      email: email ?? this.email,
      phone: phone,
    );
  }
}
