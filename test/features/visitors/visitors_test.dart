import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/visitors/data/datasources/visitor_local_data_source.dart';
import 'package:test/features/visitors/data/repositories/visitor_repository_impl.dart';
import 'package:test/features/visitors/domain/entities/visitor.dart';
import 'package:test/features/visitors/domain/repositories/visitor_repository.dart';
import 'package:test/features/visitors/domain/usecases/visitor_usecases.dart';
import 'package:test/features/visitors/domain/utils/visitor_code.dart';
import 'package:test/features/visitors/presentation/bindings/visitor_binding.dart';
import 'package:test/features/visitors/presentation/controllers/visitor_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  VisitorController buildController() {
    final repository = VisitorRepositoryImpl(VisitorLocalDataSource());
    return VisitorController(VisitorUseCases(repository));
  }

  test('generated access codes are alphanumeric and unique', () {
    final codes = List.generate(20, (_) => VisitorCodeGenerator.generate());
    for (final code in codes) {
      expect(code, matches(RegExp(r'^VIS [A-Z0-9]{3}-[A-Z0-9]{3}$')));
      // Ambiguous glyphs are excluded so the code is easy to read out loud.
      expect(code.substring(4), isNot(matches(RegExp(r'[01OIL]'))));
    }
    expect(codes.toSet().length, greaterThan(1));
  });

  test('registering a visitor assigns an access code and a pre-registered state',
      () async {
    final controller = buildController();
    await controller.loadVisitors();

    final visitor = await controller.registerVisitor(
      name: 'Nina Patel',
      phone: '+959772611100',
      relation: VisitorRelation.friend,
      purpose: 'Coffee',
      date: 'Sep 26, 2026',
      arrivalWindow: '10:00 AM – 12:00 PM',
    );

    expect(visitor, isNotNull);
    expect(visitor!.accessCode, isNotEmpty);
    expect(visitor.status, VisitorStatus.preRegistered);
    expect(controller.visitors.first.id, visitor.id);
  });

  test('verification accepts a valid code and rejects a wrong one', () async {
    final controller = buildController();
    await controller.loadVisitors();
    final expected = controller.visitors.first;

    controller.onVerificationChanged(expected.accessCode);
    final valid = await controller.verifyCode();
    expect(valid!.isValid, isTrue);
    expect(valid.visitor?.id, expected.id);

    controller.clearVerification();
    controller.onVerificationChanged('VIS ZZZ-ZZZ');
    final invalid = await controller.verifyCode();
    expect(invalid!.isValid, isFalse);
    expect(invalid.visitor, isNull);
  });

  test('check-in and check-out update the status', () async {
    final controller = buildController();
    await controller.loadVisitors();
    final visitor = controller.visitors.firstWhere(
      (item) => item.status == VisitorStatus.preRegistered,
    );

    final checkedIn = await controller.checkIn(visitor);
    expect(checkedIn!.status, VisitorStatus.checkedIn);
    expect(checkedIn.checkedInAt, isNotNull);
    expect(checkedIn.canCheckOut, isTrue);

    final checkedOut = await controller.checkOut(checkedIn);
    expect(checkedOut!.status, VisitorStatus.checkedOut);
    expect(checkedOut.checkedOutAt, isNotNull);
  });

  test('a visitor on site cannot have the pass cancelled', () async {
    final controller = buildController();
    await controller.loadVisitors();
    final onSite = controller.visitors.firstWhere(
      (item) => item.status == VisitorStatus.checkedIn,
    );

    final cancelled = await controller.cancelVisitor(onSite);
    expect(cancelled, isNull);
    expect(controller.errorMessage.value, isNotNull);
  });

  test('binding provides the visitor dependency graph', () {
    VisitorBinding().dependencies();

    expect(Get.find<VisitorRepository>(), isA<VisitorRepositoryImpl>());
    expect(Get.isRegistered<VisitorController>(), isTrue);
  });
}
