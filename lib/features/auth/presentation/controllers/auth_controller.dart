import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
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

  final rememberMe = false.obs;

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
        SignInRequest(username: username, password: password),
      );
      final remembered = session.copyWith(rememberMe: rememberMe.value);
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

  Future<void> signOut() => useCases.signOut();

  /// The remembered session from a previous launch, or null.
  ///
  /// Null covers both "never signed in" and "the stored session could not be
  /// validated", which for the resident means the same thing: sign in again.
  Future<AuthSession?> restoreSession() async {
    isRestoring.value = true;
    try {
      final restored = await useCases.restoreSession();
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

  /// Makes the rest of the app know who signed in.
  ///
  /// Features read the resident from [SessionController], which does not know
  /// about auth on its own, so a sign-in (or a restored session) only takes
  /// effect once it is handed over here.
  void adoptIntoSession(AuthSession session) {
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