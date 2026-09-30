import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/theme/app_theme.dart';
import 'package:test/core/utils/app_dates.dart';
import 'package:test/features/facilities/presentation/bindings/facility_binding.dart';
import 'package:test/features/facilities/presentation/controllers/facility_controller.dart';
import 'package:test/features/facilities/presentation/pages/facility_reservation_page.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  /// Opens the reservation screen with a facility already chosen, the way the
  /// resident arrives there from the facilities list.
  Future<FacilityController> pumpReservation(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const FacilityReservationPage(),
        initialBinding: FacilityBinding(),
      ),
    );
    await tester.pumpAndSettle();

    final controller = Get.find<FacilityController>();
    expect(find.text('No facility selected'), findsOneWidget);
    controller.selectFacility(controller.facilities.first);
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('the date chips cover today and the next five days', (
    tester,
  ) async {
    final controller = await pumpReservation(tester);

    final now = DateTime.now();
    final expected = List.generate(
      6,
      (index) =>
          AppDates.format(DateTime(now.year, now.month, now.day + index)),
    );

    for (final date in expected) {
      expect(
        find.byKey(Key('facility-date-$date')),
        findsOneWidget,
        reason: '$date must be selectable',
      );
    }
    expect(expected.first, AppDates.format(now));
    // Today is preselected so the resident can confirm straight away.
    expect(controller.selectedDate.value, expected.first);
  });

  testWidgets('tapping another date moves the selection', (tester) async {
    final controller = await pumpReservation(tester);

    final dates = controller.reservationDates;
    final target = dates[3];
    await tester.tap(find.byKey(Key('facility-date-$target')));
    await tester.pumpAndSettle();

    expect(controller.selectedDate.value, target);
    final chip = tester.widget<ChoiceChip>(
      find.byKey(Key('facility-date-$target')),
    );
    expect(chip.selected, isTrue);
    // The previously selected date gives the selection back.
    final previous = tester.widget<ChoiceChip>(
      find.byKey(Key('facility-date-${dates.first}')),
    );
    expect(previous.selected, isFalse);
  });

  testWidgets('custom time is offered next to the predefined slots', (
    tester,
  ) async {
    final controller = await pumpReservation(tester);

    expect(find.byKey(const Key('facility-slot-custom')), findsOneWidget);
    expect(find.text('Custom time'), findsOneWidget);
    for (final slot in controller.selectedFacility.value!.availableSlots) {
      expect(find.byKey(Key('facility-slot-$slot')), findsOneWidget);
    }
    expect(controller.selectedSlot.value, isNull);
  });

  testWidgets('a chosen custom time is stored and displayed', (tester) async {
    final controller = await pumpReservation(tester);

    await tester.tap(find.byKey(const Key('facility-slot-custom')));
    await tester.pumpAndSettle();
    // The platform picker opens; confirming it takes the time it was seeded with.
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.customTime.value, isNotNull);
    expect(controller.isCustomTimeSelected, isTrue);
    final expected = FacilityController.customSlotLabel(
      controller.customTime.value!,
    );
    expect(controller.selectedSlot.value, expected);
    // The chip shows the chosen time instead of the generic label.
    expect(find.text('Custom time'), findsNothing);
    expect(find.text(expected), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('facility-slot-custom')))
          .selected,
      isTrue,
    );

    // Picking a predefined slot again takes over and clears the custom time.
    final slot = controller.selectedFacility.value!.availableSlots.first;
    await tester.tap(find.byKey(Key('facility-slot-$slot')));
    await tester.pumpAndSettle();
    expect(controller.selectedSlot.value, slot);
    expect(controller.customTime.value, isNull);
    expect(find.text('Custom time'), findsOneWidget);
  });

  testWidgets('cancelling the time picker keeps the current selection', (
    tester,
  ) async {
    final controller = await pumpReservation(tester);

    final slot = controller.selectedFacility.value!.availableSlots.first;
    controller.selectSlot(slot);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('facility-slot-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.selectedSlot.value, slot);
    expect(controller.customTime.value, isNull);
    expect(controller.isCustomTimeSelected, isFalse);
    expect(find.text('Custom time'), findsOneWidget);
  });

  testWidgets('the reservation screen has no overflow on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = await pumpReservation(tester);

    // Any RenderFlex overflow is reported as a test failure, so walking the
    // whole screen is the assertion.
    expect(find.text('Select a date'), findsOneWidget);
    expect(find.text('Select a time slot'), findsOneWidget);
    expect(find.byKey(const Key('facility-slot-custom')), findsOneWidget);

    // Every generated date chip renders, and so does the custom time chip, on a
    // narrow screen.
    for (final date in controller.reservationDates) {
      final finder = find.byKey(Key('facility-date-$date'));
      expect(finder, findsOneWidget, reason: '$date must render');
    }

    await tester.tap(find.byKey(const Key('facility-slot-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.isCustomTimeSelected, isTrue);
  });

  testWidgets('the reservation screen uses the shared custom app bar', (
    tester,
  ) async {
    await pumpReservation(tester);

    expect(find.text('Reserve facility'), findsOneWidget);
    // The Material app bar is replaced by the shared custom one.
    expect(find.byType(AppBar), findsNothing);
    expect(
      find.byIcon(Icons.arrow_back_rounded),
      findsOneWidget,
      reason: 'the custom bar brings its own back button',
    );
  });
}
