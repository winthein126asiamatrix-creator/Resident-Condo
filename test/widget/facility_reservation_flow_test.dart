import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/routes/app_routes.dart';
import 'package:test/app/theme/app_theme.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/core/utils/app_dates.dart';
import 'package:test/core/widgets/app_primary_action.dart';
import 'package:test/features/facilities/data/datasources/facility_local_data_source.dart';
import 'package:test/features/facilities/data/repositories/facility_repository_impl.dart';
import 'package:test/features/facilities/domain/entities/facility.dart';
import 'package:test/features/facilities/domain/repositories/facility_repository.dart';
import 'package:test/features/facilities/domain/usecases/facility_usecases.dart';
import 'package:test/features/facilities/presentation/controllers/facility_controller.dart';
import 'package:test/features/facilities/presentation/pages/booking_confirmed_page.dart';
import 'package:test/features/facilities/presentation/pages/facilities_page.dart';
import 'package:test/features/facilities/presentation/pages/facility_reservation_page.dart';
import 'package:test/features/facilities/presentation/pages/my_reservations_page.dart';
import 'package:test/features/facilities/presentation/pages/reservation_detail_page.dart';
import 'package:test/core/utils/app_times.dart';

/// Wraps the real local repository so a test can watch the calls, make the
/// create fail, or hold it open to check the submitting state.
class TestRepository implements FacilityRepository {
  TestRepository({
    this.reservations,
    this.facilities,
    this.failureMessage,
    this.failLoads = false,
  });

  /// When set, `getReservations` returns this instead of the seeded list.
  List<FacilityReservation>? reservations;

  /// When set, `getFacilities` returns this instead of the seeded list.
  List<Facility>? facilities;

  /// When set, `createReservation` throws with this message.
  String? failureMessage;

  /// When true, `getReservations` throws, to exercise the error state.
  bool failLoads;

  int createCalls = 0;
  Completer<FacilityReservation>? gate;

  final FacilityRepository _real = FacilityRepositoryImpl(
    FacilityLocalDataSource(),
  );

  @override
  Future<List<Facility>> getFacilities() async =>
      facilities ?? _real.getFacilities();

  @override
  Future<Facility?> getFacility(String id) => _real.getFacility(id);

  @override
  Future<List<FacilityReservation>> getReservations() async {
    if (failLoads) {
      throw const AppException('Unable to load your reservations.');
    }
    return reservations ?? _real.getReservations();
  }

  @override
  Future<FacilityReservation> createReservation(
    FacilityReservation reservation,
  ) async {
    createCalls++;
    if (failureMessage != null) {
      throw AppException(failureMessage!);
    }
    final pending = gate;
    if (pending != null) {
      return pending.future;
    }
    return _real.createReservation(reservation);
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  /// Registers the controller the way [FacilityBinding] does, but with a
  /// repository the test controls.
  Future<FacilityController> registerController(
    TestRepository repository,
  ) async {
    final controller = FacilityController(FacilityUseCases(repository));
    Get.put<FacilityController>(controller, permanent: true);
    await controller.loadFacilities();
    return controller;
  }

  /// Pumps a page with the routes the reservation flow needs.
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: page,
        getPages: [
          GetPage<dynamic>(
            name: AppRoutes.facilityReserve,
            page: () => const FacilityReservationPage(),
          ),
          GetPage<dynamic>(
            name: AppRoutes.bookingConfirmed,
            page: () => BookingConfirmedPage(
              reservation: Get.arguments as FacilityReservation,
            ),
          ),
          GetPage<dynamic>(
            name: AppRoutes.myReservations,
            page: () => const MyReservationsPage(),
          ),
          GetPage<dynamic>(
            name: AppRoutes.reservationDetail,
            page: () => ReservationDetailPage(
              reservation: Get.arguments as FacilityReservation,
            ),
          ),
          GetPage<dynamic>(name: AppRoutes.home, page: () => const Scaffold()),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The reservation screen with a facility already chosen, as the resident
  /// arrives there from the amenities grid.
  Future<FacilityController> pumpReservation(
    WidgetTester tester, {
    TestRepository? repository,
  }) async {
    final controller = await registerController(repository ?? TestRepository());
    await pumpPage(tester, const FacilityReservationPage());
    expect(find.text('No facility selected'), findsOneWidget);
    controller.selectFacility(controller.facilities.first);
    await tester.pumpAndSettle();
    return controller;
  }

  /// Taps the CTA and opens the review dialog.
  /// Scrolls the reservation page until [target] is on screen. The list is
  /// lazy, and the page is long enough that the CTA starts below the fold.
  Future<void> scrollReservationTo(WidgetTester tester, Finder target) async {
    final list = find
        .descendant(
          of: find.byKey(const Key('facility-reservation-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(target, 200, scrollable: list);
    await tester.pumpAndSettle();
  }

  Future<void> openConfirmDialog(WidgetTester tester) async {
    await scrollReservationTo(
      tester,
      find.byKey(const Key('confirm-reservation')),
    );
    await tester.tap(find.byKey(const Key('confirm-reservation')));
    await tester.pumpAndSettle();
  }

  /// Builds the reservation the controller would send for the current
  /// selection, used to unblock a held create.
  FacilityReservation buildTestReservation(FacilityController controller) {
    final facility = controller.selectedFacility.value!;
    return FacilityReservation(
      id: 'RES-900',
      facilityId: facility.id,
      facilityName: facility.name,
      date: controller.selectedDate.value,
      time: controller.selectedSlot.value!,
      status: 'Confirmed',
      createdAt: controller.selectedDate.value,
      isCustomTime: controller.isCustomTimeSelected,
    );
  }

  group('date and time selection', () {
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
      expect(controller.selectedDate.value, expected.first);
    });

    testWidgets('tapping another date moves the selection without booking', (
      tester,
    ) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);

      final target = controller.reservationDates[3];
      await tester.tap(find.byKey(Key('facility-date-$target')));
      await tester.pumpAndSettle();

      expect(controller.selectedDate.value, target);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(Key('facility-date-$target')))
            .selected,
        isTrue,
      );
      expect(
        repository.createCalls,
        0,
        reason: 'a date must not book anything',
      );
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

    testWidgets('a predefined slot can be picked', (tester) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);
      final slot = controller.selectedFacility.value!.availableSlots.first;

      await tester.tap(find.byKey(Key('facility-slot-$slot')));
      await tester.pumpAndSettle();

      expect(controller.selectedSlot.value, slot);
      expect(repository.createCalls, 0);
    });

    testWidgets('a chosen custom time is stored and displayed', (tester) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);

      await tester.tap(find.byKey(const Key('facility-slot-custom')));
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.isCustomTimeSelected, isTrue);
      final expected = FacilityController.customSlotLabel(
        controller.customTime.value!,
      );
      expect(controller.selectedSlot.value, expected);
      expect(find.text('Custom time'), findsNothing);
      // The chip shows the chosen time, in the same design as a predefined slot.
      expect(
        find.descendant(
          of: find.byKey(const Key('facility-slot-custom')),
          matching: find.text(expected),
        ),
        findsOneWidget,
      );
      // And the derived interval is on screen.
      expect(find.text(controller.reservationRange!.label), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('facility-slot-custom')))
            .selected,
        isTrue,
      );
      expect(repository.createCalls, 0, reason: 'picking a time books nothing');

      // A predefined slot takes over again and clears the custom time.
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
    });
  });

  group('confirm button', () {
    testWidgets('is disabled until a date and a time are both chosen', (
      tester,
    ) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);
      final cta = find.byKey(const Key('confirm-reservation'));
      await scrollReservationTo(tester, cta);

      // No time yet.
      expect(controller.canConfirmBooking, isFalse);
      expect(
        tester.widget<AppPrimaryAction>(cta).onPressed,
        isNull,
        reason: 'the CTA must be inert without a time',
      );
      expect(
        find.text('Choose a date and a start time to continue.'),
        findsOneWidget,
      );

      controller.selectSlot(
        controller.selectedFacility.value!.availableSlots.first,
      );
      await tester.pumpAndSettle();

      expect(controller.canConfirmBooking, isTrue);
      expect(tester.widget<AppPrimaryAction>(cta).onPressed, isNotNull);
      expect(
        find.text('Choose a date and a start time to continue.'),
        findsNothing,
      );
    });

    testWidgets('is reachable after scrolling on a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = await pumpReservation(tester);
      controller.selectSlot(
        controller.selectedFacility.value!.availableSlots.first,
      );
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('confirm-reservation'));
      await scrollReservationTo(tester, cta);
      expect(cta, findsOneWidget);
      expect(cta.hitTestable(), findsOneWidget);
    });
  });

  group('reservation duration', () {
    testWidgets('one, two and three hour options change the end time', (
      tester,
    ) async {
      final controller = await pumpReservation(tester);
      final slot = controller.selectedFacility.value!.availableSlots.first;
      await tester.tap(find.byKey(Key('facility-slot-$slot')));
      await tester.pumpAndSettle();

      // The end time is derived, never picked by hand.
      expect(find.text('1 hour'), findsOneWidget);
      expect(find.text('2 hours'), findsOneWidget);
      expect(find.text('3 hours'), findsOneWidget);

      for (final hours in [1, 2, 3]) {
        await tester.tap(find.byKey(Key('facility-duration-$hours')));
        await tester.pumpAndSettle();
        expect(
          controller.selectedDurationHours.value,
          hours,
          reason: 'the selected duration is $hours',
        );
        // The chosen chip is the active one.
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(Key('facility-duration-$hours')))
              .selected,
          isTrue,
        );
        // The interval shown matches start plus the duration.
        final start = AppTimes.parse(slot)!;
        final end = AppTimes.addHours(start, hours);
        expect(
          find.text('${AppTimes.format(start)} – ${AppTimes.format(end)}'),
          findsOneWidget,
        );
      }
    });

    testWidgets('the confirm button is disabled when the booking will not fit', (
      tester,
    ) async {
      final controller = await pumpReservation(tester);
      // The gym closes at 10:00 PM, so a three hour slot at 8:00 PM cannot fit.
      controller.selectCustomTime(const TimeOfDay(hour: 20, minute: 0));
      controller.selectDuration(3);
      await tester.pumpAndSettle();

      expect(controller.durationError, isNotNull);
      expect(controller.canConfirmBooking, isFalse);
      await scrollReservationTo(
        tester,
        find.byKey(const Key('confirm-reservation')),
      );
      expect(
        tester
            .widget<AppPrimaryAction>(
              find.byKey(const Key('confirm-reservation')),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('confirmation dialog', () {
    testWidgets('shows the facility, date and time and books nothing yet', (
      tester,
    ) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);
      final date = controller.reservationDates[2];
      await tester.tap(find.byKey(Key('facility-date-$date')));
      final slot = controller.selectedFacility.value!.availableSlots.first;
      await tester.tap(find.byKey(Key('facility-slot-$slot')));
      await tester.pumpAndSettle();

      await openConfirmDialog(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const Key('app-confirm-dialog-title')), findsOneWidget);
      expect(
        find.byKey(const Key('app-confirm-dialog-message')),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      // The summary is inside the dialog, so these are the reviewed values.
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('Gym')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(AppDates.formatLong(AppDates.parse(date))),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(slot)),
        findsOneWidget,
      );
      // Opening the dialog must not create anything.
      expect(repository.createCalls, 0);
      expect(controller.reservations, hasLength(2));
    });

    testWidgets('cancelling closes it and keeps the selection', (tester) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);
      final slot = controller.selectedFacility.value!.availableSlots.first;
      await tester.tap(find.byKey(Key('facility-slot-$slot')));
      await tester.pumpAndSettle();

      await openConfirmDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Please review your reservation details'), findsNothing);
      expect(controller.selectedSlot.value, slot);
      expect(controller.selectedFacility.value, isNotNull);
      expect(repository.createCalls, 0);
    });

    testWidgets('a failed booking keeps the dialog open and can be retried', (
      tester,
    ) async {
      final repository = TestRepository(
        failureMessage: 'That time slot is no longer available.',
      );
      final controller = await pumpReservation(tester, repository: repository);
      final slot = controller.selectedFacility.value!.availableSlots.first;
      await tester.tap(find.byKey(Key('facility-slot-$slot')));
      await tester.pumpAndSettle();

      await openConfirmDialog(tester);
      await tester.tap(find.byKey(const Key('app-confirm-dialog-confirm')));
      await tester.pumpAndSettle();

      // Still in the flow, with the reason and the selection intact.
      expect(find.byKey(const Key('app-confirm-dialog-error')), findsOneWidget);
      expect(
        find.text('That time slot is no longer available.'),
        findsOneWidget,
      );
      expect(find.byType(FacilityReservationPage), findsOneWidget);
      expect(controller.selectedSlot.value, slot);
      expect(controller.selectedDate.value.isNotEmpty, isTrue);
      // Not treated as a success.
      expect(find.byType(BookingConfirmedPage), findsNothing);
    });

    testWidgets('a second tap while submitting does not book twice', (
      tester,
    ) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);
      controller.selectSlot(
        controller.selectedFacility.value!.availableSlots.first,
      );
      await tester.pumpAndSettle();

      repository.gate = Completer<FacilityReservation>();
      await openConfirmDialog(tester);

      final confirm = find.byKey(const Key('app-confirm-dialog-confirm'));
      await tester.tap(confirm);
      await tester.pump();
      expect(find.text('Booking...'), findsOneWidget);

      // Keep tapping while the request is in flight.
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pump();
      expect(repository.createCalls, 1);

      final held = repository.gate!;
      // Release the held call with a real create, done on a separate
      // repository so the test's own call counter stays honest.
      final result = await FacilityRepositoryImpl(FacilityLocalDataSource())
          .createReservation(buildTestReservation(controller));
      held.complete(result);

      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(find.byType(BookingConfirmedPage), findsOneWidget);
    });
  });

  group('successful reservation', () {
    testWidgets(
      'confirms, navigates to the success page and lists the booking',
      (tester) async {
        final repository = TestRepository();
        final controller = await pumpReservation(
          tester,
          repository: repository,
        );
        final date = controller.reservationDates[1];
        await tester.tap(find.byKey(Key('facility-date-$date')));
        final slot = controller.selectedFacility.value!.availableSlots.first;
        await tester.tap(find.byKey(Key('facility-slot-$slot')));
        await tester.pumpAndSettle();

        await openConfirmDialog(tester);
        await tester.tap(find.byKey(const Key('app-confirm-dialog-confirm')));
        await tester.pumpAndSettle();

        // Success page, with the custom app bar and the reference.
        expect(find.byType(BookingConfirmedPage), findsOneWidget);
        expect(
          find.byKey(const Key('booking-confirmed-title')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Your facility reservation has been successfully confirmed.',
          ),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsNothing);
        final created = controller.bookingSuccess.value!;
        expect(created.id, isNotEmpty, reason: 'a reference is assigned');
        expect(find.text('#${created.id}'), findsOneWidget);
        expect(find.text('Confirmed'), findsOneWidget);

        // Done lands on My Reservations with the new booking already there.
        await tester.tap(find.byKey(const Key('booking-confirmed-done')));
        await tester.pumpAndSettle();

        expect(find.byType(MyReservationsPage), findsOneWidget);
        expect(
          find.byKey(Key('reservation-card-${created.id}')),
          findsOneWidget,
          reason: 'the new reservation appears straight away',
        );
        expect(find.text('Upcoming'), findsOneWidget);
      },
    );

    testWidgets('a custom time booking is stored with its label', (
      tester,
    ) async {
      final repository = TestRepository();
      final controller = await pumpReservation(tester, repository: repository);

      await tester.tap(find.byKey(const Key('facility-slot-custom')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await openConfirmDialog(tester);
      final start = controller.selectedStartTimeLabel!;
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(start)),
        findsOneWidget,
        reason: 'the dialog shows the start time',
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(controller.reservationRange!.label),
        ),
        findsOneWidget,
        reason: 'and the interval it adds up to',
      );
      await tester.tap(find.byKey(const Key('app-confirm-dialog-confirm')));
      await tester.pumpAndSettle();

      final created = controller.bookingSuccess.value!;
      // Stored as the interval, with the start time kept for availability.
      expect(created.time, controller.reservationRange!.label);
      expect(created.startTime, start);
      expect(created.isCustomTime, isTrue);
    });
  });

  group('end to end', () {
    testWidgets('facilities to booking to my reservations to details', (
      tester,
    ) async {
      final repository = TestRepository();
      final controller = await registerController(repository);
      final before = controller.reservations.length;
      await pumpPage(tester, const FacilitiesPage());

      // The amenities grid is untouched and offers a way into the list.
      expect(find.text('Your amenities'), findsOneWidget);
      expect(
        find.byKey(const Key('facilities-my-reservations')),
        findsOneWidget,
      );

      // Reserve the gym straight from the grid.
      final reserve = find.byKey(const Key('reserve-facility-facility-gym'));
      await tester.ensureVisible(reserve);
      await tester.pumpAndSettle();
      await tester.tap(reserve);
      await tester.pumpAndSettle();
      expect(find.byType(FacilityReservationPage), findsOneWidget);
      expect(find.byType(AppBar), findsNothing, reason: 'custom app bar only');

      final slot = controller.selectedFacility.value!.availableSlots.first;
      await tester.tap(find.byKey(Key('facility-slot-$slot')));
      await tester.pumpAndSettle();

      await openConfirmDialog(tester);
      await tester.tap(find.byKey(const Key('app-confirm-dialog-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(BookingConfirmedPage), findsOneWidget);

      final created = controller.bookingSuccess.value!;
      expect(controller.reservations, hasLength(before + 1));

      // Done lands on My Reservations with the new booking at the top.
      await tester.tap(find.byKey(const Key('booking-confirmed-done')));
      await tester.pumpAndSettle();
      expect(find.byType(MyReservationsPage), findsOneWidget);
      expect(find.byKey(Key('reservation-card-${created.id}')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Key('reservation-card-${created.id}')),
          matching: find.text('Gym'),
        ),
        findsOneWidget,
      );

      // And the card opens the details page.
      await tester.tap(find.byKey(Key('reservation-card-${created.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationDetailPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('reservation-detail-summary')),
          matching: find.text('#${created.id}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the facilities page opens my reservations', (tester) async {
      await registerController(TestRepository());
      await pumpPage(tester, const FacilitiesPage());

      await tester.tap(find.byKey(const Key('facilities-my-reservations')));
      await tester.pumpAndSettle();

      expect(find.byType(MyReservationsPage), findsOneWidget);
      expect(find.text('My Reservations'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    });
  });

  group('my reservations', () {
    testWidgets('splits upcoming from past and shows the status', (
      tester,
    ) async {
      final controller = await registerController(TestRepository());
      await pumpPage(tester, const MyReservationsPage());

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(controller.upcomingReservations, hasLength(1));
      expect(controller.pastReservations, hasLength(1));

      // The upcoming BBQ booking is Confirmed, the past gym one Completed.
      final upcoming = controller.upcomingReservations.single;
      final past = controller.pastReservations.single;
      expect(
        find.byKey(Key('reservation-card-${upcoming.id}')),
        findsOneWidget,
      );
      expect(find.byKey(Key('reservation-card-${past.id}')), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('#${upcoming.id}'), findsOneWidget);
      // The card reads the date in full.
      expect(
        find.text(AppDates.formatLong(AppDates.parse(upcoming.date))),
        findsOneWidget,
      );
    });

    testWidgets('shows an empty state with a way back to facilities', (
      tester,
    ) async {
      await registerController(TestRepository(reservations: []));
      await pumpPage(tester, const MyReservationsPage());

      expect(find.byKey(const Key('my-reservations-empty')), findsOneWidget);
      expect(find.text('No Reservations Yet'), findsOneWidget);
      expect(
        find.text("You haven't reserved any facilities yet."),
        findsOneWidget,
      );
      expect(find.text('Explore Facilities'), findsOneWidget);

      await tester.tap(find.text('Explore Facilities'));
      await tester.pumpAndSettle();
      expect(find.text('No Reservations Yet'), findsNothing);
    });

    testWidgets('shows a friendly error and retries', (tester) async {
      final repository = TestRepository(reservations: []);
      await registerController(repository);

      // The page's own load fails, so the error state is what it renders.
      repository.failLoads = true;
      await pumpPage(tester, const MyReservationsPage());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load reservations'), findsOneWidget);
      expect(find.text('Unable to load your reservations.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byKey(const Key('my-reservations-scroll')), findsNothing);

      // The retry recovers without leaving the screen.
      repository
        ..failLoads = false
        ..reservations = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load reservations'), findsNothing);
      expect(find.byKey(const Key('my-reservations-scroll')), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('opens the reservation details page', (tester) async {
      final controller = await registerController(TestRepository());
      await pumpPage(tester, const MyReservationsPage());

      final reservation = controller.upcomingReservations.single;
      await tester.tap(find.byKey(Key('reservation-card-${reservation.id}')));
      await tester.pumpAndSettle();

      expect(find.byType(ReservationDetailPage), findsOneWidget);
      expect(find.text('Reservation Details'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      // Scoped to the details card, since the list is still mounted behind it.
      expect(
        find.descendant(
          of: find.byKey(const Key('reservation-detail-summary')),
          matching: find.text('BBQ Area'),
        ),
        findsOneWidget,
      );
      expect(find.text('#${reservation.id}'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('reservation-detail-summary')),
          matching: find.text('Confirmed'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('handles a long facility name and a long reference', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const longName =
          'Rooftop Sky Garden Multipurpose Recreation And Wellness Deck';
      await registerController(
        TestRepository(
          facilities: [
            const Facility(
              id: 'facility-long',
              name: longName,
              imagePath: 'assets/images/amenities/bbq_area.jpg',
              location: 'Rooftop · Tower B · Level 42',
              description:
                  'A very long description that must not break the card.',
              rules: 'Rules that are long enough to wrap onto a second line.',
              openingHours: '6:00 AM – 11:00 PM',
              capacity: 40,
              availableSlots: ['6:00 PM'],
            ),
          ],
          reservations: [
            FacilityReservation(
              id: 'RES-2026-000417-ROOFTOP-SKY-GARDEN-DECK',
              facilityId: 'facility-long',
              facilityName: longName,
              date: AppDates.format(
                DateTime.now().add(const Duration(days: 1)),
              ),
              time: 'Custom · 7:45 AM',
              status: 'Confirmed',
              createdAt: AppDates.format(DateTime.now()),
              isCustomTime: true,
            ),
          ],
        ),
      );
      await pumpPage(tester, const MyReservationsPage());

      // The card renders with the long values truncated rather than overflowing.
      expect(find.text('Upcoming'), findsOneWidget);
      expect(
        find.byKey(
          const Key('reservation-card-RES-2026-000417-ROOFTOP-SKY-GARDEN-DECK'),
        ),
        findsOneWidget,
      );

      // The same long values are safe in the dialog too.
      final controller = Get.find<FacilityController>();
      controller.selectFacility(controller.facilities.first);
      controller.selectCustomTime(const TimeOfDay(hour: 19, minute: 45));
      await tester.pumpAndSettle();
      await pumpPage(tester, const FacilityReservationPage());
      await openConfirmDialog(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(longName)),
        findsOneWidget,
      );
    });

    testWidgets('has no overflow on a small android screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = await registerController(TestRepository());
      await pumpPage(tester, const MyReservationsPage());

      // Any RenderFlex overflow is reported as a test failure, so walking the
      // whole list is the assertion.
      for (final reservation in controller.reservations) {
        final finder = find.byKey(Key('reservation-card-${reservation.id}'));
        expect(finder, findsOneWidget, reason: '${reservation.id} must render');
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
    });
  });
}
