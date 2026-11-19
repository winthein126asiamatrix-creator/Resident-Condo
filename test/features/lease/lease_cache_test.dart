import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/utils/app_dates.dart';
import 'package:test/features/lease/data/datasources/lease_local_data_source.dart';
import 'package:test/features/lease/data/models/lease_model.dart';
import 'package:test/features/lease/domain/entities/lease.dart';
import 'package:test/features/lease/domain/repositories/lease_repository.dart';
import 'package:test/features/lease/domain/usecases/lease_usecases.dart';
import 'package:test/features/lease/presentation/controllers/lease_controller.dart';
import 'package:test/features/lease/presentation/pages/lease_page.dart';
import 'package:test/features/lease/presentation/pages/lease_renewal_page.dart';
import 'package:test/features/lease/presentation/pages/lease_renewal_sent_page.dart';

void main() {
  test('parses the lease fields the screen renders', () {
    final lease = LeaseModel.fromJson(_leaseJson());

    expect(lease.id, '42');
    expect(lease.unitId, '7');
    expect(lease.unitLabel, 'Tower A · 1205');
    expect(lease.status, LeaseStatus.expiringSoon);
    expect(lease.startDate, DateTime(2026, 1, 1));
    expect(lease.endDate, DateTime(2026, 10, 31));
    expect(lease.currency, 'USD');
    expect(lease.monthlyRent, 2400);
    expect(lease.securityDeposit, 2500);
    expect(lease.rentDueDay, 1);
    expect(lease.owner.id, '10');
    expect(lease.owner.name, 'Alex Johnson');
    expect(lease.tenant?.name, 'Jamie Rivera');
    expect(lease.lastRentPaymentDate, 'Sep 1, 2026');
    expect(lease.documentNames, <String>['lease.pdf']);
    expect(lease.terms, <String>['Rent is due monthly.']);
  });

  test('parses an existing lease whose tenant is not assigned', () {
    final json = _leaseJson()..remove('tenant');
    final lease = LeaseModel.fromJson(json);

    expect(lease.tenant, isNull);
    expect(lease.status, LeaseStatus.expiringSoon);
    expect(lease.owner.name, 'Alex Johnson');

    final restored = LeaseModel.fromJson(lease.toJson());
    expect(restored.tenant, isNull);
  });

  test('lease and renewal JSON round-trip through the cache format', () {
    final lease = LeaseModel.fromJson(_leaseJson());
    final restored = LeaseModel.fromJson(lease.toJson());
    final renewal = LeaseRenewalModel.fromJson(_renewalJson());
    final renewed = LeaseRenewalModel.fromJson(renewal.toJson());

    expect(restored.id, lease.id);
    expect(restored.unitId, lease.unitId);
    expect(restored.owner.id, lease.owner.id);
    expect(restored.startDate, lease.startDate);
    expect(restored.endDate, lease.endDate);
    expect(restored.currency, lease.currency);
    expect(restored.terms, lease.terms);

    expect(renewed.id, renewal.id);
    expect(renewed.leaseId, renewal.leaseId);
    expect(renewed.proposedStart, 'Nov 1, 2026');
    expect(renewed.proposedRent, 2460);
    expect(renewed.status, RenewalStatus.pending);
  });

  test('parses and round-trips the terminated lease status', () {
    final lease = LeaseModel.fromJson(_leaseJson()..['status'] = 'terminated');

    expect(lease.status, LeaseStatus.terminated);
    expect(lease.status.label, 'Terminated');
    expect(LeaseModel.fromJson(lease.toJson()).status, LeaseStatus.terminated);
  });

  test('an unknown lease status falls back to active without throwing', () {
    for (final value in <Object?>[null, '', 'cancelled', 'draft', 7]) {
      final lease = LeaseModel.fromJson(_leaseJson()..['status'] = value);
      expect(lease.status, LeaseStatus.active, reason: '$value');
    }
  });

  test('an unknown renewal status falls back to cancelled without throwing', () {
    for (final value in <Object?>[null, '', 'in_review', 'expired', 3]) {
      final renewal = LeaseRenewalModel.fromJson(
        _renewalJson()..['status'] = value,
      );
      expect(renewal.status, RenewalStatus.cancelled, reason: '$value');
    }
  });

  test('decide_on controls whether the updated date is shown', () {
    final hidden = LeaseRenewalModel.fromJson(
      _renewalJson()
        ..['decide_on'] = false
        ..['updated_on'] = '2026-09-06',
    );
    final missing = LeaseRenewalModel.fromJson(
      _renewalJson()..['decided_on'] = '2026-09-06',
    );
    final shown = LeaseRenewalModel.fromJson(
      _renewalJson()
        ..['decide_on'] = true
        ..['decided_on'] = '2026-09-06',
    );

    expect(hidden.decideOn, isFalse);
    expect(hidden.decidedOn, 'Sep 6, 2026');
    expect(missing.decideOn, isFalse);
    expect(shown.decideOn, isTrue);
    expect(shown.decidedOn, 'Sep 6, 2026');
  });

  test(
    'cached lease lists are scoped to the resident who fetched them',
    () async {
      final cache = _FakeCache();
      var account = 'user:1';
      final local = LeaseLocalDataSource(
        cache: cache,
        accountKey: () => account,
      );

      await local.saveLeases(<Lease>[_lease('42')]);
      await local.saveRenewals(<LeaseRenewal>[]);

      expect(await local.readLeases(), hasLength(1));
      expect(await local.readRenewals(), isEmpty);

      account = 'user:2';
      expect(await local.readLeases(), isNull);
      expect(await local.readRenewals(), isNull);

      account = 'user:1';
      expect((await local.readLeases())?.single.id, '42');
    },
  );

  test(
    'controller keeps cache and shows no error when the API is unreachable',
    () async {
      final repository = _FakeRepository()
        ..cachedLeases = <Lease>[_lease('cached')]
        ..cachedRenewals = <LeaseRenewal>[_renewal('cached')]
        ..error = const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = LeaseController(LeaseUseCases(repository));

      await controller.loadLeases();

      expect(controller.leases.single.id, 'cached');
      expect(controller.renewals.single.id, 'cached');
      expect(controller.isShowingCachedData.value, isTrue);
      expect(controller.errorMessage.value, isNull);
    },
  );

  test('controller replaces cache with a successful API response', () async {
    final repository = _FakeRepository()
      ..cachedLeases = <Lease>[_lease('cached')]
      ..cachedRenewals = <LeaseRenewal>[_renewal('cached')]
      ..leases = <Lease>[_lease('fresh')]
      ..renewals = <LeaseRenewal>[_renewal('fresh')];
    final controller = LeaseController(LeaseUseCases(repository));

    await controller.loadLeases();

    expect(controller.leases.single.id, 'fresh');
    expect(controller.renewals.single.id, 'fresh');
    expect(controller.isShowingCachedData.value, isFalse);
    expect(controller.errorMessage.value, isNull);
  });

  test('controller reports an error when there is no cache', () async {
    final repository = _FakeRepository()
      ..cachedLeases = null
      ..cachedRenewals = null
      ..error = const ApiException(
        'No connection.',
        kind: ApiFailureKind.network,
      );
    final controller = LeaseController(LeaseUseCases(repository));

    await controller.loadLeases();

    expect(controller.leases, isEmpty);
    expect(controller.isShowingCachedData.value, isFalse);
    expect(controller.errorMessage.value, 'No connection.');
  });

  test('a successful empty response is not treated as a failure', () async {
    final repository = _FakeRepository()
      ..cachedLeases = null
      ..cachedRenewals = null
      ..leases = <Lease>[]
      ..renewals = <LeaseRenewal>[];
    final controller = LeaseController(LeaseUseCases(repository));

    await controller.loadLeases();

    expect(controller.leases, isEmpty);
    expect(controller.errorMessage.value, isNull);
    expect(controller.isShowingCachedData.value, isFalse);
  });

  test('an empty renewal list keeps the lease visible', () async {
    final repository = _FakeRepository()
      ..cachedLeases = null
      ..cachedRenewals = null
      ..leases = <Lease>[_lease('42')]
      ..renewals = <LeaseRenewal>[];
    final controller = LeaseController(LeaseUseCases(repository));

    await controller.loadLeases();

    expect(controller.leases.single.id, '42');
    expect(controller.renewals, isEmpty);
    expect(controller.errorMessage.value, isNull);
    expect(controller.isShowingCachedData.value, isFalse);
  });

  test('a renewal failure does not hide an existing lease', () async {
    final repository = _FakeRepository()
      ..cachedLeases = null
      ..cachedRenewals = null
      ..leases = <Lease>[_lease('42')]
      ..renewalError = const ApiException(
        'Renewals unavailable.',
        kind: ApiFailureKind.network,
      );
    final controller = LeaseController(LeaseUseCases(repository));

    await controller.loadLeases();

    expect(controller.leases.single.id, '42');
    expect(controller.renewals, isEmpty);
    expect(controller.errorMessage.value, isNull);
  });

  test('a lease failure is reported instead of an empty lease', () async {
    final repository = _FakeRepository()
      ..cachedLeases = null
      ..cachedRenewals = null
      ..leaseError = const ApiException(
        'Lease list unavailable.',
        kind: ApiFailureKind.network,
      )
      ..renewals = <LeaseRenewal>[_renewal('9')];
    final controller = LeaseController(LeaseUseCases(repository));

    await controller.loadLeases();

    expect(controller.leases, isEmpty);
    expect(controller.renewals.single.id, '9');
    expect(controller.errorMessage.value, 'Lease list unavailable.');
  });

  test('lease and renewal records are kept as separate states', () async {
    final repository = _FakeRepository()
      ..cachedLeases = null
      ..cachedRenewals = null
      ..leases = <Lease>[_lease('42')]
      ..renewals = <LeaseRenewal>[_renewal('9')];
    final controller = LeaseController(LeaseUseCases(repository));

    await controller.loadLeases();

    expect(controller.leases.single.id, '42');
    expect(controller.renewals.single.id, '9');
    expect(controller.renewalsFor(controller.leases.single), hasLength(1));
    expect(controller.errorMessage.value, isNull);
  });

  test('renewal submission is blocked for an expired lease', () async {
    final repository = _FakeRepository();
    final controller = LeaseController(LeaseUseCases(repository));
    final lease = _lease('42', status: LeaseStatus.expired);

    final renewal = await controller.requestRenewal(
      lease: lease,
      proposedStart: DateTime(2026, 11, 1),
      proposedEnd: DateTime(2027, 10, 31),
      proposedRent: 2460,
    );

    expect(renewal, isNull);
    expect(repository.createCalls, 0);
    expect(controller.errorMessage.value, contains('expired'));
    expect(lease.status, LeaseStatus.expired);
  });

  test('renewal submission is blocked for a terminated lease', () async {
    final repository = _FakeRepository();
    final controller = LeaseController(LeaseUseCases(repository));
    final lease = _lease('42', status: LeaseStatus.terminated);

    expect(controller.canRequestRenewal(lease), isFalse);

    final renewal = await controller.requestRenewal(
      lease: lease,
      proposedStart: DateTime(2026, 11, 1),
      proposedEnd: DateTime(2027, 10, 31),
      proposedRent: 2460,
    );

    expect(renewal, isNull);
    expect(repository.createCalls, 0);
    expect(controller.errorMessage.value, contains('terminated'));
    expect(lease.status, LeaseStatus.terminated);
  });

  test('renewal submission remains available for eligible statuses', () async {
    for (final status in <LeaseStatus>[
      LeaseStatus.active,
      LeaseStatus.expiringSoon,
      LeaseStatus.renewed,
    ]) {
      final lease = _lease('42', status: status);
      final repository = _FakeRepository()..leases = <Lease>[lease];
      final controller = LeaseController(LeaseUseCases(repository));

      final renewal = await controller.requestRenewal(
        lease: lease,
        proposedStart: DateTime(2026, 11, 1),
        proposedEnd: DateTime(2027, 10, 31),
        proposedRent: 2460,
      );

      expect(renewal, isNotNull, reason: '${status.name} should allow renewal');
      expect(repository.createCalls, 1);
      expect(controller.errorMessage.value, isNull);
    }
  });

  test('a renewal API error keeps the lease status unchanged', () async {
    final lease = _lease('42', status: LeaseStatus.expiringSoon);
    final repository = _FakeRepository()
      ..leases = <Lease>[lease]
      ..createError = const ApiException(
        'Renewal failed.',
        kind: ApiFailureKind.server,
      );
    final controller = LeaseController(LeaseUseCases(repository));

    final renewal = await controller.requestRenewal(
      lease: lease,
      proposedStart: DateTime(2026, 11, 1),
      proposedEnd: DateTime(2027, 10, 31),
      proposedRent: 2460,
    );

    expect(renewal, isNull);
    expect(repository.createCalls, 1);
    expect(controller.errorMessage.value, 'Renewal failed.');
    expect(lease.status, LeaseStatus.expiringSoon);
  });

  group('lease page', () {
    testWidgets('shows the lease when the renewal list is empty', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewals = <LeaseRenewal>[];
      await _pumpLeasePage(tester, repository);

      expect(find.text('No active lease'), findsNothing);
      expect(find.text('LSE-42'), findsOneWidget);
      await _scrollLeaseTo(
        tester,
        find.textContaining('No renewal request yet'),
      );
      expect(find.textContaining('No renewal request yet'), findsOneWidget);
    });

    testWidgets('shows No active lease only for an empty lease list', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[]
        ..renewals = <LeaseRenewal>[];
      await _pumpLeasePage(tester, repository);

      expect(find.text('No active lease'), findsOneWidget);
      expect(find.text('LSE-42'), findsNothing);
    });

    testWidgets('shows the lease with its renewal records', (tester) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewals = <LeaseRenewal>[_renewal('9')];
      await _pumpLeasePage(tester, repository);

      await _scrollLeaseTo(tester, find.text('LSE-42'));
      expect(find.text('LSE-42'), findsOneWidget);
      await _scrollLeaseTo(tester, find.text('Pending review'));
      expect(find.text('Pending review'), findsOneWidget);
    });

    testWidgets('disables renewal for an expired lease', (tester) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42', status: LeaseStatus.expired)]
        ..renewals = <LeaseRenewal>[];
      await _pumpLeasePage(tester, repository);

      final button = find.byKey(const Key('request-lease-renewal'));
      await _scrollLeaseTo(tester, button);

      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('Renewal unavailable'), findsOneWidget);
    });

    testWidgets('renders a terminated lease and disables renewal', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42', status: LeaseStatus.terminated)]
        ..renewals = <LeaseRenewal>[];
      await _pumpLeasePage(tester, repository);

      expect(find.text('Terminated'), findsOneWidget);
      final button = find.byKey(const Key('request-lease-renewal'));
      await _scrollLeaseTo(tester, button);

      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('Renewal unavailable'), findsOneWidget);
    });

    testWidgets('keeps renewal enabled for an expiring lease', (tester) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42', status: LeaseStatus.expiringSoon)]
        ..renewals = <LeaseRenewal>[];
      await _pumpLeasePage(tester, repository);

      final button = find.byKey(const Key('request-lease-renewal'));
      await _scrollLeaseTo(tester, button);

      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(find.text('Request renewal'), findsOneWidget);
    });

    testWidgets('blocks the renewal form for an expired lease', (tester) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lease = _lease('42', status: LeaseStatus.expired);
      final repository = _FakeRepository()..leases = <Lease>[lease];
      final controller = Get.put(LeaseController(LeaseUseCases(repository)));
      controller.selectLease(lease);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(home: LeaseRenewalPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Renewal unavailable'), findsOneWidget);
      expect(find.byKey(const Key('submit-renewal')), findsNothing);
    });

    testWidgets('formats lease and renewal amounts in the lease currency', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewals = <LeaseRenewal>[_renewal('9')];
      await _pumpLeasePage(tester, repository);

      expect(find.textContaining(r'$2,400.00 / month'), findsOneWidget);
      await _scrollLeaseTo(tester, find.text(r'$2,500.00'));
      expect(find.text(r'$2,500.00'), findsOneWidget);
      await _scrollLeaseTo(tester, find.text(r'$2,460.00 / month'));
      expect(find.text(r'$2,460.00 / month'), findsOneWidget);
    });

    testWidgets('uses a non-USD currency from the API', (tester) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42', currency: 'MMK')]
        ..renewals = <LeaseRenewal>[_renewal('9')];
      await _pumpLeasePage(tester, repository);

      expect(find.textContaining('2,400 Ks / month'), findsOneWidget);
      await _scrollLeaseTo(tester, find.text('2,500 Ks'));
      expect(find.text('2,500 Ks'), findsOneWidget);
      await _scrollLeaseTo(tester, find.text('2,460 Ks / month'));
      expect(find.text('2,460 Ks / month'), findsOneWidget);
    });

    testWidgets('renewal success shows rent in the lease currency', (
      tester,
    ) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lease = _lease('42', currency: 'MMK');
      final repository = _FakeRepository()..leases = <Lease>[lease];
      final controller = Get.put(LeaseController(LeaseUseCases(repository)));
      controller.selectLease(lease);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              MaterialApp(home: LeaseRenewalSentPage(renewal: _renewal('9'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2,460 Ks / month'), findsOneWidget);
    });

    testWidgets('renewal confirmation uses the lease currency', (tester) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lease = _lease('42', currency: 'MMK');
      final repository = _FakeRepository()..leases = <Lease>[lease];
      final controller = Get.put(LeaseController(LeaseUseCases(repository)));
      controller.selectLease(lease);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(home: LeaseRenewalPage()),
        ),
      );
      await tester.pumpAndSettle();

      final submit = find.byKey(const Key('submit-renewal'));
      await tester.scrollUntilVisible(
        submit,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.textContaining('2,472 Ks per month'), findsOneWidget);
    });

    testWidgets('hides the updated date when decide_on is false', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewals = <LeaseRenewal>[
          _renewal('9').copyWith(decidedOn: 'Sep 6, 2026', decideOn: false),
        ];
      await _pumpLeasePage(tester, repository);

      await _scrollLeaseTo(
        tester,
        find.textContaining('Requested by Alex Johnson'),
      );
      expect(find.textContaining('updated Sep 6, 2026'), findsNothing);
    });

    testWidgets('shows the updated date when decide_on is true', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewals = <LeaseRenewal>[
          _renewal('9').copyWith(decidedOn: 'Sep 6, 2026', decideOn: true),
        ];
      await _pumpLeasePage(tester, repository);

      await _scrollLeaseTo(tester, find.textContaining('updated Sep 6, 2026'));
      expect(find.textContaining('updated Sep 6, 2026'), findsOneWidget);
    });

    testWidgets('a renewal failure keeps the lease visible', (tester) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewalError = const ApiException(
          'Renewals unavailable.',
          kind: ApiFailureKind.network,
        );
      await _pumpLeasePage(tester, repository);

      expect(find.text('LSE-42'), findsOneWidget);
      expect(find.text('Unable to load lease'), findsNothing);
      expect(find.text('No active lease'), findsNothing);
    });

    testWidgets('a lease failure shows an error, not an empty lease', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leaseError = const ApiException(
          'Lease list unavailable.',
          kind: ApiFailureKind.network,
        )
        ..renewals = <LeaseRenewal>[_renewal('9')];
      await _pumpLeasePage(tester, repository);

      expect(find.text('Unable to load lease'), findsOneWidget);
      expect(find.text('No active lease'), findsNothing);
    });
  });

  group('renewal eligibility and approved term', () {
    test('rejected and cancelled backend statuses parse and round-trip', () {
      for (final entry in <String, RenewalStatus>{
        'rejected': RenewalStatus.rejected,
        'cancelled': RenewalStatus.cancelled,
        'canceled': RenewalStatus.cancelled,
      }.entries) {
        final json = _renewalJson()..['status'] = entry.key;
        final renewal = LeaseRenewalModel.fromJson(json);
        expect(renewal.status, entry.value, reason: entry.key);
        expect(renewal.status.label, isNotEmpty);
        expect(
          LeaseRenewalModel.fromJson(
            LeaseRenewalModel.fromEntity(renewal).toJson(),
          ).status,
          entry.value,
        );
      }
    });

    test('pending or approved renewal blocks a new request', () async {
      for (final status in <RenewalStatus>[
        RenewalStatus.pending,
        RenewalStatus.approved,
      ]) {
        final lease = _lease('42');
        final repository = _FakeRepository()
          ..leases = <Lease>[lease]
          ..renewals = <LeaseRenewal>[
            _renewalWith(
              id: '9',
              status: status,
              start: DateTime.now().add(const Duration(days: 30)),
              end: DateTime.now().add(const Duration(days: 360)),
            ),
          ];
        final controller = LeaseController(LeaseUseCases(repository));
        await controller.loadLeases();

        expect(controller.canRequestRenewal(lease), isFalse, reason: status.name);
        final renewal = await controller.requestRenewal(
          lease: lease,
          proposedStart: DateTime(2027, 1, 1),
          proposedEnd: DateTime(2027, 12, 31),
          proposedRent: 2460,
        );
        expect(renewal, isNull, reason: status.name);
        expect(repository.createCalls, 0, reason: status.name);
        expect(
          controller.errorMessage.value,
          contains(
            status == RenewalStatus.approved
                ? 'approved'
                : 'awaiting approval',
          ),
        );
      }
    });

    test('rejected, cancelled, withdrawn and declined allow a new request', () async {
      for (final status in <RenewalStatus>[
        RenewalStatus.rejected,
        RenewalStatus.cancelled,
        RenewalStatus.withdrawn,
        RenewalStatus.declined,
      ]) {
        final lease = _lease('42');
        final repository = _FakeRepository()
          ..leases = <Lease>[lease]
          ..renewals = <LeaseRenewal>[
            _renewalWith(
              id: '9',
              status: status,
              start: DateTime(2026, 11, 1),
              end: DateTime(2027, 10, 31),
            ),
          ];
        final controller = LeaseController(LeaseUseCases(repository));
        await controller.loadLeases();

        expect(controller.canRequestRenewal(lease), isTrue, reason: status.name);
        final renewal = await controller.requestRenewal(
          lease: lease,
          proposedStart: DateTime(2027, 1, 1),
          proposedEnd: DateTime(2027, 12, 31),
          proposedRent: 2460,
        );
        expect(renewal, isNotNull, reason: status.name);
        expect(repository.createCalls, 1, reason: status.name);
      }
    });

    test('eligibility is scoped to the lease with the blocking renewal', () async {
      final leaseA = _lease('42');
      final leaseB = _lease('43');
      final repository = _FakeRepository()
        ..leases = <Lease>[leaseA, leaseB]
        ..renewals = <LeaseRenewal>[
          _renewalWith(
            id: '9',
            leaseId: '42',
            status: RenewalStatus.pending,
            start: DateTime(2026, 11, 1),
            end: DateTime(2027, 10, 31),
          ),
        ];
      final controller = LeaseController(LeaseUseCases(repository));
      await controller.loadLeases();

      expect(controller.canRequestRenewal(leaseA), isFalse);
      expect(controller.canRequestRenewal(leaseB), isTrue);
      final renewal = await controller.requestRenewal(
        lease: leaseB,
        proposedStart: DateTime(2027, 1, 1),
        proposedEnd: DateTime(2027, 12, 31),
        proposedRent: 2460,
      );
      expect(renewal, isNotNull);
      expect(repository.createCalls, 1);
    });

    test('duplicate submissions are prevented while one is in flight', () async {
      final lease = _lease('42');
      final gate = Completer<LeaseRenewal>();
      final repository = _FakeRepository()
        ..leases = <Lease>[lease]
        ..renewals = <LeaseRenewal>[]
        ..createGate = gate;
      final controller = LeaseController(LeaseUseCases(repository));
      await controller.loadLeases();

      final first = controller.requestRenewal(
        lease: lease,
        proposedStart: DateTime(2027, 1, 1),
        proposedEnd: DateTime(2027, 12, 31),
        proposedRent: 2460,
      );
      final duplicate = await controller.requestRenewal(
        lease: lease,
        proposedStart: DateTime(2027, 1, 1),
        proposedEnd: DateTime(2027, 12, 31),
        proposedRent: 2460,
      );

      expect(duplicate, isNull);
      expect(repository.createCalls, 1);
      gate.complete(
        _renewalWith(
          id: '10',
          status: RenewalStatus.pending,
          start: DateTime(2027, 1, 1),
          end: DateTime(2027, 12, 31),
        ),
      );
      expect(await first, isNotNull);
      expect(controller.isSubmitting.value, isFalse);
    });

    test('a cached pending renewal still blocks requests while offline', () async {
      final lease = _lease('42');
      final repository = _FakeRepository()
        ..cachedLeases = <Lease>[lease]
        ..cachedRenewals = <LeaseRenewal>[
          _renewalWith(
            id: 'cached',
            status: RenewalStatus.pending,
            start: DateTime(2026, 11, 1),
            end: DateTime(2027, 10, 31),
          ),
        ]
        ..error = const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = LeaseController(LeaseUseCases(repository));
      await controller.loadLeases();

      expect(controller.isShowingCachedData.value, isTrue);
      expect(controller.canRequestRenewal(lease), isFalse);
      final renewal = await controller.requestRenewal(
        lease: lease,
        proposedStart: DateTime(2027, 1, 1),
        proposedEnd: DateTime(2027, 12, 31),
        proposedRent: 2460,
      );
      expect(renewal, isNull);
      expect(repository.createCalls, 0);
    });

    test('approved renewal changes the term only from its start date', () async {
      final lease = _lease('42');
      final futureStart = DateTime.now().add(const Duration(days: 45));
      final futureEnd = futureStart.add(const Duration(days: 364));
      final futureRepository = _FakeRepository()
        ..leases = <Lease>[lease]
        ..renewals = <LeaseRenewal>[
          _renewalWith(
            id: '10',
            status: RenewalStatus.approved,
            start: futureStart,
            end: futureEnd,
            rent: 3200,
          ),
        ];
      final futureController = LeaseController(LeaseUseCases(futureRepository));
      await futureController.loadLeases();

      expect(futureController.displayLeaseFor(lease).startDate, lease.startDate);
      expect(futureController.displayLeaseFor(lease).endDate, lease.endDate);
      expect(futureController.upcomingApprovedRenewalFor(lease), isNotNull);

      final today = AppDates.dateOnly(DateTime.now());
      final effectiveRepository = _FakeRepository()
        ..leases = <Lease>[lease]
        ..renewals = <LeaseRenewal>[
          _renewalWith(
            id: '11',
            status: RenewalStatus.approved,
            start: today,
            end: today.add(const Duration(days: 365)),
            rent: 3300,
          ),
        ];
      final effectiveController =
          LeaseController(LeaseUseCases(effectiveRepository));
      await effectiveController.loadLeases();

      final displayed = effectiveController.displayLeaseFor(lease);
      expect(displayed.startDate, today);
      expect(displayed.endDate, AppDates.dateOnly(today.add(const Duration(days: 365))));
      expect(displayed.monthlyRent, 3300);
      expect(effectiveController.upcomingApprovedRenewalFor(lease), isNull);
    });

    testWidgets('pending renewal disables the action and explains why', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewals = <LeaseRenewal>[
          _renewalWith(
            id: '9',
            status: RenewalStatus.pending,
            start: DateTime.now().add(const Duration(days: 30)),
            end: DateTime.now().add(const Duration(days: 360)),
          ),
        ];
      await _pumpLeasePage(tester, repository);

      final button = find.byKey(const Key('request-lease-renewal'));
      await _scrollLeaseTo(tester, button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('Renewal under review'), findsOneWidget);
      expect(
        find.text('You already have a renewal request awaiting approval.'),
        findsOneWidget,
      );
    });

    testWidgets('approved future renewal shows upcoming term on the card', (
      tester,
    ) async {
      final lease = _lease('42');
      final start = DateTime.now().add(const Duration(days: 45));
      final end = start.add(const Duration(days: 364));
      final repository = _FakeRepository()
        ..leases = <Lease>[lease]
        ..renewals = <LeaseRenewal>[
          _renewalWith(
            id: '10',
            status: RenewalStatus.approved,
            start: start,
            end: end,
            rent: 3200,
          ),
        ];
      await _pumpLeasePage(tester, repository);

      await _scrollLeaseTo(tester, find.text('Renewal Approved'));
      expect(find.text('Upcoming Lease Term'), findsOneWidget);
      expect(
        find.text('${AppDates.format(start)} – ${AppDates.format(end)}'),
        findsOneWidget,
      );
      expect(
        find.text('Your new lease term will begin on ${AppDates.format(start)}.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ends ${AppDates.format(lease.endDate)}'),
        findsOneWidget,
      );
      final button = find.byKey(const Key('request-lease-renewal'));
      await _scrollLeaseTo(tester, button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('approved renewal effective today switches the card term', (
      tester,
    ) async {
      final start = AppDates.dateOnly(DateTime.now());
      final end = start.add(const Duration(days: 365));
      final repository = _FakeRepository()
        ..leases = <Lease>[_lease('42')]
        ..renewals = <LeaseRenewal>[
          _renewalWith(
            id: '11',
            status: RenewalStatus.approved,
            start: start,
            end: end,
            rent: 3300,
          ),
        ];
      await _pumpLeasePage(tester, repository);

      expect(find.text('Renewal Approved'), findsNothing);
      await _scrollLeaseTo(
        tester,
        find.textContaining('Ends ${AppDates.format(end)}'),
      );
      expect(
        find.textContaining('Ends ${AppDates.format(end)}'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _scrollLeaseTo(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('lease-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpLeasePage(
  WidgetTester tester,
  _FakeRepository repository,
) async {
  Get.testMode = true;
  addTearDown(Get.reset);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Get.put(LeaseController(LeaseUseCases(repository)));
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => const MaterialApp(home: LeasePage()),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _leaseJson() {
  return <String, dynamic>{
    'id': 42,
    'reference': 'LSE-2026-0042',
    'status': 'expiring_soon',
    'unit': <String, dynamic>{'id': 7, 'label': 'Tower A · 1205'},
    'start_date': '2026-01-01',
    'end_date': '2026-10-31',
    'currency': 'USD',
    'monthly_rent': 2400,
    'security_deposit': 2500,
    'rent_due_day': 1,
    'owner': <String, dynamic>{
      'id': 10,
      'name': 'Alex Johnson',
      'phone': '+959772611100',
      'email': 'alex@example.com',
      'id_number': 'ID-1',
    },
    'tenant': <String, dynamic>{
      'id': 11,
      'name': 'Jamie Rivera',
      'phone': '+959772611101',
      'email': 'jamie@example.com',
      'id_number': 'ID-2',
    },
    'last_rent_payment_date': '2026-09-01',
    'document_names': <String>['lease.pdf'],
    'terms': <String>['Rent is due monthly.'],
  };
}

Map<String, dynamic> _renewalJson() {
  return <String, dynamic>{
    'id': 9,
    'lease_id': 42,
    'requested_on': '2026-09-05',
    'proposed_start': '2026-11-01',
    'proposed_end': '2027-10-31',
    'proposed_rent': 2460,
    'status': 'pending',
    'requested_by': <String, dynamic>{'name': 'Alex Johnson'},
    'note': 'Please review.',
    'decided_on': null,
  };
}

Lease _lease(
  String id, {
  String currency = 'USD',
  LeaseStatus status = LeaseStatus.active,
}) {
  return LeaseModel(
    id: id,
    reference: 'LSE-$id',
    unitLabel: 'Tower A · 1205',
    status: status,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
    currency: currency,
    monthlyRent: 2400,
    securityDeposit: 2500,
    rentDueDay: 1,
    owner: const LeaseParty(
      name: 'Alex Johnson',
      role: LeasePartyRole.owner,
      phone: '',
      email: '',
      idNumber: '',
    ),
    tenant: const LeaseParty(
      name: 'Jamie Rivera',
      role: LeasePartyRole.tenant,
      phone: '',
      email: '',
      idNumber: '',
    ),
    lastRentPaymentDate: 'Sep 1, 2026',
    documentNames: const <String>[],
    terms: const <String>[],
  );
}

LeaseRenewal _renewalWith({
  required String id,
  required RenewalStatus status,
  required DateTime start,
  required DateTime end,
  String leaseId = '42',
  double rent = 3000,
}) {
  return LeaseRenewalModel(
    id: id,
    leaseId: leaseId,
    requestedOn: 'Sep 5, 2026',
    proposedStart: AppDates.format(start),
    proposedEnd: AppDates.format(end),
    proposedRent: rent,
    status: status,
    requestedBy: 'Alex Johnson',
  );
}

LeaseRenewal _renewal(String id) {
  return LeaseRenewalModel(
    id: id,
    leaseId: '42',
    requestedOn: 'Sep 5, 2026',
    proposedStart: 'Nov 1, 2026',
    proposedEnd: 'Oct 31, 2027',
    proposedRent: 2460,
    status: RenewalStatus.pending,
    requestedBy: 'Alex Johnson',
  );
}

class _FakeRepository implements LeaseRepository {
  List<Lease>? cachedLeases;
  List<LeaseRenewal>? cachedRenewals;
  List<Lease> leases = <Lease>[];
  List<LeaseRenewal> renewals = <LeaseRenewal>[];
  Object? error;
  Object? leaseError;
  Object? renewalError;
  Object? createError;
  Completer<LeaseRenewal>? createGate;
  int createCalls = 0;

  @override
  Future<List<Lease>?> getCachedLeases() async => cachedLeases;

  @override
  Future<List<LeaseRenewal>?> getCachedRenewals() async => cachedRenewals;

  @override
  Future<List<Lease>> getLeases() async {
    final failure = leaseError ?? error;
    if (failure != null) throw failure;
    return leases;
  }

  @override
  Future<List<LeaseRenewal>> getRenewals() async {
    final failure = renewalError ?? error;
    if (failure != null) throw failure;
    return renewals;
  }

  @override
  Future<Lease?> getLease(String id) async => null;

  @override
  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal) async {
    createCalls++;
    final failure = createError;
    if (failure != null) throw failure;
    final gate = createGate;
    if (gate != null) return gate.future;
    return renewal;
  }

  @override
  Future<LeaseRenewal> withdrawRenewal(LeaseRenewal renewal) async =>
      renewal.copyWith(status: RenewalStatus.withdrawn);
}

class _FakeCache extends ApiCacheStore {
  static final AppCacheDatabase _database = AppCacheDatabase();

  _FakeCache() : super(_database);

  final entries = <String, CachedApiEntry>{};

  @override
  Future<CachedApiEntry?> read(String key) async => entries[key];

  @override
  Future<void> save({
    required String key,
    String? accountKey,
    required Object payload,
  }) async {
    entries[key] = CachedApiEntry(
      key: key,
      accountKey: accountKey,
      payloadJson: jsonEncode(payload),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> invalidate(String key) async {
    entries.remove(key);
  }
}
