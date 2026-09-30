import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/theme/app_theme.dart';
import 'package:test/features/announcements/presentation/bindings/announcement_binding.dart';
import 'package:test/features/announcements/presentation/pages/announcements_page.dart';
import 'package:test/features/complaints/presentation/bindings/complaint_binding.dart';
import 'package:test/features/complaints/presentation/pages/complaints_page.dart';
import 'package:test/features/complaints/presentation/pages/create_complaint_page.dart';
import 'package:test/features/maintenance/presentation/bindings/maintenance_binding.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_page.dart';
import 'package:test/features/notifications/presentation/bindings/notification_binding.dart';
import 'package:test/features/notifications/presentation/pages/notifications_page.dart';
import 'package:test/features/parking/presentation/bindings/parking_binding.dart';
import 'package:test/features/parking/presentation/pages/parking_page.dart';
import 'package:test/features/profile/presentation/bindings/profile_binding.dart';
import 'package:test/features/profile/presentation/pages/profile_page.dart';
import 'package:test/features/visitors/presentation/bindings/visitor_binding.dart';
import 'package:test/features/visitors/presentation/pages/visitors_page.dart';
import 'package:test/features/lease/presentation/bindings/lease_binding.dart';
import 'package:test/features/lease/presentation/pages/lease_renewal_page.dart';
import 'package:test/features/rules/presentation/bindings/rules_binding.dart';
import 'package:test/features/rules/presentation/pages/appeal_violation_page.dart';
import 'package:test/features/services/presentation/bindings/condo_service_binding.dart';
import 'package:test/features/services/presentation/pages/service_request_page.dart';
import 'package:test/features/store/presentation/bindings/store_binding.dart';
import 'package:test/features/store/presentation/controllers/store_controller.dart';
import 'package:test/features/store/presentation/pages/store_checkout_page.dart';
import 'package:test/features/store/presentation/pages/store_page.dart';
import 'package:test/features/visitors/presentation/pages/register_visitor_page.dart';
import 'package:test/core/widgets/app_primary_action.dart';

/// Walks every resident facing screen at a small phone size. Any RenderFlex
/// overflow fails the test, which is the point of this file.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  /// Pumps [page] at a small phone size. Returns the store controller when the
  /// page registered one, so a store test can drive the flow.
  Future<StoreController?> smallPhone(
    WidgetTester tester,
    Widget page,
    Bindings binding,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: page,
        initialBinding: binding,
      ),
    );
    await tester.pumpAndSettle();
    // Every screen uses the one custom app bar.
    expect(find.byType(AppBar), findsNothing);
    return Get.isRegistered<StoreController>() ? Get.find<StoreController>() : null;
  }

  testWidgets('complaints list', (tester) async {
    await smallPhone(tester, const ComplaintsPage(), ComplaintBinding());
  });

  testWidgets('create complaint', (tester) async {
    await smallPhone(tester, const CreateComplaintPage(), ComplaintBinding());
  });

  testWidgets('visitors', (tester) async {
    await smallPhone(tester, const VisitorsPage(), VisitorBinding());
  });

  testWidgets('parking', (tester) async {
    await smallPhone(tester, const ParkingPage(), ParkingBinding());
  });

  testWidgets('notifications', (tester) async {
    await smallPhone(tester, const NotificationsPage(), NotificationBinding());
  });

  testWidgets('announcements', (tester) async {
    await smallPhone(tester, const AnnouncementsPage(), AnnouncementBinding());
  });

  testWidgets('profile', (tester) async {
    await smallPhone(tester, const ProfilePage(), ProfileBinding());
  });

  testWidgets('maintenance list', (tester) async {
    await smallPhone(tester, const MaintenancePage(), MaintenanceBinding());
  });

  testWidgets('register visitor form', (tester) async {
    await smallPhone(tester, const RegisterVisitorPage(), VisitorBinding());
  });

  testWidgets('visitors list', (tester) async {
    await smallPhone(tester, const VisitorsPage(), VisitorBinding());

    // The primary action is the shared component, sitting in the content flow
    // rather than floating over the cards.
    final cta = find.byKey(const Key('register-visitor'));
    expect(cta, findsOneWidget);
    expect(find.byType(AppPrimaryAction), findsWidgets);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    expect(cta.hitTestable(), findsOneWidget);
  });

  testWidgets('lease renewal form', (tester) async {
    await smallPhone(tester, const LeaseRenewalPage(), LeaseBinding());
  });

  testWidgets('appeal violation form', (tester) async {
    await smallPhone(tester, const AppealViolationPage(), RulesBinding());
  });

  testWidgets('service request form', (tester) async {
    await smallPhone(tester, const ServiceRequestPage(), CondoServiceBinding());
  });

  testWidgets('condo mart shop', (tester) async {
    final store = (await smallPhone(
      tester,
      const StorePage(),
      StoreBinding(),
    ))!;
    // The category row scrolls horizontally rather than overflowing.
    expect(find.byKey(const Key('store-category-scroll')), findsOneWidget);
    // Every visible product leads with a photo frame.
    expect(find.byKey(Key('store-photo-store-lays-chips')), findsOneWidget);

    // An added product swaps its Add button for the stepper.
    await tester.tap(find.byKey(const Key('add-to-cart-store-lays-chips')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-plus-store-lays-chips')), findsOneWidget);
    expect(find.byKey(const Key('cart-minus-store-lays-chips')), findsOneWidget);
    expect(store.cartCount, 1);
  });

  testWidgets('condo mart basket', (tester) async {
    final store = (await smallPhone(
      tester,
      const StorePage(),
      StoreBinding(),
    ))!;
    store.addToCart(store.products.first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('store-tab-basket')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-basket-summary')), findsOneWidget);
  });

  testWidgets('condo mart orders', (tester) async {
    await smallPhone(tester, const StorePage(), StoreBinding());
    await tester.tap(find.byKey(const Key('store-tab-orders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-order-ST-20260930-01')), findsOneWidget);
  });

  testWidgets('condo mart checkout', (tester) async {
    final store = (await smallPhone(
      tester,
      const StoreCheckoutPage(),
      StoreBinding(),
    ))!;
    // The empty state is the first thing a resident can land on with no basket.
    expect(find.text('Nothing to check out'), findsOneWidget);

    store.addToCart(store.products.first);
    await tester.pumpAndSettle();
    expect(find.text('Nothing to check out'), findsNothing);

    // The place-order action sits below the fold on a small phone, so walk the
    // page down to it rather than assuming it is already built.
    final scroll = find.byKey(const Key('store-checkout-scroll'));
    final cta = find.byKey(const Key('store-place-order'));
    for (var i = 0; i < 12 && cta.evaluate().isEmpty; i++) {
      await tester.drag(scroll, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    expect(cta.hitTestable(), findsOneWidget);
  });
}
