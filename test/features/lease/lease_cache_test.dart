import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/features/lease/data/datasources/lease_local_data_source.dart';
import 'package:test/features/lease/data/models/lease_model.dart';
import 'package:test/features/lease/domain/entities/lease.dart';
import 'package:test/features/lease/domain/repositories/lease_repository.dart';
import 'package:test/features/lease/domain/usecases/lease_usecases.dart';
import 'package:test/features/lease/presentation/controllers/lease_controller.dart';
import 'package:test/features/lease/presentation/pages/lease_page.dart';

void main() {
  test('parses the lease fields the screen renders', () {
    final lease = LeaseModel.fromJson(_leaseJson());

    expect(lease.id, '42');
    expect(lease.unitId, '7');
    expect(lease.unitLabel, 'Tower A · 1205');
    expect(lease.status, LeaseStatus.expiringSoon);
    expect(lease.startDate, DateTime(2026, 1, 1));
    expect(lease.endDate, DateTime(2026, 10, 31));
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
    expect(restored.terms, lease.terms);

    expect(renewed.id, renewal.id);
    expect(renewed.leaseId, renewal.leaseId);
    expect(renewed.proposedStart, 'Nov 1, 2026');
    expect(renewed.proposedRent, 2460);
    expect(renewed.status, RenewalStatus.pending);
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

      expect(find.text('LSE-42'), findsOneWidget);
      await _scrollLeaseTo(tester, find.text('Pending review'));
      expect(find.text('Pending review'), findsOneWidget);
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

Lease _lease(String id) {
  return LeaseModel(
    id: id,
    reference: 'LSE-$id',
    unitLabel: 'Tower A · 1205',
    status: LeaseStatus.active,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
    monthlyRent: 2400,
    securityDeposit: 2400,
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
  Future<LeaseRenewal> createRenewal(LeaseRenewal renewal) async => renewal;

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
