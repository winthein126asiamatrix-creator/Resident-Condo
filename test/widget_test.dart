import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A remembered session, so the splash routes straight home rather than to
  // the login screen, which is not what these flows are about.
  SharedPreferences.setMockInitialValues(<String, Object>{
    'auth.username': 'alex',
    'auth.display_name': 'Alex Johnson',
  });
  testWidgets('opens the resident dashboard after the splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CondoResidentApp());
    await tester.pump();
    expect(find.text('Condo Residents'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('Tower A · Unit 1205'), findsOneWidget);
    expect(find.text('Outstanding balance'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Payment due soon'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Alex'), findsOneWidget);

    await tester.ensureVisible(find.text('Pay now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();
    expect(find.text('Outstanding balance'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('payments-scroll')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invoices'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('dashboard-scroll')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Alex'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('dashboard-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Alex'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('dashboard-scroll')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tower A · Unit 1205'));
    await tester.pumpAndSettle();
    expect(find.text('My Unit'), findsOneWidget);
    expect(find.text('Unit information'), findsOneWidget);
    expect(find.textContaining('Parking B2-125'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Alex'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    // The payments tab keeps its scroll offset, so reset it before asserting.
    await tester.drag(
      find.byKey(const Key('payments-scroll')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Outstanding balance'), findsOneWidget);
    expect(find.text('Balance by fee type'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('payments-scroll')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('INV-2026-011'), findsOneWidget);

    await tester.tap(find.textContaining('INV-2026-011'));
    await tester.pumpAndSettle();
    expect(find.text('Invoice details'), findsOneWidget);
    expect(find.text('Breakdown'), findsOneWidget);
    expect(find.text('AMOUNT DUE'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('invoice-pay-selected')),
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('invoice-detail-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoice-pay-selected')));
    await tester.pumpAndSettle();
    expect(find.text('Payment summary'), findsOneWidget);
    expect(find.text('Select items'), findsOneWidget);
    // Mandatory fees are selected automatically and locked, optional ones are
    // left for the resident to pick.
    final firstItem = find.byKey(const Key('invoice-item-condoFee|Sep 2026'));
    expect(firstItem, findsOneWidget);
    final mandatoryTile = tester.widget<CheckboxListTile>(
      find.descendant(of: firstItem, matching: find.byType(CheckboxListTile)),
    );
    expect(mandatoryTile.value, isTrue);
    expect(mandatoryTile.onChanged, isNull);

    final optionalItem = find.byKey(
      const Key('invoice-item-parking|Sep 2026 · Slot B2-125'),
    );
    expect(optionalItem, findsOneWidget);
    final optionalTile = tester.widget<CheckboxListTile>(
      find.descendant(
        of: optionalItem,
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(optionalTile.value, isFalse);
    expect(optionalTile.onChanged, isNotNull);
    expect(find.text('Mandatory'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Alex'), findsOneWidget);

    await tester.tap(find.text('Maintenance'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance summary'), findsOneWidget);
    expect(find.byKey(const Key('add-maintenance-request')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-maintenance-request')));
    await tester.pumpAndSettle();
    expect(find.text('New Request'), findsOneWidget);
    expect(find.byKey(const Key('maintenance-title')), findsOneWidget);
    expect(find.byKey(const Key('submit-maintenance-request')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facilities'));
    await tester.pumpAndSettle();
    expect(find.text('Your amenities'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Reserve'), findsNWidgets(6));

    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reserve-facility-facility-gym')));
    await tester.pumpAndSettle();
    expect(find.text('Reserve facility'), findsOneWidget);
    expect(find.text('Select a date'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Johnson'), findsNWidgets(2));
    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('Role-based view'), findsOneWidget);
    expect(find.byKey(const Key('role-option-owner')), findsOneWidget);

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
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });
}
