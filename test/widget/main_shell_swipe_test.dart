import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/bindings/app_binding.dart';
import 'package:test/features/auth/presentation/bindings/auth_binding.dart';
import 'package:test/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:test/features/dashboard/presentation/pages/main_shell_page.dart';

/// The five tab root is swipeable: horizontal gestures move between tabs, taps
/// on the bar animate the pager, and [selectedTab] stays the single source of
/// truth in both directions.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const MainShellPage(),
        // The pager builds the neighbouring page too, so the full app graph is
        // needed, exactly as the /home route registers it.
        initialBinding: BindingsBuilder(() {
          AppBinding().dependencies();
          AuthBinding().dependencies();
        }),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab() => Get.find<DashboardController>().selectedTab.value;

  int navSelectedIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  /// A horizontal swipe sized to the screen, so it lands on exactly one page
  /// whatever the test viewport's width.
  Future<void> swipeLeft(WidgetTester tester) async {
    final width = tester.getSize(find.byType(PageView)).width;
    await tester.fling(
      find.byType(PageView),
      Offset(-width * 0.75, 0),
      1000,
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight(WidgetTester tester) async {
    final width = tester.getSize(find.byType(PageView)).width;
    await tester.fling(
      find.byType(PageView),
      Offset(width * 0.75, 0),
      1000,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on Home with the bar synced', (tester) async {
    await pumpShell(tester);

    expect(selectedTab(), 0);
    expect(navSelectedIndex(tester), 0);
    expect(find.text('Good morning, Alex'), findsOneWidget);
  });

  testWidgets('swiping left moves to the next tab and updates the bar', (
    tester,
  ) async {
    await pumpShell(tester);

    await swipeLeft(tester);

    expect(selectedTab(), 1);
    expect(navSelectedIndex(tester), 1);

    await swipeLeft(tester);
    await swipeLeft(tester);

    expect(selectedTab(), 3);
    expect(navSelectedIndex(tester), 3);
  });

  testWidgets('swiping right moves to the previous tab', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Facilities'));
    await tester.pumpAndSettle();
    expect(selectedTab(), 3);

    await swipeRight(tester);

    expect(selectedTab(), 2);
    expect(navSelectedIndex(tester), 2);
  });

  testWidgets('tapping the bar animates the pager to the same page', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(selectedTab(), 4);
    expect(navSelectedIndex(tester), 4);
    // The pager actually arrived at the last page, not just the tab state.
    expect(find.text('Personal information'), findsOneWidget);
  });

  testWidgets('the navigation state survives a tap then a swipe then a tap', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Maintenance'));
    await tester.pumpAndSettle();
    expect(selectedTab(), 2);

    await swipeLeft(tester);
    expect(selectedTab(), 3);
    expect(navSelectedIndex(tester), 3);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selectedTab(), 0);
    expect(navSelectedIndex(tester), 0);
  });

  testWidgets('the first page cannot swipe further right', (tester) async {
    await pumpShell(tester);

    await swipeRight(tester);

    expect(selectedTab(), 0);
    expect(navSelectedIndex(tester), 0);
  });

  testWidgets('the last page cannot swipe further left', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(selectedTab(), 4);

    await swipeLeft(tester);

    expect(selectedTab(), 4);
    expect(navSelectedIndex(tester), 4);
  });

  testWidgets('vertical scrolling inside a page still works after swiping', (
    tester,
  ) async {
    await pumpShell(tester);

    await swipeLeft(tester);
    expect(selectedTab(), 1);

    // The payments list scrolls vertically without the pager stealing the drag.
    await tester.drag(
      find.byKey(const Key('payments-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(selectedTab(), 1, reason: 'a vertical drag must not change tabs');
    expect(find.byKey(const Key('payments-scroll')), findsOneWidget);
  });

  testWidgets('a dashboard quick action animates the pager too', (tester) async {
    await pumpShell(tester);

    await tester.ensureVisible(find.text('Pay now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(selectedTab(), 1);
    expect(navSelectedIndex(tester), 1);
    expect(find.byKey(const Key('payments-scroll')), findsOneWidget);
  });

  testWidgets('no overflow on a small screen and swipes still work', (
    tester,
  ) async {
    // The project's small-screen size; the payments page overflows on its own
    // below this width, which is a pre-existing layout issue and not caused by
    // the pager.
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpShell(tester);
    expect(tester.takeException(), isNull);

    await swipeLeft(tester);
    expect(selectedTab(), 1);
    expect(tester.takeException(), isNull);

    await swipeRight(tester);
    expect(selectedTab(), 0);
    expect(tester.takeException(), isNull);
  });
}