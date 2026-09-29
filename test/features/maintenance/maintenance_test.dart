import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/maintenance/data/datasources/maintenance_local_data_source.dart';
import 'package:test/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:test/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:test/features/maintenance/domain/usecases/maintenance_usecases.dart';
import 'package:test/features/maintenance/presentation/bindings/maintenance_binding.dart';
import 'package:test/features/maintenance/presentation/controllers/maintenance_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('loads mock maintenance requests and counts', () async {
    final repository = MaintenanceRepositoryImpl(MaintenanceLocalDataSource());
    final controller = MaintenanceController(MaintenanceUseCases(repository));

    await controller.loadRequests();

    expect(controller.requests, hasLength(4));
    expect(controller.inProgressCount, 1);
    expect(controller.completedCount, 2);
    expect(controller.requests.first.title, 'Leaking kitchen sink');
  });

  test('creates a request and advances status locally', () async {
    final repository = MaintenanceRepositoryImpl(MaintenanceLocalDataSource());
    final controller = MaintenanceController(MaintenanceUseCases(repository));

    final created = await controller.createRequest(
      title: 'Bathroom tap dripping',
      category: MaintenanceCategory.plumbing,
      description: 'The bathroom tap continues to drip after use.',
      location: 'Bathroom',
      priority: MaintenancePriority.low,
      preferredDate: 'Sep 30, 2026',
      preferredTime: '10:00 AM',
      photoNames: ['Photo 1 attached'],
    );

    expect(created, isNotNull);
    expect(controller.requests.first.status, MaintenanceStatus.submitted);
    expect(controller.requests.first.photoCount, 1);

    final assigned = await controller.advanceRequest(controller.requests.first);
    expect(assigned?.status, MaintenanceStatus.assigned);

    final inProgress = await controller.advanceRequest(
      controller.requests.first,
    );
    expect(inProgress?.status, MaintenanceStatus.inProgress);

    final completed = await controller.advanceRequest(
      controller.requests.first,
    );
    expect(completed?.status, MaintenanceStatus.completed);
  });

  test('binding provides the maintenance dependency graph', () {
    MaintenanceBinding().dependencies();

    expect(Get.find<MaintenanceRepository>(), isA<MaintenanceRepositoryImpl>());
    expect(Get.find<MaintenanceUseCases>(), isA<MaintenanceUseCases>());
    expect(Get.find<MaintenanceController>(), isA<MaintenanceController>());
    expect(
      Get.find<MaintenanceController>().useCases.repository,
      isA<MaintenanceRepositoryImpl>(),
    );
  });
}
