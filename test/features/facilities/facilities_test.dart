import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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
    controller.selectDate('Sep 26, 2026');
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
