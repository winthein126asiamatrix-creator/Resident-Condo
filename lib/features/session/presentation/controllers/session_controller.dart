import 'package:get/get.dart';

import '../../../../core/models/resident_role.dart';
import '../../domain/entities/resident_session.dart';

/// Holds the active resident session so every feature can render
/// role-aware UI (owner / tenant / resident) without duplicating auth code.
class SessionController extends GetxController {
  final session = const ResidentSession(
    name: 'Alex Johnson',
    role: ResidentRole.owner,
    tower: 'Tower A',
    unitNumber: '1205',
    email: 'alex.johnson@example.com',
    phone: '+959772611100',
  ).obs;

  ResidentRole get role => session.value.role;

  String get name => session.value.name;

  String get unitLabel => session.value.unitLabel;

  bool get isOwner => session.value.role.managesLease;

  bool get isTenant => session.value.role.paysRent;

  void switchRole(ResidentRole next) {
    if (session.value.role == next) {
      return;
    }
    session.value = session.value.copyWith(role: next);
  }

  /// Adopts the name from a successful sign-in, so the greeting on the
  /// dashboard and the name on the profile match the account just used. The
  /// rest of the demo session stays as it is: this build has a single unit.
  void signInAs(String displayName) {
    if (displayName.trim().isEmpty || session.value.name == displayName) {
      return;
    }
    session.value = session.value.copyWith(name: displayName);
  }
}
