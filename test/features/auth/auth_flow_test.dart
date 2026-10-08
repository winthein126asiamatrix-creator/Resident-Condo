import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/app.dart';
import 'package:test/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:test/features/auth/presentation/controllers/auth_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

/// The app level wiring: splash routes by session state, a sign-in enters the
/// app, and logout leaves it again.
void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(Get.reset);

  /// Boots the real app and waits out the splash.
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(const CondoResidentApp());
    await tester.pump();
    // Splash shows the brand before deciding where to go.
    expect(find.text('Condo Residents'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
  }

  testWidgets('a cold start lands on the login screen', (tester) async {
    await boot(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to manage your residence'), findsOneWidget);
    // The dashboard is not mounted underneath.
    expect(find.text('Good morning, Alex'), findsNothing);
  });

  testWidgets('a remembered session skips the login screen', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth.username': AuthLocalDataSource.demoUsername,
      'auth.display_name': 'Alex Johnson',
    });

    await boot(tester);

    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    // The session was adopted, not just read.
    expect(
      Get.find<SessionController>().session.value.name,
      'Alex Johnson',
    );
  });

  testWidgets('signing in enters the app and logout returns to login', (
    tester,
  ) async {
    await boot(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    // Sign in with the demo account.
    await tester.enterText(find.byKey(const Key('login-username')), AuthLocalDataSource.demoUsername);
    await tester.enterText(
      find.byKey(const Key('login-password')),
      AuthLocalDataSource.demoPassword,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    // Home, with the signed in resident greeting them.
    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);

    // Logout from the Profile tab.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Logout'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Logout?'), findsOneWidget);
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();

    // Back on the login screen, and the remembered session is gone.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Good morning, Alex'), findsNothing);
    expect(
      await Get.find<AuthController>().restoreSession(),
      isNull,
    );
  });

  testWidgets('after logout a cold start asks for sign in again', (tester) async {
    // Sign in, remember nothing, sign out, then boot again.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth.username': AuthLocalDataSource.demoUsername,
      'auth.display_name': 'Alex Johnson',
    });
    await boot(tester);
    expect(find.text('Good morning, Alex'), findsOneWidget);

    final auth = Get.find<AuthController>();
    await auth.signOut();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const SizedBox.shrink());

    // A fresh boot over the now empty storage must not let them back in.
    await tester.pumpWidget(const CondoResidentApp());
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}