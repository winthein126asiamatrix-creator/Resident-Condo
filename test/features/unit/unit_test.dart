import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/unit/data/datasources/unit_local_data_source.dart';
import 'package:test/features/unit/data/repositories/unit_repository_impl.dart';
import 'package:test/features/unit/domain/repositories/unit_repository.dart';
import 'package:test/features/unit/domain/usecases/unit_usecases.dart';
import 'package:test/features/unit/presentation/bindings/unit_binding.dart';
import 'package:test/features/unit/presentation/controllers/unit_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('loads mock unit data through the use case', () async {
    final repository = UnitRepositoryImpl(UnitLocalDataSource());
    final unit = await UnitUseCases(repository).getMyUnit();

    expect(unit.tower, 'Tower A');
    expect(unit.unitNumber, '1205');
    expect(unit.floor, '12th floor');
    expect(unit.ownershipStatus, 'Owner');
    expect(unit.occupancyStatus, 'Occupied');
    expect(unit.residents, hasLength(2));
    expect(unit.tenant, isNotNull);
    expect(unit.tenant!.name, 'Jamie Rivera');
    expect(unit.parking.slot, 'B2-125');
  });

  test('binding provides the unit dependency graph', () async {
    UnitBinding().dependencies();

    expect(Get.find<UnitRepository>(), isA<UnitRepositoryImpl>());
    expect(Get.find<UnitUseCases>(), isA<UnitUseCases>());

    final controller = Get.find<UnitController>();
    expect(controller.useCases.repository, isA<UnitRepositoryImpl>());

    await controller.loadMyUnit();
    expect(controller.unit.value?.unitNumber, '1205');
  });
}
