import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/app.dart';
import 'package:test/app/routes/app_routes.dart';
import 'package:test/features/announcements/presentation/controllers/announcement_controller.dart';
import 'package:test/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:test/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';

/// Regression cover for the "AnnouncementController not found" crash.
///
/// The feature controllers used to be registered by the `/home` route only.
/// `Get.offNamed(home)` and `Get.offAllNamed(home)` create a *new* home
/// instance, and disposing it deleted the controllers that the previous home
/// instance - and any page pushed on top of it, such as Announcements - still
/// needed. Every session scoped controller is now registered permanently by
/// `AppBinding`, so route replacement can no longer remove it.
void main() {
  Future<void> scrollTo(
    WidgetTester tester,
    Finder target,
    String scrollKey,
  ) async {
    final scrollable = find
        .descendant(
          of: find.byKey(Key(scrollKey)),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, 5000));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 30; attempt++) {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        return;
      }
      await tester.drag(scrollable, const Offset(0, -160));
      await tester.pumpAndSettle();
    }
    fail('Could not find $target inside $scrollKey');
  }

  testWidgets('announcements still work after the home route is replaced', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CondoResidentApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(Get.isRegistered<AnnouncementController>(), isTrue);

    // The root cause: session scoped controllers must not be owned (and thus
    // deleted) by any route. GetX only allows a route disposal to skip a
    // dependency when it is registered as permanent.
    expect(
      GetInstance().getInstanceInfo<AnnouncementController>().isPermanent,
      isTrue,
      reason: 'AnnouncementController must be permanent',
    );
    expect(
      GetInstance().getInstanceInfo<NotificationController>().isPermanent,
      isTrue,
      reason: 'NotificationController must be permanent',
    );
    expect(
      GetInstance().getInstanceInfo<DashboardController>().isPermanent,
      isTrue,
      reason: 'DashboardController must be permanent',
    );
    expect(
      GetInstance().getInstanceInfo<PaymentController>().isPermanent,
      isTrue,
      reason: 'PaymentController must be permanent',
    );

    // The exact route replacement used by the "Done" buttons after a payment.
    Get.offAllNamed(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Get.isRegistered<AnnouncementController>(), isTrue);

    // And the "Back to payments" replacement used by the empty states.
    // `Get.offNamed(home)` pushes a *second* home while the first one is still
    // mounted underneath, so the stack now holds two shells.
    Get.offNamed(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(Get.isRegistered<AnnouncementController>(), isTrue);

    // Popping that second home (system back) disposes its bindings while the
    // first shell is still mounted. Before the fix the shared controllers were
    // deleted here, so the rebuilt shell threw "...Controller not found".
    Get.back();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Get.isRegistered<AnnouncementController>(), isTrue);
    expect(Get.isRegistered<DashboardController>(), isTrue);
    expect(Get.isRegistered<PaymentController>(), isTrue);

    // Announcements must render without a controller lookup failure.
    await scrollTo(
      tester,
      find.byKey(const Key('dashboard-all-services')),
      'dashboard-scroll',
    );
    await tester.tap(find.byKey(const Key('dashboard-all-services')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Announcements'), 'more-scroll');
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Announcements'), findsWidgets);
    expect(find.text('Stay in the loop'), findsOneWidget);
  });

  testWidgets('a full payment round trip keeps the shell controllers alive', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CondoResidentApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining('INV-2026-011'), 'payments-scroll');
    await tester.tap(find.textContaining('INV-2026-011'));
    await tester.pumpAndSettle();

    await scrollTo(
      tester,
      find.byKey(const Key('invoice-pay-selected')),
      'invoice-detail-scroll',
    );
    await tester.tap(find.byKey(const Key('invoice-pay-selected')));
    await tester.pumpAndSettle();

    await scrollTo(
      tester,
      find.byKey(const Key('select-all-unpaid')),
      'payment-summary-scroll',
    );
    await tester.tap(find.byKey(const Key('select-all-unpaid')));
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.byKey(const Key('continue-to-payment')),
      'payment-summary-scroll',
    );
    await tester.tap(find.byKey(const Key('continue-to-payment')));
    await tester.pumpAndSettle();

    await scrollTo(
      tester,
      find.byKey(const Key('confirm-payment')),
      'payment-method-scroll',
    );
    await tester.tap(find.byKey(const Key('confirm-payment')));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Confirm Payment').last;
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Payment Successful'), findsOneWidget);

    await scrollTo(
      tester,
      find.text('View Receipt'),
      'payment-success-scroll',
    );
    await tester.tap(find.text('View Receipt'));
    await tester.pumpAndSettle();
    expect(find.text('PAYMENT RECEIPT'), findsOneWidget);

    // "Done" runs Get.offAllNamed(home), replacing the whole stack.
    await scrollTo(tester, find.text('Done'), 'payment-receipt-scroll');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(Get.isRegistered<AnnouncementController>(), isTrue);
    expect(Get.isRegistered<PaymentController>(), isTrue);
  });
}
