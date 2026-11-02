import 'package:get/get.dart';

import '../../../../core/models/resident_role.dart';
import '../../domain/entities/resident_session.dart';

/// Holds the active resident session so every feature can render
/// role-aware UI (owner / tenant / resident) without duplicating auth code.
///
/// `null` is an explicit "no signed-in resident" state. It is never seeded
/// with demo data: an unauthenticated user must not look authenticated.
class SessionController extends GetxController {
  final session = Rxn<ResidentSession>();

  /// The active signed-in resident, or null when nobody is signed in.
  ResidentSession? get current => session.value;

  ResidentRole? get role => session.value?.role;

  String get name => session.value?.name ?? '';

  String get unitLabel => session.value?.unitLabel ?? '';

  bool get isOwner => session.value?.role.managesLease ?? false;

  bool get isTenant => session.value?.role.paysRent ?? false;

  void signInAs(String displayName, {String? email}) {
    final currentSession = session.value;
    final name = displayName.trim().isEmpty
        ? (currentSession?.name ?? '')
        : displayName.trim();

    if (name.isEmpty && (email == null || email.isEmpty)) {
      return;
    }

    if (currentSession == null) {
 
      session.value = ResidentSession(
        name: name.isEmpty ? 'Resident' : name,
        role: ResidentRole.resident,
        tower: '',
        unitNumber: '',
        email: email?.isNotEmpty == true ? email! : '',
        phone: '',
      );
      return;
    }
    if (currentSession.name == name &&
        (email == null || currentSession.email == email)) {
      return;
    }
    session.value = currentSession.copyWith(
      name: name.isEmpty ? currentSession.name : name,
      email: email?.isNotEmpty == true ? email : currentSession.email,
    );
  }

  /// Puts the session back to its signed-out state.
  void clearResident() {
    session.value = null;
  }
}
