import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/complaints/data/datasources/complaint_local_data_source.dart';
import 'package:test/features/complaints/data/repositories/complaint_repository_impl.dart';
import 'package:test/features/complaints/domain/entities/complaint.dart';
import 'package:test/features/complaints/domain/usecases/complaint_usecases.dart';
import 'package:test/features/complaints/presentation/bindings/complaint_binding.dart';
import 'package:test/features/complaints/presentation/controllers/complaint_controller.dart';
import 'package:test/features/parking/data/datasources/parking_local_data_source.dart';
import 'package:test/features/parking/data/repositories/parking_repository_impl.dart';
import 'package:test/features/parking/domain/usecases/parking_usecases.dart';
import 'package:test/features/parking/presentation/bindings/parking_binding.dart';
import 'package:test/features/parking/presentation/controllers/parking_controller.dart';
import 'package:test/features/rules/data/datasources/rules_local_data_source.dart';
import 'package:test/features/rules/data/repositories/rules_repository_impl.dart';
import 'package:test/features/rules/domain/entities/rules.dart';
import 'package:test/features/rules/domain/usecases/rules_usecases.dart';
import 'package:test/features/rules/presentation/bindings/rules_binding.dart';
import 'package:test/features/rules/presentation/controllers/rules_controller.dart';
import 'package:test/features/services/data/datasources/condo_service_local_data_source.dart';
import 'package:test/features/services/data/repositories/condo_service_repository_impl.dart';
import 'package:test/features/services/domain/entities/condo_service.dart';
import 'package:test/features/services/domain/usecases/condo_service_usecases.dart';
import 'package:test/features/services/presentation/bindings/condo_service_binding.dart';
import 'package:test/features/services/presentation/controllers/condo_service_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('condo services are a separate workflow from maintenance', () async {
    final repository = CondoServiceRepositoryImpl(CondoServiceLocalDataSource());
    final controller = CondoServiceController(CondoServiceUseCases(repository));

    await controller.loadAll();

    expect(controller.services, hasLength(7));
    expect(controller.requests, hasLength(2));
    expect(controller.openRequestCount, 1);

    final deepClean = controller.services.first;
    controller.selectService(deepClean);
    final request = await controller.bookService(
      service: deepClean,
      date: 'Sep 27, 2026',
      slot: '9:00 AM – 11:00 AM',
    );

    expect(request!.status, ServiceRequestStatus.requested);
    expect(controller.openRequestCount, 2);
  });

  test('a service request can be cancelled and rated', () async {
    final repository = CondoServiceRepositoryImpl(CondoServiceLocalDataSource());
    final controller = CondoServiceController(CondoServiceUseCases(repository));
    await controller.loadAll();

    final scheduled = controller.requests.firstWhere(
      (item) => item.status == ServiceRequestStatus.scheduled,
    );
    final cancelled = await controller.cancelRequest(scheduled);
    expect(cancelled!.status, ServiceRequestStatus.cancelled);

    final completed = controller.requests.firstWhere(
      (item) => item.status == ServiceRequestStatus.completed,
    );
    final rated = await controller.rateRequest(completed, 4, 'Good service');
    expect(rated!.rating, 4);
  });

  test('parking keeps the allocated bay, log and guest requests', () async {
    final repository = ParkingRepositoryImpl(ParkingLocalDataSource());
    final controller = ParkingController(ParkingUseCases(repository));

    await controller.loadParking();

    expect(controller.mySpace.value!.slot, 'B2-125');
    expect(controller.mySpace.value!.monthlyFee, 45);
    expect(controller.events, hasLength(4));
    expect(controller.availableCount, 1);

    final updated = await controller.updateVehicle('Honda Civic', 'XYZ-7788');
    expect(updated, isNull, reason: 'a duplicate plate must be rejected');

    final guest = await controller.requestGuestParking(
      guestName: 'Jamie Johnson',
      vehicle: 'Nissan Leaf',
      plate: 'KLM-2210',
      date: 'Sep 26, 2026',
      window: '10:00 AM – 6:00 PM',
    );
    expect(guest!.status, 'Pending review');

    final cancelled = await controller.cancelGuestParking(guest);
    expect(cancelled!.status, 'Cancelled');
  });

  test('complaints are tracked separately from violations', () async {
    final repository = ComplaintRepositoryImpl(ComplaintLocalDataSource());
    final controller = ComplaintController(ComplaintUseCases(repository));

    await controller.loadComplaints();

    expect(controller.complaints, hasLength(2));
    expect(controller.openCount, 1);

    final filed = await controller.fileComplaint(
      category: ComplaintCategory.parking,
      subject: 'Blocked driveway again',
      description: 'A delivery truck blocked the exit ramp for ten minutes.',
      location: 'Tower A · Level 1',
      priority: ComplaintPriority.high,
      isAnonymous: false,
    );

    expect(filed!.reference, startsWith('CMP-2026-'));
    expect(controller.openCount, 2);

    final commented = await controller.addComment(filed, 'Following up here.');
    expect(commented!.comments, hasLength(1));

    final withdrawn = await controller.withdraw(filed);
    expect(withdrawn!.status, ComplaintStatus.withdrawn);
  });

  test('rules list fines and a violation can be appealed', () async {
    final repository = RulesRepositoryImpl(RulesLocalDataSource());
    final controller = RulesController(RulesUseCases(repository));

    await controller.loadAll();

    expect(controller.rules, hasLength(6));
    expect(controller.violations, hasLength(3));
    expect(controller.outstandingFines, 120);

    final open = controller.violations.firstWhere(
      (violation) => violation.canAppeal,
    );
    final appeal = await controller.submitAppeal(
      violation: open,
      reason:
          'The noise came from a party in the neighbouring unit on the same floor.',
      requestedOutcome: 'Waive the fine',
    );

    expect(appeal!.status, AppealStatus.pending);
    expect(
      controller.violations
          .firstWhere((violation) => violation.id == open.id)
          .status,
      ViolationStatus.appealed,
    );

    final withdrawn = await controller.withdrawAppeal(appeal);
    expect(withdrawn!.status, AppealStatus.withdrawn);
    expect(
      controller.violations
          .firstWhere((violation) => violation.id == open.id)
          .status,
      ViolationStatus.open,
    );
  });

  test('an appeal is rejected when the reason is too short', () async {
    final repository = RulesRepositoryImpl(RulesLocalDataSource());
    final controller = RulesController(RulesUseCases(repository));
    await controller.loadAll();

    final open = controller.violations.firstWhere(
      (violation) => violation.canAppeal,
    );
    final appeal = await controller.submitAppeal(
      violation: open,
      reason: 'no',
      requestedOutcome: 'Waive the fine',
    );

    expect(appeal, isNull);
    expect(controller.errorMessage.value, isNotNull);
  });

  test('bindings provide the new module graphs', () {
    CondoServiceBinding().dependencies();
    ParkingBinding().dependencies();
    ComplaintBinding().dependencies();
    RulesBinding().dependencies();

    expect(Get.isRegistered<CondoServiceController>(), isTrue);
    expect(Get.isRegistered<ParkingController>(), isTrue);
    expect(Get.isRegistered<ComplaintController>(), isTrue);
    expect(Get.isRegistered<RulesController>(), isTrue);
  });
}
