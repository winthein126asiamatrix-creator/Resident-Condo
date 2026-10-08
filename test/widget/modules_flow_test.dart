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
  /// Scrolls a lazily built list until [target] exists, then makes it visible.
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
    // Start from the top so the helper works for items above and below.
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

  Future<void> openHub(WidgetTester tester) async {
    await scrollTo(
      tester,
      find.byKey(const Key('dashboard-all-services')),
      'dashboard-scroll',
    );
    await tester.tap(find.byKey(const Key('dashboard-all-services')));
    await tester.pumpAndSettle();
  }

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(const CondoResidentApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
  }

  testWidgets('navigates the resident services hub and the visitor workflow', (
    WidgetTester tester,
  ) async {
    await startApp(tester);

    await openHub(tester);
    expect(find.text('Resident services'), findsOneWidget);
    expect(find.text('Rental & lease'), findsOneWidget);
    expect(find.text('Visitors'), findsOneWidget);
    await scrollTo(tester, find.text('Rules & violations'), 'more-scroll');
    expect(find.text('Rules & violations'), findsOneWidget);

    await scrollTo(tester, find.text('Visitors'), 'more-scroll');
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    expect(find.text('Visitor access'), findsOneWidget);
    expect(find.text('Pre-registered'), findsWidgets);

    await tester.tap(find.byKey(const Key('register-visitor')));
    await tester.pumpAndSettle();
    expect(find.text('Register visitor'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('visitor-name-field')),
      'Nina Patel',
    );
    await tester.enterText(
      find.byKey(const Key('visitor-phone-field')),
      '+959772611100',
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const Key('submit-visitor')), 'register-visitor-scroll');
    await tester.tap(find.byKey(const Key('submit-visitor')));
    await tester.pumpAndSettle();
    expect(find.text('Register visitor?'), findsOneWidget);

    final confirm = find.widgetWithText(FilledButton, 'Register');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('VISITOR ACCESS CODE'), findsOneWidget);
    expect(find.text('Nina Patel'), findsWidgets);
    await scrollTo(
      tester,
      find.text('Copy access code'),
      'visitor-pass-scroll',
    );
    // A QR pass is never used in the visitor workflow.
    expect(find.textContaining('QR'), findsNothing);
  });

  testWidgets('opens lease, services, parking, complaints and rules screens', (
    WidgetTester tester,
  ) async {
    await startApp(tester);
    await openHub(tester);

    await scrollTo(tester, find.text('Rental & lease'), 'more-scroll');
    await tester.tap(find.text('Rental & lease'));
    await tester.pumpAndSettle();
    expect(find.text('Term progress'), findsOneWidget);
    await scrollTo(tester, find.text('Renewal requests'), 'lease-scroll');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Condo services'), 'more-scroll');
    await tester.tap(find.text('Condo services'));
    await tester.pumpAndSettle();
    expect(find.text('Book a service'), findsOneWidget);
    expect(find.text('Deep cleaning'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Parking'), 'more-scroll');
    await tester.tap(find.text('Parking'));
    await tester.pumpAndSettle();
    expect(find.text('Slot B2-125'), findsOneWidget);
    await scrollTo(tester, find.text('Access log'), 'parking-scroll');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Complaints'), 'more-scroll');
    await tester.tap(find.text('Complaints'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining('CMP-2026-018'), 'complaints-scroll');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Rules & violations'), 'more-scroll');
    await tester.tap(find.text('Rules & violations'));
    await tester.pumpAndSettle();
    expect(find.text('Community rules'), findsWidgets);
    await scrollTo(tester, find.textContaining('VIO-2026-009'), 'rules-scroll');
  });
}
