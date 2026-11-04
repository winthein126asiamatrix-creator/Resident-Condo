import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/photo_picker.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../session/presentation/controllers/session_controller.dart';

/// Profile-specific actions and preferences.
///
/// The authenticated profile itself is not stored here. It lives in
/// [SessionController], which is the single in-memory source of truth for the
/// complete [AuthUser] returned by `/auth/me`.
class ProfileController extends GetxController {
  ProfileController(
    this.sessionController, {
    PhotoPicker? photoPicker,
    this.authController,
  }) : _photoPicker = photoPicker ?? const DevicePhotoPicker();

  final SessionController sessionController;
  final PhotoPicker _photoPicker;
  final AuthController? authController;

  /// The current authenticated user, or null after logout.
  AuthUser? get user => sessionController.currentUser;

  /// The resident's display unit, taken from the same session user.
  String get unitLabel => sessionController.unitLabel;

  /// A local display preference. It is not part of the `/auth/me` payload.
  final notificationsEnabled = true.obs;

  final errorMessage = RxnString();

  final isPickingAvatar = false.obs;

  final avatarError = RxnString();

  /// True while the selected photo is being uploaded.
  bool get isUploadingAvatar => _auth?.isUploadingAvatar.value ?? false;

  AuthController? get _auth {
    final injected = authController;
    if (injected != null) {
      return injected;
    }
    return Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
  }

  /// Opens the photo library, validates the choice, and uploads it.
  ///
  /// A cancelled picker is not a failure and leaves [avatarError] untouched.
  /// Returns true only when the backend accepted the upload.
  Future<bool> pickAndUploadAvatar() async {
    if (isPickingAvatar.value || isUploadingAvatar) {
      return false;
    }

    avatarError.value = null;
    isPickingAvatar.value = true;
    PhotoPickResult result;
    try {
      result = await _photoPicker.pick(ImageSource.gallery);
    } on Object {
      avatarError.value = 'photoUpdateFailed'.tr;
      return false;
    } finally {
      isPickingAvatar.value = false;
    }

    final photo = result.photo;
    if (photo == null) {
      if (result.error != null) {
        avatarError.value = result.error;
      }
      return false;
    }

    final validationError = _validateAvatar(photo);
    if (validationError != null) {
      avatarError.value = validationError;
      return false;
    }

    final auth = _auth;
    if (auth == null) {
      avatarError.value = 'photoUpdateFailed'.tr;
      return false;
    }

    final uploaded = await auth.uploadAvatar(
      filePath: photo.path,
      filename: photo.name,
      mimeType: photo.mimeType,
    );
    if (!uploaded) {
      avatarError.value =
          auth.avatarUploadError.value ?? 'photoUpdateFailed'.tr;
    }
    return uploaded;
  }

  static const int maxAvatarBytes = 10 * 1024 * 1024;

  String? _validateAvatar(AttachedPhoto photo) {
    final mimeType = photo.mimeType?.trim().toLowerCase();
    final extension = photo.name.toLowerCase().split('.').last;
    const allowedMimeTypes = <String>{
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    };
    const allowedExtensions = <String>{'jpg', 'jpeg', 'png', 'webp'};
    final allowed = mimeType != null && mimeType.isNotEmpty
        ? allowedMimeTypes.contains(mimeType)
        : allowedExtensions.contains(extension);
    if (!allowed) {
      return 'photoUnsupported'.tr;
    }

    final size = photo.sizeBytes;
    if (size != null && size > maxAvatarBytes) {
      return 'photoTooLarge'.tr;
    }
    return null;
  }

  void toggleNotifications(bool enabled) {
    notificationsEnabled.value = enabled;
  }

  /// True while the profile API request is in flight.
  bool get isUpdatingProfile => _auth?.isUpdatingProfile.value ?? false;

  /// The latest profile update failure, for the editor to keep open.
  String? get profileUpdateError =>
      errorMessage.value ?? _auth?.profileUpdateError.value;

  /// Validates the editable profile fields before the API is called.
  static String? validateProfile({
    required String name,
    required String email,
    required String phone,
  }) {
    final nameError = validateProfileName(name);
    if (nameError != null) return nameError;
    final emailError = validateProfileEmail(email);
    if (emailError != null) return emailError;
    return validateProfilePhone(phone);
  }

  static String? validateProfileName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'profileNameRequired'.tr;
    }
    return null;
  }

  static String? validateProfileEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'profileEmailInvalid'.tr;
    }
    return null;
  }

  static String? validateProfilePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return 'profilePhoneRequired'.tr;
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^\+?[0-9][0-9 \-()]*$').hasMatch(phone) ||
        digits.length < 6 ||
        digits.length > 15) {
      return 'profilePhoneInvalid'.tr;
    }
    return null;
  }

  /// Sends the edited fields through the shared auth controller.
  ///
  /// Validation happens before the request, and the UI reads the same
  /// [isUpdatingProfile] / [profileUpdateError] pair so it can keep the editor
  /// open with the resident's values when the backend rejects the update.
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    if (isUpdatingProfile) {
      return false;
    }
    if (user == null) {
      errorMessage.value = 'profileUpdateFailed'.tr;
      return false;
    }
    final validationError = validateProfile(
      name: name,
      email: email,
      phone: phone,
    );
    if (validationError != null) {
      errorMessage.value = validationError;
      return false;
    }
    final auth = _auth;
    if (auth == null) {
      errorMessage.value = 'profileUpdateFailed'.tr;
      return false;
    }

    errorMessage.value = null;
    final updated = await auth.updateProfile(
      name: name,
      email: email,
      phone: phone,
    );
    if (!updated) {
      errorMessage.value =
          auth.profileUpdateError.value ?? 'profileUpdateFailed'.tr;
    }
    return updated;
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
