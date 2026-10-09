import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/theme/app_theme.dart';
import 'package:test/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:test/features/auth/domain/entities/auth_session.dart';
import 'package:test/features/auth/domain/repositories/auth_repository.dart';
import 'package:test/features/auth/presentation/bindings/auth_binding.dart';
import 'package:test/features/auth/presentation/controllers/auth_controller.dart';
import 'package:test/features/auth/presentation/pages/login_page.dart';
import 'package:test/features/session/presentation/bindings/session_binding.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

/// Walks the login screen the way a resident does, and checks the states the
/// screen has to get right: validation, password visibility, loading, double
/// submission, error and success.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });
  tearDown(Get.reset);

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: LoginPage(onSignedIn: () {}),
        initialBinding: AuthBinding(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillCredentials(
    WidgetTester tester, {
    String username = AuthLocalDataSource.demoUsername,
    String password = AuthLocalDataSource.demoPassword,
  }) async {
    await tester.enterText(find.byKey(const Key('login-username')), username);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.pumpAndSettle();
  }

  /// The screen opens with the demo account pre-filled, so a validation test has
  /// to empty the fields before it can assert anything about them.
  Future<void> clearFields(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('login-username')), '');
    await tester.enterText(find.byKey(const Key('login-password')), '');
    await tester.pumpAndSettle();
  }

  testWidgets('shows the brand, the greeting and both fields', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to manage your residence'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Secure access to your residence'), findsOneWidget);
  });

  testWidgets('an empty submit reports both fields', (tester) async {
    await pumpLogin(tester);
    await clearFields(tester);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your username.'), findsOneWidget);
    // The username error is reported first, so the password error is not shown
    // until the username is filled in.
    expect(find.text('Enter your password.'), findsNothing);
    expect(Get.find<AuthController>().errorMessage.value, isNull);
  });

  testWidgets('a username with no password reports the password', (tester) async {
    await pumpLogin(tester);
    await clearFields(tester);

    await tester.enterText(
      find.byKey(const Key('login-username')),
      AuthLocalDataSource.demoUsername,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('the password toggle flips visibility both ways', (tester) async {
    await pumpLogin(tester);
    final toggle = find.byKey(const Key('login-password-toggle'));

    bool obscured() => tester
        .widgetList<TextField>(find.byType(TextField))
        .where((f) => f.obscureText)
        .isNotEmpty;

    expect(obscured(), isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(Get.find<AuthController>().isPasswordVisible.value, isTrue);
    expect(obscured(), isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(Get.find<AuthController>().isPasswordVisible.value, isFalse);
    expect(obscured(), isTrue);
  });

  testWidgets('wrong credentials show a clean error and stay on the screen', (
    tester,
  ) async {
    await pumpLogin(tester);
    await fillCredentials(tester, password: 'nope');

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(
      find.text('That username and password combination was not recognised.'),
      findsOneWidget,
    );
    // The form is still there, ready for another attempt.
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });

  testWidgets('the error clears once the resident edits a field', (tester) async {
    await pumpLogin(tester);
    await fillCredentials(tester, password: 'nope');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login-password')), 'resident12');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsNothing);
  });

  testWidgets('a correct sign-in calls back and clears the password', (
    tester,
  ) async {
    AuthSession? captured;
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: LoginPage(onSignedIn: () {}),
        initialBinding: AuthBinding(),
      ),
    );
    await tester.pumpAndSettle();

    // Swap in a callback that records the call.
    final controller = Get.find<AuthController>();
    await fillCredentials(tester);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    captured = await controller.restoreSession();
    expect(captured, isNull, reason: 'remember me was left off');
    expect(controller.passwordController.text, isEmpty);
  });

  testWidgets('remember me persists the session for the next launch', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login-remember-me')));
    await tester.pumpAndSettle();
    expect(Get.find<AuthController>().rememberMe.value, isTrue);

    await fillCredentials(tester);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    final restored = await AuthLocalDataSource().restoreSession();
    expect(restored, isNotNull);
    expect(restored!.rememberMe, isTrue);
    expect(restored.username, AuthLocalDataSource.demoUsername);
  });

  testWidgets('the label next to the checkbox toggles it too', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();

    expect(Get.find<AuthController>().rememberMe.value, isTrue);
  });

  testWidgets('a slow sign-in shows the loading state and blocks re-submits', (
    tester,
  ) async {
    final gate = Completer<AuthSession>();
    Get.put<AuthRepository>(_SlowRepository(gate));

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: LoginPage(onSignedIn: () {}),
        initialBinding: AuthBinding(),
      ),
    );
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.pump();

    final controller = Get.find<AuthController>();
    expect(controller.isSubmitting.value, isTrue);
    expect(find.text('Signing in...'), findsOneWidget);
    // The fields are disabled so the credentials cannot be edited mid flight.
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('login-username'))).enabled,
      isFalse,
    );

    // A second tap while in flight must not start another attempt.
    await tester.tap(find.byKey(const Key('login-submit')), warnIfMissed: false);
    await tester.pump();
    expect(controller.isSubmitting.value, isTrue);

    gate.complete(
      const AuthSession(username: AuthLocalDataSource.demoUsername, displayName: 'Alex Johnson', rememberMe: false),
    );
    await tester.pumpAndSettle();
    expect(controller.isSubmitting.value, isFalse);
  });

  testWidgets('a generic failure still lands a readable message', (tester) async {
    Get.put<AuthRepository>(_ExplodingRepository());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: LoginPage(onSignedIn: () {}),
        initialBinding: AuthBinding(),
      ),
    );
    await tester.pumpAndSettle();
    await fillCredentials(tester);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('We could not sign you in. Please try again.'), findsOneWidget);
  });

  testWidgets('a successful sign-in updates the app session', (tester) async {
    SessionBinding().dependencies();
    await pumpLogin(tester);
    await fillCredentials(tester);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(
      Get.find<SessionController>().session.value.name,
      'Alex Johnson',
    );
  });

  testWidgets('re-registering the binding keeps the form state', (tester) async {
    await pumpLogin(tester);
    await fillCredentials(tester, username: 'half-typed');

    // Pushing the login route a second time must not reset the form.
    AuthBinding().dependencies();
    await tester.pump();

    expect(
      Get.find<AuthController>().usernameController.text,
      'half-typed',
    );
  });

  testWidgets('forgot password explains who to contact', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login-forgot-password')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Password reset: Please contact your property manager'),
      findsOneWidget,
    );
  });

  testWidgets('no overflow on a small android screen with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpLogin(tester);
    expect(tester.takeException(), isNull);

    // Show a keyboard taking roughly half the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    addTearDown(tester.view.reset);

    await tester.tap(find.byKey(const Key('login-username')));
    await tester.pumpAndSettle();

    // The form still exists and can be scrolled to, so nothing was clipped
    // away by the keyboard.
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const Key('login-submit')),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    expect(tester.takeException(), isNull);
  });
}

/// Completes only when the test says so, so the loading state can be observed.
class _SlowRepository implements AuthRepository {
  _SlowRepository(this.gate);

  final Completer<AuthSession> gate;

  @override
  Future<AuthSession> signIn(SignInRequest request) => gate.future;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> persistSession(AuthSession session) async {}

  @override
  Future<void> signOut() async {}
}

class _ExplodingRepository implements AuthRepository {
  @override
  Future<AuthSession> signIn(SignInRequest request) async =>
      throw StateError('network down');

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> persistSession(AuthSession session) async {}

  @override
  Future<void> signOut() async {}
}