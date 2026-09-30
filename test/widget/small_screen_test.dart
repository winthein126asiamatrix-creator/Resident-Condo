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
import 'package:test/features/visitors/presentation/pages/register_visitor_page.dart';

/// Walks every resident facing screen at a small phone size. Any RenderFlex
/// overflow fails the test, which is the point of this file.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<void> smallPhone(
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

  testWidgets('lease renewal form', (tester) async {
    await smallPhone(tester, const LeaseRenewalPage(), LeaseBinding());
  });

  testWidgets('appeal violation form', (tester) async {
    await smallPhone(tester, const AppealViolationPage(), RulesBinding());
  });

  testWidgets('service request form', (tester) async {
    await smallPhone(tester, const ServiceRequestPage(), CondoServiceBinding());
  });
}
