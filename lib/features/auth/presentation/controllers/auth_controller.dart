import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test/app/routes/app_routes.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/super_print.dart';
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

  /// A sign-in failure, shown above the form. Distinct from a per field
  /// validation error: this one means the credentials were rejected.
  final errorMessage = RxnString();

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
    try {
      final session = await useCases.signIn(
        SignInRequest(
          username: username,
          password: password,
          rememberMe: rememberMe.value,
        ),
      );
      final remembered = session.copyWith(
        rememberMe: rememberMe.value,
      );
      await useCases.persistSession(remembered);
      passwordController.clear();
      adoptIntoSession(remembered);
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

  Future<void> signOut() async {
    await _releaseDevice();
    await useCases.signOut();
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
    isRestoring.value = true;
    try {
      final restored = await useCases.restoreSession();
      isUnverified.value = restored?.unverified ?? false;
      if (restored != null) {
        rememberedUsername = restored.username;
        // The password is never remembered, only offered as a starting point.
        usernameController.text = restored.username;
      }
      return restored;
    } finally {
      isRestoring.value = false;
    }
  }

  Future<void> revalidateSession() async {
    final restored = await useCases.restoreSession();
    if (restored != null) {
      isUnverified.value = restored.unverified;
      adoptIntoSession(restored);
      return;
    }
    if (Get.isRegistered<SessionController>()) {
      Get.find<SessionController>().clearResident();
    }
    Get.offAllNamed(AppRoutes.login);
  }

  void adoptIntoSession(AuthSession session) {
    _prepareNotifications();
    if (!Get.isRegistered<SessionController>()) {
      return;
    }
    final controller = Get.find<SessionController>();
    final user = session.user;
    if (user is AuthUser) {
      // The backend's record is richer than a name, so the profile carries the
      // email the account actually belongs to.
      controller.signInAs(user.displayName, email: user.email);
    } else {
      controller.signInAs(session.displayName);
    }
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
