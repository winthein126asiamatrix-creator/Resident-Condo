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

/// Drives the login screen.
///
/// Two things this deliberately does not do: it never stores the password, and
/// it never navigates. Returning a result and letting the page decide keeps the
/// controller testable and stops a failed attempt from leaving the resident on
/// a screen they did not ask for.
///
/// Token refresh deliberately lives in the network layer, not here. This
/// controller asks for the signed-in resident and gets either one or an error,
/// so there is no second copy of the refresh rules to keep in step.
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

  /// Validates and attempts a sign-in.
  ///
  /// Returns the session on success, or null when validation failed or the
  /// credentials were rejected, in which case [errorMessage] explains why.
  Future<AuthSession?> signIn() async {
    // A second tap while the first is still in flight is ignored rather than
    // queued, so the resident never ends up signed in twice.
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
        displayName: "Win Thein",
      );
      await useCases.persistSession(remembered);
      // Cleared as soon as the attempt lands, so a password never lingers in
      // memory after the resident is through with it.
      passwordController.clear();
      // The rest of the app reads the resident from SessionController, so a
      // sign-in only takes effect once it knows who walked in.
      adoptIntoSession(remembered);
      return remembered;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      passwordController.clear();
      return null;
    } catch (_) {
      errorMessage.value = 'We could not sign you in. Please try again.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Ends the session, after telling the backend to stop pushing to this device.
  ///
  /// Unregistering first is the order that matters: it needs the access token,
  /// which [AuthUseCases.signOut] is about to discard. A device left registered
  /// after sign-out would keep receiving the previous resident's push
  /// notifications.
  ///
  /// The cached notifications go at the same time, so the next resident to sign
  /// in on this device does not see this one's history.
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

  /// True while the session is known only locally, because the server could not
  /// be reached when it was last checked.
  ///
  /// The resident is in the app on tokens they already hold, not on the
  /// server's word, so [revalidateSession] asks again once it is reachable.
  final isUnverified = false.obs;

  /// The remembered session from a previous launch, or null.
  ///
  /// Null means the resident has to sign in again: either nothing was stored, or
  /// the server rejected what was stored. A session the server could not be
  /// reached to check is *not* null — it is returned with [AuthSession.unverified]
  /// set, so the resident is not signed out for being offline.
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

  /// Re-runs the session check now that the backend is reachable.
  ///
  /// Only worth calling when [isUnverified] is set: a session the server has
  /// already said yes to needs no second opinion, and asking again would spend
  /// a request the resident did not trigger.
  ///
  /// Nothing happens when the server is *still* unreachable — the repository
  /// hands back another unverified session and the resident stays put. A null
  /// result means the server has now refused the session, so the repository has
  /// already cleared it and the resident is sent back to sign in.
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

  /// Makes the rest of the app know who signed in.
  ///
  /// Features read the resident from [SessionController], which does not know
  /// about auth on its own, so a sign-in (or a restored session) only takes
  /// effect once it is handed over here.
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

  /// Asks for notification permission and fetches the FCM token, once there is
  /// a resident to notify.
  ///
  /// This is the single point every sign-in path goes through — a restored
  /// session from the splash, a fresh sign-in, and a session revalidated on
  /// reconnect — so the prompt appears behind an authenticated resident and
  /// never over the splash. Fire and forget: the permission and the token are
  /// not needed for anything the resident is doing right now, so nothing here
  /// is allowed to hold up (or break) the route change that follows.
  void _prepareNotifications() {
    if (!Get.isRegistered<FirebaseService>()) {
      return;
    }
    final firebase = Get.find<FirebaseService>();
    unawaited(_registerDeviceToken(firebase));
  }

  /// Hands this device's FCM token to the backend for the signed-in resident.
  ///
  /// Runs after [FirebaseService.onResidentSignedIn] has had its chance at the
  /// token, so the token this registers is the one that was actually issued.
  /// Fire and forget and swallowed: push not being registered is not a reason for
  /// a sign-in to fail, and the resident is never shown this.
  ///
  /// The token itself is never logged.
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
