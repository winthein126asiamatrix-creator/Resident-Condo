import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/connectivity_service.dart';
import 'package:test/core/network/refresh_registry.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/payments/data/datasources/payment_invoice_local_data_source.dart';
import 'package:test/features/payments/data/models/invoice_detail_model.dart';
import 'package:test/features/payments/data/models/invoice_list_model.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/invoice_detail.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  group('invoice list parsing', () {
    test('parses ids, amounts and unknown statuses safely', () {
      final response = InvoiceListResponseModel.fromJson(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 101,
            'invoice_number': 'INV-2026-011',
            'billing_period': '2026-09',
            'invoice_date': '2026-09-01',
            'due_date': '2026-09-30',
            'total_amount': 422.40,
            'paid_amount': 0.00,
            'remaining_amount': 422.40,
            'currency': 'USD',
            'status': 'unpaid',
          },
          <String, dynamic>{
            'id': '102',
            'invoice_number': 'INV-2026-009',
            'billing_period': '2026-08',
            'total_amount': '234.20',
            'paid_amount': '100.00',
            'remaining_amount': '134.20',
            'currency': 'USD',
            'status': 'mystery-status',
          },
        ],
        'page': '1',
        'limit': '20',
        'total': '2',
      });

      expect(response.items, hasLength(2));
      expect(response.page, 1);
      expect(response.limit, 20);
      expect(response.total, 2);

      final first = response.items.first;
      expect(first.id, 101);
      expect(first.invoiceNumber, 'INV-2026-011');
      expect(first.billingPeriodLabel, 'September 2026');
      expect(first.invoiceDateLabel, 'Sep 1, 2026');
      expect(first.dueDateLabel, 'Sep 30, 2026');
      expect(first.remainingAmount, 422.40);
      expect(first.invoiceStatus, InvoiceStatus.unpaid);

      final second = response.items[1];
      expect(second.id, 102);
      expect(second.totalAmount, 234.20);
      expect(second.paidAmount, 100.00);
      expect(second.invoiceStatus, InvoiceStatus.pending);
    });

    test('missing optional fields fall back without throwing', () {
      final item = InvoiceListItemModel.fromJson(<String, dynamic>{
        'invoice_number': 'INV-1',
        'total_amount': null,
        'paid_amount': 'not-a-number',
      });

      expect(item.id, 0);
      expect(item.totalAmount, 0);
      expect(item.remainingAmount, 0);
      expect(item.invoiceDate, isNull);
      expect(item.dueDate, isNull);
    });
  });

  group('invoice detail parsing', () {
    test('parses unit, items, flags and item status', () {
      final detail = InvoiceDetailModel.parse(<String, dynamic>{
        'data': <String, dynamic>{
          'id': 101,
          'invoice_number': 'INV-2026-011',
          'billing_period': '2026-09',
          'unit': <String, dynamic>{'id': 12, 'name': 'Tower A - 1205'},
          'invoice_date': '2026-09-01',
          'due_date': '2026-09-30',
          'status': 'unpaid',
          'currency': 'USD',
          'total_amount': 422.40,
          'paid_amount': 0.00,
          'remaining_amount': 422.40,
          'items': <dynamic>[
            <String, dynamic>{
              'id': 1001,
              'fee_type': 'monthly_condo_fee',
              'name': 'Monthly Condo Fee',
              'description': 'September 2026',
              'amount': 135.00,
              'is_mandatory': true,
              'is_payable': true,
              'status': 'unpaid',
            },
            <String, dynamic>{
              'id': 1002,
              'fee_type': 'parking_fee',
              'name': 'Parking Fee',
              'description': 'Slot B2-125',
              'amount': '45.00',
              'is_mandatory': false,
              'is_payable': false,
              'status': 'unknown',
            },
          ],
        },
      });

      expect(detail.id, 101);
      expect(detail.unit?.label, 'Tower A - 1205');
      expect(detail.billingPeriodLabel, 'September 2026');
      expect(detail.items, hasLength(2));
      expect(detail.items.first.name, 'Monthly Condo Fee');
      expect(detail.items.first.description, 'September 2026');
      expect(detail.items.first.isMandatory, isTrue);
      expect(detail.items.first.isPayable, isTrue);
      expect(detail.items[1].amount, 45.00);
      expect(detail.items[1].isMandatory, isFalse);
      expect(detail.items[1].isPayable, isFalse);
      expect(detail.items[1].status, 'unknown');
    });
  });

  group('invoice list cache', () {
    test('keeps only the newest ten first-page rows', () async {
      final cache = _FakeCache();
      final local = PaymentInvoiceLocalDataSource(
        cache: cache,
        accountKey: () => 'user:1',
      );

      await local.save(1, 'all', _page(page: 1, startId: 100, count: 20));
      final cached = await local.read(1, 'all');

      expect(cached, isNotNull);
      expect(cached!.response.items, hasLength(10));
      expect(
        cached.response.items.map((item) => item.id).toList(),
        List<int>.generate(10, (index) => 100 + index),
      );

      await local.save(1, 'all', _page(page: 2, startId: 200, count: 20));
      final afterOlderPage = await local.read(1, 'all');
      expect(afterOlderPage!.response.items, hasLength(10));
      expect(afterOlderPage.response.items.first.id, 100);
    });

    test('scopes entries by resident and status filter', () async {
      final cache = _FakeCache();
      var account = 'user:1';
      final local = PaymentInvoiceLocalDataSource(
        cache: cache,
        accountKey: () => account,
      );

      await local.save(1, 'all', _page(page: 1, startId: 100, count: 20));

      expect(await local.read(1, 'paid'), isNull);
      expect(await local.read(2, 'all'), isNull);

      account = 'user:2';
      expect(await local.read(1, 'all'), isNull);

      account = 'user:1';
      await local.save(1, 'paid', _page(page: 1, startId: 300, count: 3));
      expect((await local.read(1, 'all'))!.response.items.first.id, 100);
      expect((await local.read(1, 'paid'))!.response.items.first.id, 300);
    });

    test('a valid empty response replaces the cached snapshot', () async {
      final cache = _FakeCache();
      final local = PaymentInvoiceLocalDataSource(
        cache: cache,
        accountKey: () => 'user:1',
      );

      await local.save(1, 'all', _page(page: 1, startId: 100, count: 10));
      await local.save(1, 'all', _page(page: 1, startId: 0, count: 0));

      final cached = await local.read(1, 'all');
      expect(cached, isNotNull);
      expect(cached!.response.items, isEmpty);
    });
  });

  group('invoice controller', () {
    test('shows cached invoices when the first page fails', () async {
      final repository = _InvoiceRepository()
        ..cached = CachedInvoiceList(
          response: _page(page: 1, startId: 100, count: 10),
          updatedAt: DateTime(2026, 9, 1),
        )
        ..error = const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadInvoices();

      expect(controller.invoiceList, hasLength(10));
      expect(controller.invoiceList.first.id, 100);
      expect(controller.isShowingCachedInvoices.value, isTrue);
      expect(controller.invoiceListError.value, isNull);
      expect(repository.cacheWrites, isEmpty);
    });

    test('caches only after a successful first page', () async {
      final repository = _InvoiceRepository()
        ..fresh = _page(page: 1, startId: 500, count: 20);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadInvoices();

      expect(controller.invoiceList, hasLength(20));
      expect(controller.isShowingCachedInvoices.value, isFalse);
      expect(repository.cacheWrites, hasLength(1));
      expect(repository.cacheWrites.single.userId, 1);
      expect(repository.cacheWrites.single.status, 'all');
      expect(repository.cacheWrites.single.response.items, hasLength(20));
    });

    test('an older resident response cannot replace the new one', () async {
      final repository = _InvoiceRepository()..manualResponses = true;
      final session = SessionController();
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: session,
      )..onInit();

      session.setSession(_user(1));
      final first = controller.loadInvoices();
      await _waitForRequests(repository, 1);

      session.setSession(_user(2));
      final second = controller.loadInvoices();
      await _waitForRequests(repository, 2);

      repository.requests[1].complete(_page(page: 1, startId: 900, count: 2));
      await second;
      expect(controller.invoiceList.first.id, 900);

      repository.requests[0].complete(_page(page: 1, startId: 100, count: 2));
      await first;

      expect(controller.invoiceList.first.id, 900);
      expect(repository.cacheWrites.map((write) => write.userId), <int>[2]);
    });

    test(
      'reconnect refreshes a stale cached list through the registry',
      () async {
        final repository = _InvoiceRepository()
          ..cached = CachedInvoiceList(
            response: _page(page: 1, startId: 100, count: 10),
            updatedAt: DateTime(2026, 9, 1),
          );
        final connectivity = ConnectivityService();
        connectivity.isOnline.value = false;
        final registry = RefreshRegistry();
        final controller = PaymentController(
          PaymentUseCases(repository),
          sessionController: _sessionFor(1),
          registry: registry,
          connectivity: connectivity,
        )..onInit();

        await controller.loadInvoices();

        expect(controller.invoiceList.first.id, 100);
        expect(controller.isShowingCachedInvoices.value, isTrue);
        expect(repository.listCalls, 0);

        repository.fresh = _page(page: 1, startId: 900, count: 10);
        connectivity.isOnline.value = true;
        final refreshed = await registry.refreshIfStale(
          PaymentController.invoiceListScreen,
        );

        expect(refreshed, isTrue);
        expect(repository.listCalls, 1);
        expect(controller.invoiceList.first.id, 900);
        expect(controller.isShowingCachedInvoices.value, isFalse);
      },
    );

    test('a first-page reload clears a superseded page request', () async {
      final repository = _InvoiceRepository()
        ..fresh = _page(page: 1, startId: 0, count: 20, total: 40);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadInvoices();
      expect(controller.hasMoreInvoices, isTrue);

      repository.manualResponses = true;
      final more = controller.loadMoreInvoices();
      await _waitForRequests(repository, 1);
      expect(controller.isLoadingMoreInvoices.value, isTrue);

      repository.manualResponses = false;
      repository.fresh = _page(page: 1, startId: 200, count: 20, total: 40);
      await controller.loadInvoices(refresh: true);

      expect(controller.isLoadingMoreInvoices.value, isFalse);
      expect(controller.invoiceList.first.id, 200);

      repository.requests[0].complete(
        _page(page: 2, startId: 20, count: 20, total: 40),
      );
      await more;

      expect(controller.invoiceList.first.id, 200);
      expect(controller.isLoadingMoreInvoices.value, isFalse);
    });

    test(
      'detail is fetched and never written through the list cache',
      () async {
        final repository = _InvoiceRepository()
          ..detail = const InvoiceDetail(
            id: 101,
            invoiceNumber: 'INV-2026-011',
            billingPeriod: '2026-09',
            totalAmount: 422.40,
            paidAmount: 0,
            remainingAmount: 422.40,
            currency: 'USD',
            status: 'unpaid',
            items: <InvoiceDetailItem>[],
          );
        final controller = PaymentController(
          PaymentUseCases(repository),
          sessionController: _sessionFor(1),
        )..onInit();

        await controller.loadInvoiceDetail(101);

        expect(controller.invoiceDetail.value?.invoiceNumber, 'INV-2026-011');
        expect(repository.cacheWrites, isEmpty);
        expect(repository.detailCalls, 1);
      },
    );
  });
}

InvoiceListResponse _page({
  required int page,
  required int startId,
  required int count,
  int? total,
}) {
  return InvoiceListResponse(
    items: List<InvoiceListItem>.generate(
      count,
      (index) => InvoiceListItem(
        id: startId + index,
        invoiceNumber: 'INV-$startId-$index',
        billingPeriod: '2026-09',
        totalAmount: 100,
        paidAmount: 0,
        remainingAmount: 100,
        currency: 'USD',
        status: 'unpaid',
      ),
    ),
    page: page,
    limit: 20,
    total: total ?? count,
  );
}

SessionController _sessionFor(int userId) {
  final session = SessionController();
  session.setSession(_user(userId));
  return session;
}

AuthUser _user(int id) {
  return AuthUser(
    id: id,
    name: 'Resident $id',
    phone: '080000000$id',
    role: 'owner',
  );
}

Future<void> _waitForRequests(_InvoiceRepository repository, int count) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (repository.requests.length >= count) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected $count invoice requests, got ${repository.requests.length}.');
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
      updatedAt: DateTime(2026, 9, 25),
    );
  }

  @override
  Future<void> invalidate(String key) async {
    entries.remove(key);
  }

  @override
  Future<void> invalidatePrefix(String prefix) async {
    entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clearAll() async => entries.clear();
}

class _CacheWrite {
  const _CacheWrite(this.userId, this.status, this.response);

  final int userId;
  final String status;
  final InvoiceListResponse response;
}

class _InvoiceRepository implements PaymentRepository {
  CachedInvoiceList? cached;
  InvoiceListResponse fresh = _page(page: 1, startId: 0, count: 0);
  InvoiceDetail? detail;
  Object? error;
  bool manualResponses = false;
  int detailCalls = 0;
  int listCalls = 0;

  final requests = <Completer<InvoiceListResponse>>[];
  final cacheWrites = <_CacheWrite>[];

  @override
  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) {
    listCalls++;
    if (manualResponses) {
      final completer = Completer<InvoiceListResponse>();
      requests.add(completer);
      return completer.future;
    }
    if (error != null) {
      return Future<InvoiceListResponse>.error(error!);
    }
    return Future<InvoiceListResponse>.value(fresh);
  }

  @override
  Future<InvoiceDetail> getInvoiceDetail(int id) async {
    detailCalls++;
    final value = detail;
    if (value == null) {
      throw StateError('No detail configured.');
    }
    return value;
  }

  @override
  Future<CachedInvoiceList?> getCachedInvoiceList(
    int userId,
    String status,
  ) async {
    return cached;
  }

  @override
  Future<void> cacheInvoiceList(
    int userId,
    String status,
    InvoiceListResponse response,
  ) async {
    cacheWrites.add(_CacheWrite(userId, status, response));
  }

  @override
  Future<void> clearInvoiceListCache() async {}

  @override
  Future<PaymentDashboard> getDashboard() {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) async => null;

  @override
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) async {}

  @override
  Future<void> clearDashboardCache() async {}

  @override
  Future<List<Invoice>> getInvoices() async => const <Invoice>[];

  @override
  Future<Invoice?> getInvoice(String id) async => null;

  @override
  Future<List<Payment>> getPaymentHistory() async => const <Payment>[];

  @override
  Future<Payment> submitPayment(Payment payment) async => payment;

  @override
  Future<List<Invoice>> applyRole(String roleKey) async => const <Invoice>[];

  @override
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  }) {
    throw UnimplementedError();
  }
}
