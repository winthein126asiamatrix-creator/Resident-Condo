import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/lease/data/datasources/lease_local_data_source.dart';
import 'package:test/features/lease/data/repositories/lease_repository_impl.dart';
import 'package:test/features/lease/domain/entities/lease.dart';
import 'package:test/features/lease/domain/repositories/lease_repository.dart';
import 'package:test/features/lease/domain/usecases/lease_usecases.dart';
import 'package:test/features/lease/presentation/bindings/lease_binding.dart';
import 'package:test/features/lease/presentation/controllers/lease_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  LeaseController buildController() {
    final repository = LeaseRepositoryImpl(LeaseLocalDataSource());
    return LeaseController(LeaseUseCases(repository));
  }

  test('loads the active lease with progress and expiry', () async {
    final controller = buildController();
    await controller.loadLeases();

    final lease = controller.activeLease!;
    expect(lease.reference, 'LSE-2026-0042');
    expect(lease.monthlyRent, 2400);
    expect(lease.tenant.name, 'Jamie Rivera');
    expect(lease.progress, greaterThan(0.8));
    expect(lease.daysRemaining, greaterThan(0));
    expect(lease.isExpiringSoon, isTrue);
    expect(lease.status, LeaseStatus.expiringSoon);
  });

  test('submits a renewal request', () async {
    final controller = buildController();
    await controller.loadLeases();
    final lease = controller.activeLease!;

    final renewal = await controller.requestRenewal(
      lease: lease,
      proposedStart: DateTime(2026, 11, 1),
      proposedEnd: DateTime(2027, 10, 31),
      proposedRent: 2460,
      note: 'Agreed with the tenant.',
    );

    expect(renewal, isNotNull);
    expect(renewal!.status, RenewalStatus.pending);
    expect(controller.pendingRenewal?.id, renewal.id);
  });

  test('rejects an invalid renewal and can withdraw a pending one', () async {
    final controller = buildController();
    await controller.loadLeases();
    final lease = controller.activeLease!;

    final invalid = await controller.requestRenewal(
      lease: lease,
      proposedStart: DateTime(2027, 1, 1),
      proposedEnd: DateTime(2026, 1, 1),
      proposedRent: 2400,
    );
    expect(invalid, isNull);
    expect(controller.errorMessage.value, isNotNull);

    final renewal = await controller.requestRenewal(
      lease: lease,
      proposedStart: DateTime(2026, 11, 1),
      proposedEnd: DateTime(2027, 10, 31),
      proposedRent: 2400,
    );
    final withdrawn = await controller.withdrawRenewal(renewal!);
    expect(withdrawn!.status, RenewalStatus.withdrawn);
    expect(controller.pendingRenewal, isNull);
  });

  test('binding provides the lease dependency graph', () {
    LeaseBinding().dependencies();

    expect(Get.find<LeaseRepository>(), isA<LeaseRepositoryImpl>());
    expect(Get.isRegistered<LeaseController>(), isTrue);
  });
}
