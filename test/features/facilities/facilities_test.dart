import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/core/utils/app_dates.dart';
import 'package:test/features/facilities/data/datasources/facility_local_data_source.dart';
import 'package:test/features/facilities/domain/entities/facility.dart';
import 'package:test/features/facilities/domain/entities/facility_reservation_status.dart';
import 'package:test/features/facilities/data/repositories/facility_repository_impl.dart';
import 'package:test/features/facilities/domain/repositories/facility_repository.dart';
import 'package:test/features/facilities/domain/usecases/facility_usecases.dart';
import 'package:test/features/facilities/presentation/bindings/facility_binding.dart';
import 'package:test/features/facilities/presentation/controllers/facility_controller.dart';
import 'package:test/core/utils/app_times.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('loads facilities and existing reservations', () async {
    final repository = FacilityRepositoryImpl(FacilityLocalDataSource());
    final controller = FacilityController(FacilityUseCases(repository));

    await controller.loadFacilities();

    expect(controller.facilities, hasLength(6));
    expect(controller.reservations, hasLength(2));
    expect(controller.facilities.first.name, 'Fitness Centre');
  });

  test('selects a facility and books an available slot locally', () async {
    final repository = FacilityRepositoryImpl(FacilityLocalDataSource());
    final controller = FacilityController(FacilityUseCases(repository));
    await controller.loadFacilities();

    final facility = controller.facilities.first;
    controller.selectFacility(facility);
    controller.selectDate(controller.reservationDates[2]);
    controller.selectSlot(facility.availableSlots.first);

    final reservation = await controller.bookSelectedSlot();

    expect(reservation, isNotNull);
    expect(reservation!.facilityName, 'Fitness Centre');
    expect(reservation.status, 'Confirmed');
    expect(controller.reservations, hasLength(3));
    expect(
      controller.facilities.first.availableSlots,
      isNot(contains(facility.availableSlots.first)),
    );
  });

  test('offers today and the next five days from the current date', () {
    final controller = FacilityController(
      FacilityUseCases(FacilityRepositoryImpl(FacilityLocalDataSource())),
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expected = List.generate(
      FacilityController.reservationWindowDays,
      (index) => AppDates.format(today.add(Duration(days: index))),
    );

    expect(controller.reservationDates, expected);
    expect(controller.reservationDates, hasLength(6));
    expect(controller.reservationDates.first, AppDates.format(today));
    expect(controller.selectedDate.value, AppDates.format(today));
  });

  test('books a custom time without consuming a predefined slot', () async {
    final controller = FacilityController(
      FacilityUseCases(FacilityRepositoryImpl(FacilityLocalDataSource())),
    );
    await controller.loadFacilities();

    final facility = controller.facilities.first;
    controller.selectFacility(facility);
    final slotsBefore = List<String>.of(facility.availableSlots);
    controller.selectCustomTime(const TimeOfDay(hour: 7, minute: 45));

    expect(controller.isCustomTimeSelected, isTrue);
    expect(controller.selectedStartTimeLabel, '7:45 AM');
    expect(controller.reservationRange?.label, '7:45 AM – 8:45 AM');
    expect(slotsBefore, isNot(contains(controller.selectedStartTimeLabel)));

    final reservation = await controller.bookSelectedSlot();

    expect(reservation, isNotNull);
    // Stored as the interval the resident actually booked.
    expect(reservation!.time, '7:45 AM – 8:45 AM');
    expect(reservation.startTime, '7:45 AM');
    expect(reservation.durationHours, 1);
    expect(reservation.date, AppDates.format(DateTime.now()));
    expect(controller.errorMessage.value, isNull);
    // The facility keeps every one of its own slots.
    expect(controller.facilities.first.availableSlots, slotsBefore);
  });

  test('a custom time is replaced by a predefined slot', () {
    final controller = FacilityController(
      FacilityUseCases(FacilityRepositoryImpl(FacilityLocalDataSource())),
    );

    controller.selectCustomTime(const TimeOfDay(hour: 19, minute: 0));
    expect(controller.selectedSlot.value, '7:00 PM');

    controller.selectSlot('6:00 PM - 7:00 PM');

    expect(controller.selectedSlot.value, '6:00 PM - 7:00 PM');
    expect(controller.customTime.value, isNull);
    expect(controller.isCustomTimeSelected, isFalse);
  });

  test('a time that is neither predefined nor custom is rejected', () async {
    final repository = FacilityRepositoryImpl(FacilityLocalDataSource());
    final controller = FacilityController(FacilityUseCases(repository));
    await controller.loadFacilities();

    controller.selectFacility(controller.facilities.first);
    controller.selectedSlot.value = '3:00 AM - 4:00 AM';

    expect(await controller.bookSelectedSlot(), isNull);
    expect(controller.errorMessage.value, 'Choose an available time slot.');
  });

  test('a new reservation gets a reference and lands in the list', () async {
    final repository = FacilityRepositoryImpl(FacilityLocalDataSource());
    final controller = FacilityController(FacilityUseCases(repository));
    await controller.loadFacilities();

    controller.selectFacility(controller.facilities.first);
    controller.selectDate(controller.reservationDates[1]);
    controller.selectSlot(controller.facilities.first.availableSlots.first);

    final reservation = await controller.bookSelectedSlot();

    expect(reservation, isNotNull);
    // The data source hands out the reference, the way a backend would.
    expect(reservation!.id, matches(RegExp(r'^RES-\d{3}$')));
    expect(reservation.id, isNot('RES-001'), reason: 'not a seeded reference');
    expect(reservation.createdAt, AppDates.format(DateTime.now()));
    // Visible in the controller list and on the next load, with no duplicates.
    expect(controller.reservations.first.id, reservation.id);
    await controller.loadReservations();
    expect(
      controller.reservations.where((item) => item.id == reservation.id),
      hasLength(1),
    );
  });

  test('confirmation needs a facility, a date and a time', () async {
    final controller = FacilityController(
      FacilityUseCases(FacilityRepositoryImpl(FacilityLocalDataSource())),
    );
    await controller.loadFacilities();

    expect(controller.canConfirmBooking, isFalse, reason: 'no facility yet');

    controller.selectFacility(controller.facilities.first);
    expect(controller.canConfirmBooking, isFalse, reason: 'no time yet');

    controller.selectDate(controller.reservationDates[0]);
    expect(controller.canConfirmBooking, isFalse, reason: 'no time yet');

    controller.selectSlot(controller.facilities.first.availableSlots.first);
    expect(controller.canConfirmBooking, isTrue);
  });

  test('splits the seeded reservations into upcoming and past', () async {
    final controller = FacilityController(
      FacilityUseCases(FacilityRepositoryImpl(FacilityLocalDataSource())),
    );
    await controller.loadReservations();

    final upcoming = controller.upcomingReservations;
    final past = controller.pastReservations;

    expect(upcoming, hasLength(1));
    expect(past, hasLength(1));
    expect(upcoming.single.status, 'Confirmed');
    expect(past.single.status, 'Completed');
    // Nothing is in both groups.
    expect(
      upcoming
          .map((item) => item.id)
          .toSet()
          .intersection(past.map((item) => item.id).toSet()),
      isEmpty,
    );
    // The past booking happened before the upcoming one.
    expect(
      reservationStart(past.single).isBefore(reservationStart(upcoming.single)),
      isTrue,
    );
  });

  test('a reservation later today is upcoming until its time passes', () {
    final now = DateTime.now();
    final later = now.add(const Duration(hours: 2));
    final earlier = now.subtract(const Duration(hours: 2));

    FacilityReservation at(DateTime when) => FacilityReservation(
      id: 'X',
      facilityId: 'facility-gym',
      facilityName: 'Fitness Centre',
      date: AppDates.format(when),
      time: FacilityController.formatTime(
        TimeOfDay(hour: when.hour, minute: when.minute),
      ),
      status: 'Confirmed',
      createdAt: AppDates.format(when),
    );

    expect(isReservationPast(at(later)), isFalse);
    expect(isReservationPast(at(earlier)), isTrue);
    // A cancelled booking is always past, whatever its date says.
    expect(
      isReservationPast(
        FacilityReservation(
          id: 'Y',
          facilityId: 'facility-gym',
          facilityName: 'Fitness Centre',
          date: AppDates.format(later),
          time: '6:00 PM',
          status: 'Cancelled',
          createdAt: AppDates.format(now),
        ),
      ),
      isTrue,
    );
  });

  test('a custom time label is understood when grouping', () {
    final now = DateTime.now();
    final later = now.add(const Duration(days: 1));
    final reservation = FacilityReservation(
      id: 'Z',
      facilityId: 'facility-gym',
      facilityName: 'Fitness Centre',
      date: AppDates.format(later),
      time: FacilityController.customSlotLabel(
        const TimeOfDay(hour: 19, minute: 5),
      ),
      status: 'Confirmed',
      createdAt: AppDates.format(now),
      isCustomTime: true,
    );

    expect(reservation.time, '7:05 PM');
    expect(isReservationPast(reservation), isFalse);
  });

  group('reservation duration', () {
    Future<FacilityController> buildController() async {
      final controller = FacilityController(
        FacilityUseCases(FacilityRepositoryImpl(FacilityLocalDataSource())),
      );
      await controller.loadFacilities();
      return controller;
    }

    test(
      'a one, two or three hour booking all calculate an end time',
      () async {
        final controller = await buildController();
        final gym = controller.facilities.firstWhere(
          (item) => item.availableSlots.contains('6:00 PM'),
        );
        controller.selectFacility(gym);
        controller.selectSlot('6:00 PM');

        const expected = {
          1: '6:00 PM – 7:00 PM',
          2: '6:00 PM – 8:00 PM',
          3: '6:00 PM – 9:00 PM',
        };
        for (final hours in FacilityController.reservationDurations) {
          controller.selectDuration(hours);
          expect(
            controller.reservationRange?.label,
            expected[hours],
            reason: '$hours hour booking',
          );
          expect(controller.canConfirmBooking, isTrue);
        }
      },
    );

    test('the duration is always one the app offers', () async {
      final controller = await buildController();
      controller.selectDuration(3);
      controller.selectDuration(9);
      expect(controller.selectedDurationHours.value, 3);
    });

    test('a booking that would run past closing is rejected', () async {
      final controller = await buildController();
      final gym = controller.facilities.firstWhere(
        (item) => item.id == 'facility-gym',
      );
      controller.selectFacility(gym);
      // The gym closes at 10:00 PM.
      controller.selectCustomTime(const TimeOfDay(hour: 22, minute: 0));
      controller.selectDuration(1);

      expect(controller.reservationRange?.label, '10:00 PM – 11:00 PM');
      expect(controller.durationError, isNotNull);
      expect(controller.canConfirmBooking, isFalse);
    });

    test('a booking that rolls past midnight is rejected', () async {
      final controller = await buildController();
      final gym = controller.facilities.firstWhere(
        (item) => item.id == 'facility-gym',
      );
      controller.selectFacility(gym);
      controller.selectCustomTime(const TimeOfDay(hour: 23, minute: 30));
      controller.selectDuration(2);

      expect(controller.reservationRange?.nextDay, isTrue);
      expect(controller.durationError, isNotNull);
      expect(controller.canConfirmBooking, isFalse);
    });

    test('a valid booking is refused to book when it does not fit', () async {
      final controller = await buildController();
      final gym = controller.facilities.firstWhere(
        (item) => item.id == 'facility-gym',
      );
      controller.selectFacility(gym);
      controller.selectCustomTime(const TimeOfDay(hour: 22, minute: 0));
      controller.selectDuration(3);

      expect(await controller.bookSelectedSlot(), isNull);
      expect(controller.errorMessage.value, isNotNull);
      // Nothing new was created.
      expect(controller.reservations, hasLength(2));
    });
  });

  group('visitor time arithmetic', () {
    test('adds two hours to an arrival time', () {
      expect(AppTimeRange.fromLabel('2:00 PM', 2)!.label, '2:00 PM – 4:00 PM');
      expect(
        AppTimeRange.fromLabel('10:30 AM', 2)!.label,
        '10:30 AM – 12:30 PM',
      );
    });

    test('handles midnight and noon rollover', () {
      expect(
        AppTimeRange.fromLabel('11:00 PM', 2)!.label,
        '11:00 PM – 1:00 AM (next day)',
      );
      final range = AppTimeRange.fromLabel('11:00 PM', 2)!;
      expect(range.nextDay, isTrue);
      expect(range.end, const TimeOfDay(hour: 1, minute: 0));
    });

    test('parses a time out of a stored range', () {
      expect(
        AppTimes.parse('2:00 PM – 4:00 PM'),
        const TimeOfDay(hour: 14, minute: 0),
      );
      expect(AppTimes.parse('12:00 AM'), const TimeOfDay(hour: 0, minute: 0));
      expect(AppTimes.parse('12:00 PM'), const TimeOfDay(hour: 12, minute: 0));
      expect(AppTimes.parse('no time here'), isNull);
    });
  });

  test('binding provides the facilities dependency graph', () {
    FacilityBinding().dependencies();

    expect(Get.find<FacilityRepository>(), isA<FacilityRepositoryImpl>());
    expect(Get.find<FacilityUseCases>(), isA<FacilityUseCases>());
    expect(Get.find<FacilityController>(), isA<FacilityController>());
    expect(
      Get.find<FacilityController>().useCases.repository,
      isA<FacilityRepositoryImpl>(),
    );
  });
}
