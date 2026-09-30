import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/core/utils/app_dates.dart';
import 'package:test/features/facilities/data/datasources/facility_local_data_source.dart';
import 'package:test/features/facilities/data/repositories/facility_repository_impl.dart';
import 'package:test/features/facilities/domain/repositories/facility_repository.dart';
import 'package:test/features/facilities/domain/usecases/facility_usecases.dart';
import 'package:test/features/facilities/presentation/bindings/facility_binding.dart';
import 'package:test/features/facilities/presentation/controllers/facility_controller.dart';

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
    expect(controller.selectedSlot.value, 'Custom · 7:45 AM');
    expect(slotsBefore, isNot(contains(controller.selectedSlot.value)));

    final reservation = await controller.bookSelectedSlot();

    expect(reservation, isNotNull);
    expect(reservation!.time, 'Custom · 7:45 AM');
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
    expect(controller.selectedSlot.value, 'Custom · 7:00 PM');

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
