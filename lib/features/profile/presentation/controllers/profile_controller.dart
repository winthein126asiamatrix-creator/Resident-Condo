import 'package:get/get.dart';

import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../session/presentation/controllers/session_controller.dart';

/// Profile-specific actions and preferences.
///
/// The authenticated profile itself is not stored here. It lives in
/// [SessionController], which is the single in-memory source of truth for the
/// complete [AuthUser] returned by `/auth/me`.
class ProfileController extends GetxController {
  ProfileController(this.sessionController);

  final SessionController sessionController;

  /// The current authenticated user, or null after logout.
  AuthUser? get user => sessionController.currentUser;

  /// The resident's display unit, taken from the same session user.
  String get unitLabel => sessionController.unitLabel;

  /// A local display preference. It is not part of the `/auth/me` payload.
  final notificationsEnabled = true.obs;

  final errorMessage = RxnString();

  void toggleNotifications(bool enabled) {
    notificationsEnabled.value = enabled;
  }

  /// Updates the in-memory authenticated user while preserving every field that
  /// was not edited.
  ///
  /// There is no profile update API yet. This keeps the previous local-only
  /// edit behaviour, but writes through the session so the profile cannot
  /// diverge from what every other screen reads.
  bool updateProfile({
    required String name,
    required String email,
    required String phone,
  }) {
    final current = user;
    if (current == null) {
      errorMessage.value = 'Profile information is not available.';
      return false;
    }
    if (name.trim().isEmpty || email.trim().isEmpty || phone.trim().isEmpty) {
      errorMessage.value = 'Name, email, and phone are required.';
      return false;
    }

    errorMessage.value = null;
    sessionController.setSession(
      current.copyWith(
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
      ),
    );
    return true;
  }

  /// Re-reads `/auth/me` only when the resident explicitly refreshes.
  Future<void> refreshProfile() async {
    if (!Get.isRegistered<AuthController>()) {
      return;
    }
    await Get.find<AuthController>().revalidateSession();
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!Get.isRegistered<AuthController>()) {
      return false;
    }
    return Get.find<AuthController>().changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  String? get changePasswordError {
    if (!Get.isRegistered<AuthController>()) {
      return null;
    }
    return Get.find<AuthController>().changePasswordError.value;
  }

  Future<void> signOut() async {
    if (!Get.isRegistered<AuthController>()) {
      sessionController.clearSession();
      return;
    }
    await Get.find<AuthController>().signOut();
  }
}
