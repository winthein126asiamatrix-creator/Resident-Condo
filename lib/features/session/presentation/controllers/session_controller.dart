import 'package:get/get.dart';

import '../../../../core/models/resident_role.dart';
import '../../domain/entities/resident_session.dart';

/// Holds the active resident session so every feature can render
/// role-aware UI (owner / tenant / resident) without duplicating auth code.
class SessionController extends GetxController {
  /// The demo resident shown before anyone signs in.
  static const ResidentSession _signedOut = ResidentSession(
    name: 'Alex Johnson',
    role: ResidentRole.owner,
    tower: 'Tower A',
    unitNumber: '1205',
    email: 'alex.johnson@example.com',
    phone: '+959772611100',
  );

  final session = _signedOut.obs;

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
  void signInAs(String displayName, {String? email}) {
    if (displayName.trim().isEmpty && (email == null || email.isEmpty)) {
      return;
    }
    final current = session.value;
    final name = displayName.trim().isEmpty ? current.name : displayName;
    if (current.name == name && (email == null || current.email == email)) {
      return;
    }
    session.value = current.copyWith(
      name: name,
      email: email?.isNotEmpty == true ? email : null,
    );
  }

  /// Puts the session back to its signed-out state.
  ///
  /// Logout and an unrecoverable token expiry both land here: without this the
  /// previous resident's name, email and role would stay on screen for whoever
  /// signs in next, on this device, until the process is killed.
  void clearResident() {
    session.value = _signedOut;
  }
}
