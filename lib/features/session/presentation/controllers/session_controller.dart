import 'package:get/get.dart';

import '../../../../core/models/resident_role.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../domain/entities/resident_session.dart';


class SessionController extends GetxController {
  final session = Rxn<ResidentSession>();

  bool get isAuthenticated => session.value != null;

  AuthUser? get currentUser => session.value?.user;

  ResidentSession? get current => session.value;

  ResidentRole? get role => session.value?.role;

  String get name => currentUser?.displayName ?? '';

  String get unitLabel => session.value?.unitLabel ?? '';

  bool get isOwner => role?.managesLease ?? false;

  bool get isTenant => role?.paysRent ?? false;

  bool get isSessionVerified =>
      session.value?.isSessionVerified ?? false;

  bool get isOfflineSession =>
      session.value?.isOfflineSession ?? false;

  SessionVerificationStatus? get verificationStatus =>
      session.value?.verificationStatus;

  /// Replaces the session with the complete authenticated user.
  ///
  /// Called after `/auth/me` succeeds, so the previous account's profile is
  /// replaced atomically rather than merged field by field.
  void setSession(
    AuthUser user, {
    SessionVerificationStatus verificationStatus =
        SessionVerificationStatus.verified,
  }) {
    session.value = ResidentSession(
      user: user,
      verificationStatus: verificationStatus,
    );
  }

  /// Ends the session and drops the previous resident's profile.
  void clearSession() {
    session.value = null;
  }
}
