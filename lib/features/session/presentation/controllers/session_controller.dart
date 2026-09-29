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
    phone: '+1 555 014 2026',
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
}
