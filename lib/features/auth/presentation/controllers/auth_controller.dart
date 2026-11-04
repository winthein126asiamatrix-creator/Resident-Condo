import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test/app/routes/app_routes.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/super_print.dart';
import '../../../../core/widgets/authenticated_avatar.dart';
import '../../../appearance/presentation/controllers/appearance_controller.dart';
import '../../../notifications/data/datasources/notification_remote_data_source.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../data/models/auth_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/usecases/auth_usecases.dart';

class AuthController extends GetxController {
  AuthController(this.useCases);

  final AuthUseCases useCases;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  /// Whether the resident asked to stay signed in across restarts.
  ///
  /// On by default: the Sign In form ships the checkbox ticked, and opting out
  /// is a deliberate untick rather than a setting nobody reads.
  final rememberMe = true.obs;

  /// True from the first tap until the attempt settles. Every submit path is
  /// gated on it, which is what stops a double tap from sending two requests.
  final isSubmitting = false.obs;

  /// True while a stored session is being checked on startup.
  ///
  /// The splash reads this to keep the dashboard off screen until the answer
  /// arrives, rather than flashing it and then bouncing to login.
  final isRestoring = false.obs;

  /// True while `/auth/me` is loading the authenticated profile.
  ///
  /// The home shell uses this to keep protected content off screen between
  /// saving the login tokens and receiving the resident's profile.
  final isInitializingSession = false.obs;

  /// The reason the current-user request failed, for the home shell's retry UI.
  ///
  /// A temporary failure leaves the tokens in place, so retrying does not ask
  /// the resident for their password again.
  final sessionInitializationError = RxnString();

  /// Identifies the credential session these controller operations belong to.
  int _sessionEpoch = 0;

  /// Shares one `/auth/me` call between concurrent initialization callers.
  Future<AuthSession?>? _currentUserInFlight;

  /// A sign-in failure, shown above the form. Distinct from a per field
  /// validation error: this one means the credentials were rejected.
  final errorMessage = RxnString();

  /// True while the change-password request is in flight.
  final isChangingPassword = false.obs;

  /// The backend's reason for rejecting a password change.
  final changePasswordError = RxnString();

  /// True while an avatar replacement is being uploaded.
  final isUploadingAvatar = false.obs;

  /// The reason the last avatar upload failed, when it did.
  final avatarUploadError = RxnString();

  /// True while the editable profile fields are being saved.
  final isUpdatingProfile = false.obs;

  /// The reason the last profile update failed, when it did.
  final profileUpdateError = RxnString();

  final isPasswordVisible = false.obs;

  /// The field currently being corrected, so the screen can move focus to the
  /// first thing that needs attention.
  final RxnString invalidField = RxnString();

  /// The username from a remembered session, so the login form can offer it back
  /// without ever holding on to a password.
  String? rememberedUsername;

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  void toggleRememberMe([bool? value]) {
    rememberMe.value = value ?? !rememberMe.value;
  }

  /// Clears the error as soon as the resident starts fixing it, rather than
  /// leaving a stale "wrong password" under a field they have just corrected.
  void onFieldChanged(String _) {
    if (errorMessage.value != null) {
      errorMessage.value = null;
    }
    invalidField.value = null;
  }

  Future<AuthSession?> signIn() async {
    if (isSubmitting.value) {
      return null;
    }

    final username = usernameController.text.trim();
    final password = passwordController.text;

    final fieldError = validate(username: username, password: password);
    if (fieldError != null) {
      invalidField.value = fieldError.field;
      errorMessage.value = null;
      return null;
    }

    invalidField.value = null;
    isSubmitting.value = true;
    errorMessage.value = null;
    // A new credential session invalidates any profile request or restore still
    // in flight for the previous account.
    _sessionEpoch++;
    _currentUserInFlight = null;
    isInitializingSession.value = false;
    sessionInitializationError.value = null;
    isUnverified.value = false;
    isRestoring.value = false;
    isUpdatingProfile.value = false;
    profileUpdateError.value = null;
    // A new sign-in must never inherit the previous account's in-memory user,
    // even if the login screen was reached without going through sign-out.
    if (Get.isRegistered<SessionController>()) {
      Get.find<SessionController>().clearSession();
    }
    try {
      final session = await useCases.signIn(
        SignInRequest(
          username: username,
          password: password,
          rememberMe: rememberMe.value,
        ),
      );
      final remembered = session.copyWith(rememberMe: rememberMe.value);
      await useCases.persistSession(remembered);
      passwordController.clear();
      // Login is complete once the tokens are saved. The authenticated profile
      // is loaded separately by fetchCurrentUser.
      return remembered;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'We could not sign you in. Please try again.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Loads `/auth/me` and publishes the complete user to the shared session.
  ///
  /// This is deliberately separate from [signIn]: credentials are already
  /// authenticated by the time this runs, and a temporary profile failure must
  /// not send the resident back to the login form.
  Future<AuthSession?> fetchCurrentUser({bool force = false}) {
    final inFlight = _currentUserInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    if (!force) {
      final currentUser = _sessionUser;
      if (currentUser != null) {
        // A valid session is already established; there is nothing to fetch.
        return Future<AuthSession?>.value(
          AuthSession(
            username: currentUser.name,
            displayName: currentUser.displayName,
            rememberMe: rememberMe.value,
            user: currentUser,
          ),
        );
      }
    }

    final epoch = _sessionEpoch;
    final future = _fetchCurrentUser(epoch);
    late final Future<AuthSession?> tracked;
    tracked = future.whenComplete(() {
      if (identical(_currentUserInFlight, tracked)) {
        _currentUserInFlight = null;
      }
    });
    _currentUserInFlight = tracked;
    return tracked;
  }

  Future<AuthSession?> _fetchCurrentUser(int epoch) async {
    isInitializingSession.value = true;
    sessionInitializationError.value = null;
    try {
      final session = await useCases.fetchCurrentUser();
      if (epoch != _sessionEpoch) {
        return null;
      }
      final remembered = session.copyWith(rememberMe: rememberMe.value);
      await useCases.persistSession(remembered);
      if (epoch != _sessionEpoch) {
        return null;
      }
      await adoptIntoSession(remembered);
      if (epoch != _sessionEpoch) {
        return null;
      }
      isUnverified.value = false;
      return remembered;
    } on AppException catch (error) {
      if (epoch != _sessionEpoch) {
        return null;
      }
      // Placing the message on the controller keeps the tokens: the resident can
      // retry without re-entering credentials.
      sessionInitializationError.value = error.message;
      return null;
    } catch (_) {
      if (epoch != _sessionEpoch) {
        return null;
      }
      sessionInitializationError.value =
          'We could not load your profile. Please try again.';
      return null;
    } finally {
      if (epoch == _sessionEpoch) {
        isInitializingSession.value = false;
      }
    }
  }

  AuthUser? get _sessionUser {
    if (!Get.isRegistered<SessionController>()) {
      return null;
    }
    return Get.find<SessionController>().currentUser;
  }

  /// Saves the editable profile fields and publishes the updated user.
  ///
  /// Only values that differ from the current user are sent. The returned user
  /// is merged into the shared session, then persisted, so the profile,
  /// dashboard and remembered sign-in details all see the same record without
  /// losing the avatar or any other unrelated field.
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    if (isUpdatingProfile.value) {
      return false;
    }
    final currentUser = _sessionUser;
    if (currentUser == null) {
      profileUpdateError.value = 'profileUpdateFailed'.tr;
      return false;
    }

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phone.trim();
    final changes = <String, Object?>{};
    if (trimmedName != currentUser.name) {
      changes['name'] = trimmedName;
    }
    if (trimmedPhone != currentUser.phone) {
      changes['phone'] = trimmedPhone;
    }
    if (trimmedEmail != (currentUser.email?.trim() ?? '')) {
      changes['email'] = trimmedEmail;
    }
    if (changes.isEmpty) {
      profileUpdateError.value = null;
      return true;
    }

    final epoch = _sessionEpoch;
    isUpdatingProfile.value = true;
    profileUpdateError.value = null;
    try {
      final updated = await useCases.updateProfile(
        currentUser: currentUser,
        changes: changes,
      );
      if (epoch != _sessionEpoch) {
        return false;
      }
      final session = AuthSession(
        username: updated.name,
        displayName: updated.displayName,
        rememberMe: rememberMe.value,
        user: updated,
      );
      await useCases.persistSession(session);
      if (epoch != _sessionEpoch) {
        return false;
      }
      await adoptIntoSession(session);
      return true;
    } on AppException catch (error) {
      if (epoch == _sessionEpoch) {
        profileUpdateError.value = _profileUpdateMessage(error);
      }
      return false;
    } catch (_) {
      if (epoch == _sessionEpoch) {
        profileUpdateError.value = 'profileUpdateFailed'.tr;
      }
      return false;
    } finally {
      if (epoch == _sessionEpoch) {
        isUpdatingProfile.value = false;
      }
    }
  }

  String _profileUpdateMessage(AppException error) {
    if (error is ApiException) {
      final status = error.statusCode;
      if (status == 400 ||
          status == 422 ||
          error.kind == ApiFailureKind.validation) {
        return 'profileUpdateInvalid'.tr;
      }
      if (error.kind == ApiFailureKind.network ||
          error.kind == ApiFailureKind.timeout) {
        return 'profileUpdateNetworkError'.tr;
      }
      if (error.kind == ApiFailureKind.server) {
        return 'profileUpdateServerError'.tr;
      }
    }
    return 'profileUpdateFailed'.tr;
  }

  /// Changes the password without disturbing the current session.
  ///
  /// Returns whether the backend accepted the change. The reason for a
  /// rejection is left in [changePasswordError] so the dialog can show it
  /// without closing and losing what the resident typed.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (isChangingPassword.value) {
      return false;
    }
    isChangingPassword.value = true;
    changePasswordError.value = null;
    superPrint(currentPassword, title: "Hello W");
    try {
      await useCases.changePassword(
        oldPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on AppException catch (error) {
      changePasswordError.value = error.message;
      return false;
    } catch (_) {
      changePasswordError.value =
          'We could not change your password. Please try again.';
      return false;
    } finally {
      isChangingPassword.value = false;
    }
  }

  /// Uploads a replacement avatar and refreshes the canonical profile.
  ///
  /// The upload endpoint's success body is not part of the confirmed contract,
  /// so `/me` remains the source of the resident record. The avatar cache is
  /// dropped as soon as the upload succeeds, which also refreshes a URL-stable
  /// Odoo avatar without appending cache-busting query parameters.
  Future<bool> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) async {
    if (isUploadingAvatar.value) {
      return false;
    }
    isUploadingAvatar.value = true;
    avatarUploadError.value = null;
    try {
      await useCases.uploadAvatar(
        filePath: filePath,
        filename: filename,
        mimeType: mimeType,
      );
      invalidateAuthenticatedAvatarCache();
      // A refresh failure must not turn an accepted upload into a failure; the
      // image widget has already been told to reload the new bytes.
      await fetchCurrentUser(force: true);
      return true;
    } on AppException catch (error) {
      avatarUploadError.value = error.message;
      return false;
    } catch (_) {
      avatarUploadError.value = 'photoUpdateFailed'.tr;
      return false;
    } finally {
      isUploadingAvatar.value = false;
    }
  }

  Future<void> signOut() async {
    // Invalidate any /auth/me request still in flight. Its response may arrive
    // later, but it now belongs to the session that has just ended.
    _sessionEpoch++;
    _currentUserInFlight = null;
    isInitializingSession.value = false;
    sessionInitializationError.value = null;
    isUnverified.value = false;
    isRestoring.value = false;
    isUpdatingProfile.value = false;
    profileUpdateError.value = null;
    await _releaseDevice();
    try {
      await useCases.signOut();
    } finally {
      // Tokens are gone at this point (or the repository failed); either way the
      // previous resident's in-memory profile must not remain accessible.
      if (Get.isRegistered<SessionController>()) {
        Get.find<SessionController>().clearSession();
      }
      invalidateAuthenticatedAvatarCache();
      await _resetAppearance();
    }
  }

  /// Removes this device's token and its cached notifications.
  ///
  /// Never throws: a sign-out has to succeed even when the backend is
  /// unreachable, so the token is left to expire server-side instead.
  Future<void> _releaseDevice() async {
    try {
      if (Get.isRegistered<FirebaseService>()) {
        final token = Get.find<FirebaseService>().deviceToken.value;
        if (token != null &&
            token.isNotEmpty &&
            Get.isRegistered<NotificationRemoteDataSource>()) {
          await Get.find<NotificationRemoteDataSource>().unregisterDeviceToken(
            token,
          );
        }
      }
      if (Get.isRegistered<NotificationController>()) {
        await Get.find<NotificationController>().clearDeviceHistory();
      }
    } catch (error) {
      superPrint('Device cleanup did not complete: $error', title: 'Auth');
    }
  }

  final isUnverified = false.obs;

  Future<AuthSession?> restoreSession() async {
    final epoch = _sessionEpoch;
    isRestoring.value = true;
    try {
      final restored = await useCases.restoreSession();
      // A login or logout started while the restore was in flight owns the
      // session now; the stale result must not change it.
      if (epoch != _sessionEpoch) {
        return null;
      }
      isUnverified.value = restored?.unverified ?? false;
      if (restored != null) {
        rememberedUsername = restored.username;
        // The password is never remembered, only offered as a starting point.
        usernameController.text = restored.username;
      } else {
        if (Get.isRegistered<SessionController>()) {
          Get.find<SessionController>().clearSession();
        }
        await _resetAppearance();
      }
      return restored;
    } finally {
      if (epoch == _sessionEpoch) {
        isRestoring.value = false;
      }
    }
  }

  Future<void> revalidateSession() async {
    final epoch = _sessionEpoch;
    final restored = await useCases.restoreSession();
    if (epoch != _sessionEpoch) {
      return;
    }
    if (restored == null) {
      if (Get.isRegistered<SessionController>()) {
        Get.find<SessionController>().clearSession();
      }
      isUnverified.value = false;
      await _resetAppearance();
      if (Get.currentRoute != AppRoutes.login) {
        Get.offAllNamed(AppRoutes.login);
      }
      return;
    }
    isUnverified.value = restored.unverified;
    // A transient failure leaves the already established session untouched; it
    // must not be replaced with the remembered (unverified) details.
    if (restored.unverified) {
      return;
    }
    await adoptIntoSession(restored);
  }

  /// Publishes the authenticated user to the shared session.
  ///
  /// Only a complete [AuthUser] from `/auth/me` may establish a session. A
  /// remembered name on its own is never promoted into an authenticated user.
  Future<void> adoptIntoSession(AuthSession session) async {
    final user = session.user;
    final verifiedUser = user is AuthUser && !session.unverified ? user : null;
    if (Get.isRegistered<SessionController>()) {
      final controller = Get.find<SessionController>();
      if (verifiedUser != null) {
        controller.setSession(verifiedUser);
      } else if (!session.unverified) {
        // A transient restore is not proof that the current session is invalid.
        // Only a confirmed absence of a user may clear it.
        controller.clearSession();
      }
    }
    if (verifiedUser != null) {
      // Device registration and theme seeding are authenticated side effects.
      _prepareNotifications();
      await _applyAppearance(verifiedUser);
    }
  }

  /// Seeds the app theme from the authenticated user's `/auth/me` record.
  ///
  /// The account id scopes the local cache, and the backend colour is applied
  /// only when it is valid; a missing or malformed value leaves the user's
  /// cached preference (or the default) in place.
  Future<void> _applyAppearance(AuthUser user) async {
    if (!Get.isRegistered<AppearanceController>()) {
      return;
    }
    final accountId = user.id > 0 ? user.id.toString() : user.name;
    if (accountId.isEmpty) {
      return;
    }
    await Get.find<AppearanceController>().applyAuthenticatedUser(
      accountId: accountId,
      backendThemeColor: user.themeColor,
    );
  }

  Future<void> _resetAppearance() async {
    if (!Get.isRegistered<AppearanceController>()) {
      return;
    }
    await Get.find<AppearanceController>().onSignedOut();
  }

  void _prepareNotifications() {
    if (!Get.isRegistered<FirebaseService>()) {
      return;
    }
    final firebase = Get.find<FirebaseService>();
    unawaited(_registerDeviceToken(firebase));
  }

  Future<void> _registerDeviceToken(FirebaseService firebase) async {
    try {
      await firebase.onResidentSignedIn();
      final token = firebase.deviceToken.value;
      if (token == null || token.isEmpty) {
        return;
      }
      final remote = Get.isRegistered<NotificationRemoteDataSource>()
          ? Get.find<NotificationRemoteDataSource>()
          : null;
      if (remote == null) {
        return;
      }
      await remote.registerDeviceToken(token, platform: _devicePlatform());
    } catch (error) {
      superPrint(
        'Device token registration did not complete: $error',
        title: 'Auth',
      );
    }
  }

  /// `android` or `ios`, the two platforms this app ships to.
  static String _devicePlatform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Validates the form, returning the first problem or null when it is valid.
  ///
  /// Exposed so the page can bind it to the `Form` and show errors as the
  /// resident leaves a field, which is friendlier than validating only on
  /// submit.
  AuthValidationError? validate({
    required String username,
    required String password,
  }) {
    if (username.isEmpty) {
      return const AuthValidationError('username', 'Enter your username.');
    }
    if (password.isEmpty) {
      return const AuthValidationError('password', 'Enter your password.');
    }
    return null;
  }
}

/// A validation problem, and which field it belongs to.
class AuthValidationError {
  const AuthValidationError(this.field, this.message);

  /// Either `username` or `password`.
  final String field;
  final String message;
}
