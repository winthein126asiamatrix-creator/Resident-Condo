import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/routes/app_routes.dart';
import 'package:test/app/theme/app_theme.dart';
import 'package:test/core/utils/app_dates.dart';
import 'package:test/core/utils/app_times.dart';
import 'package:test/features/visitors/presentation/bindings/visitor_binding.dart';
import 'package:test/features/visitors/presentation/controllers/visitor_controller.dart';
import 'package:test/features/visitors/presentation/pages/register_visitor_page.dart';
import 'package:test/features/visitors/presentation/pages/visitor_pass_page.dart';
import 'package:test/core/theme/app_palette.dart';

/// Covers the visit date range, the custom arrival time and the window that is
/// derived from the arrival time.
/// Background colour of a visit date card, which is how the selected day is
/// shown.
Color? _cardColour(WidgetTester tester, String date) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byKey(Key('visit-date-$date')),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.color;
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  Future<VisitorController> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const RegisterVisitorPage(),
        initialBinding: VisitorBinding(),
        getPages: [
          GetPage<dynamic>(
            name: AppRoutes.visitorPass,
            page: () => VisitorPassPage(visitor: Get.arguments as dynamic),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return Get.find<VisitorController>();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    final list = find
        .descendant(
          of: find.byKey(const Key('register-visitor-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(target, 200, scrollable: list);
    await tester.pumpAndSettle();
  }

  /// The four selectable dates, generated the same way the page does.
  List<String> expectedDates() {
    final now = DateTime.now();
    return List.generate(
      4,
      (index) =>
          AppDates.format(DateTime(now.year, now.month, now.day + index)),
    );
  }

  testWidgets('offers today and the next three days, generated dynamically', (
    tester,
  ) async {
    await pumpForm(tester);
    await scrollTo(tester, find.text('Visit date'));

    final dates = expectedDates();
    expect(dates, hasLength(4));
    for (final date in dates) {
      expect(
        find.byKey(Key('visit-date-$date')),
        findsOneWidget,
        reason: '$date must be selectable',
      );
    }

    // Relative labels, the day number and the month.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    for (final date in dates) {
      final parsed = AppDates.parse(date);
      expect(find.text(parsed.day.toString().padLeft(2, '0')), findsWidgets);
    }

    // Today starts selected, shown by the filled card.
    expect(_cardColour(tester, dates.first), AppPalette.brand);
  });

  testWidgets('tapping another visit date changes the selection', (
    tester,
  ) async {
    await pumpForm(tester);
    final dates = expectedDates();
    final target = dates[2];
    await scrollTo(tester, find.byKey(Key('visit-date-$target')));

    await tester.tap(find.byKey(Key('visit-date-$target')));
    await tester.pumpAndSettle();

    expect(_cardColour(tester, target), AppPalette.brand);
    expect(_cardColour(tester, dates.first), isNot(AppPalette.brand));
  });

  testWidgets('a predefined arrival time produces a two hour window', (
    tester,
  ) async {
    await pumpForm(tester);
    await scrollTo(tester, find.text('Arrival time'));

    for (final slot in const ['9:00 AM', '12:00 PM', '2:00 PM']) {
      await tester.tap(find.byKey(Key('arrival-slot-$slot')));
      await tester.pumpAndSettle();

      final start = AppTimes.parse(slot)!;
      final end = AppTimes.addHours(start, 2);
      expect(
        find.text('${AppTimes.format(start)} – ${AppTimes.format(end)}'),
        findsOneWidget,
        reason: '$slot is a two hour visit',
      );
    }
    // The duration is stated, not left for the resident to work out.
    expect(find.text('2 hours'), findsOneWidget);
  });

  testWidgets('a custom arrival time is picked and shown like a preset', (
    tester,
  ) async {
    await pumpForm(tester);
    await scrollTo(tester, find.byKey(const Key('arrival-slot-custom')));

    await tester.tap(find.byKey(const Key('arrival-slot-custom')));
    await tester.pumpAndSettle();
    // The platform time picker, no new package involved.
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Seeded with the current arrival time, so confirming keeps 10:00 AM and the
    // window is unchanged.
    expect(find.text('10:00 AM – 12:00 PM'), findsOneWidget);
    // The custom chip shows the chosen time in the same design as a preset.
    expect(
      find.descendant(
        of: find.byKey(const Key('arrival-slot-custom')),
        matching: find.text('10:00 AM'),
      ),
      findsOneWidget,
    );
    expect(find.text('Custom time'), findsNothing);
  });

  testWidgets('cancelling the time picker keeps the previous arrival', (
    tester,
  ) async {
    await pumpForm(tester);
    await scrollTo(tester, find.byKey(Key('arrival-slot-10:00 AM')));
    await tester.tap(find.byKey(Key('arrival-slot-10:00 AM')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('arrival-slot-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('10:00 AM – 12:00 PM'), findsOneWidget);
  });

  testWidgets('the visit window is stored on the registered visitor', (
    tester,
  ) async {
    final controller = await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('visitor-name-field')),
      'Nina Patel',
    );
    await tester.enterText(
      find.byKey(const Key('visitor-phone-field')),
      '+959772611100',
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(Key('arrival-slot-2:00 PM')));
    await tester.tap(find.byKey(Key('arrival-slot-2:00 PM')));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const Key('submit-visitor')));
    await tester.tap(find.byKey(const Key('submit-visitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    final visitor = controller.visitors.first;
    // The two hour window is stored, not just the start time.
    expect(visitor.arrivalWindow, '2:00 PM – 4:00 PM');
  });

  testWidgets('the form has no overflow on a small android screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpForm(tester);

    // Walking the form is the assertion: any RenderFlex overflow fails.
    for (final target in [
      find.byKey(Key('visit-date-${expectedDates().last}')),
      find.byKey(const Key('arrival-slot-custom')),
      find.byKey(const Key('submit-visitor')),
    ]) {
      await scrollTo(tester, target);
      expect(target, findsOneWidget);
    }
  });
}
