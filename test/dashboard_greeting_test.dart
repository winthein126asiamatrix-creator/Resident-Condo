import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/theme/app_theme.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/dashboard/presentation/bindings/dashboard_binding.dart';
import 'package:test/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

/// Covers the greeting on the dashboard.
///
/// The point of these tests is the wiring: `/auth/me` -> [AuthUser.displayName]
/// -> `AuthController.adoptIntoSession` -> [SessionController] -> the greeting.
/// The dashboard payload used to carry a hardcoded 'Alex Johnson' in its own
/// `Resident`, which is what the greeting rendered; that field is gone, so the
/// only name the greeting can show is the authenticated one.
void main() {
  setUp(Get.reset);

  /// Pumps the dashboard the way the app does: register the controller graph,
  /// seed the session the way `adoptIntoSession` would after `/auth/me`, then
  /// let the mock dashboard payload resolve.
  Future<void> pumpDashboard(WidgetTester tester) async {
    DashboardBinding().dependencies();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.forSeed(const Color(0xFF2563EB), Brightness.light),
        home: Scaffold(body: DashboardPage(onSelectTab: (_) {})),
      ),
    );
    // The payload resolves on a microtask; two pumps is plenty, and avoids
    // pumpAndSettle, which would never settle on the indeterminate progress bar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('AuthUser.displayName', () {
    test('joins firstName and lastName, which is what the greeting shows', () {
      // The shape DummyJSON's /auth/me answers with.
      const user = AuthUser(
        id: 1,
        username: 'emilys',
        email: 'emily.johnson@example.com',
        firstName: 'Emily',
        lastName: 'Johnson',
      );

      expect(user.displayName, 'Emily Johnson');
    });

    test('falls back to username when the name parts are missing', () {
      const user = AuthUser(
        id: 1,
        username: 'emilys',
        email: 'emily.johnson@example.com',
        firstName: '',
        lastName: '',
      );

      expect(user.displayName, 'emilys');
    });
  });

  group('Dashboard greeting', () {
    testWidgets('shows the authenticated resident, not the old sample name', (tester) async {
      Get.put<SessionController>(SessionController());
      // Written by AuthController.adoptIntoSession from /auth/me.
      Get.find<SessionController>().signInAs(
        'Emily Johnson',
        email: 'emily.johnson@example.com',
      );

      await pumpDashboard(tester);

      expect(find.text('Good morning, Emily'), findsOneWidget);
      expect(find.text('EJ'), findsOneWidget);
      expect(find.textContaining('Alex'), findsNothing);
    });

    testWidgets('updates when the session changes', (tester) async {
      Get.put<SessionController>(SessionController());
      Get.find<SessionController>().signInAs('Emily Johnson');

      await pumpDashboard(tester);
      expect(find.text('Good morning, Emily'), findsOneWidget);

      // A re-fetch of /auth/me under a different account, or a re-login.
      Get.find<SessionController>().signInAs('Marcus Webb');
      await tester.pump();

      expect(find.text('Good morning, Marcus'), findsOneWidget);
      expect(find.text('Emily'), findsNothing);
    });

    testWidgets('never paints a blank name', (tester) async {
      // No SessionController registered: the greeting falls back to a neutral
      // word rather than a placeholder that belongs to nobody.
      expect(Get.isRegistered<SessionController>(), isFalse);

      await pumpDashboard(tester);

      expect(find.text('Good morning, Resident'), findsOneWidget);
      expect(find.textContaining('Alex'), findsNothing);
    });
  });
}
