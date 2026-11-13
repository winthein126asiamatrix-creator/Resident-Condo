import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/connectivity_service.dart';
import 'package:test/core/network/refresh_registry.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/payments/data/datasources/payment_dashboard_local_data_source.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/invoice_detail.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_method_option.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';
import 'package:test/features/payments/domain/entities/payment_detail.dart';
import 'package:test/features/payments/domain/entities/payment_list.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  test(
    'dashboard cache round-trips and stays scoped to its resident',
    () async {
      final cache = _FakeCache();
      var account = 'user:1';
      final local = PaymentDashboardLocalDataSource(
        cache: cache,
        accountKey: () => account,
      );

      await local.save(1, _dashboard(12.5));
      final cached = await local.read(1);

      expect(cached?.dashboard.outstandingBalance.amount, 12.5);
      expect(cached?.dashboard.outstandingBalance.currency, 'USD');
      expect(cached?.updatedAt, isNotNull);

      account = 'user:2';
      expect(await local.read(1), isNull);
      await local.save(2, _dashboard(99));
      expect((await local.read(2))?.dashboard.outstandingBalance.amount, 99);

      account = 'user:1';
      expect((await local.read(1))?.dashboard.outstandingBalance.amount, 12.5);

      await local.clear();
      expect(await local.read(1), isNull);
    },
  );

  test(
    'controller shows the cached dashboard when the API is unreachable',
    () async {
      final repository = _FakeRepository()
        ..cached = CachedPaymentDashboard(
          dashboard: _dashboard(5),
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

      await controller.loadPayments();

      expect(controller.dashboard.value?.outstandingBalance.amount, 5);
      expect(controller.isShowingCachedData.value, isTrue);
      expect(controller.errorMessage.value, isNull);
      expect(controller.lastUpdatedAt.value, DateTime(2026, 9, 1));
      expect(repository.cacheWrites, isEmpty);
    },
  );

  test(
    'a successful refresh replaces the cache and marks the data fresh',
    () async {
      final repository = _FakeRepository()
        ..cached = CachedPaymentDashboard(
          dashboard: _dashboard(5),
          updatedAt: DateTime(2026, 9, 1),
        )
        ..fresh = _dashboard(7);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPayments();

      expect(controller.dashboard.value?.outstandingBalance.amount, 7);
      expect(controller.isShowingCachedData.value, isFalse);
      expect(controller.errorMessage.value, isNull);
      expect(repository.cacheWrites[1]?.outstandingBalance.amount, 7);
    },
  );

  test(
    'an older response cannot overwrite a newer resident dashboard',
    () async {
      final repository = _FakeRepository()..manualResponses = true;
      final session = SessionController();
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: session,
      )..onInit();

      session.setSession(_user(1));
      final first = controller.loadPayments();
      await _waitForRequests(repository, 1);

      session.setSession(_user(2));
      final second = controller.loadPayments();
      await _waitForRequests(repository, 2);

      repository.requests[1].complete(_dashboard(200));
      await second;
      expect(controller.dashboard.value?.outstandingBalance.amount, 200);

      repository.requests[0].complete(_dashboard(100));
      await first;

      expect(controller.dashboard.value?.outstandingBalance.amount, 200);
      expect(repository.cacheWrites.keys, <int>[2]);
    },
  );

  test(
    'reconnect refreshes a stale cached dashboard through the registry',
    () async {
      final repository = _FakeRepository()
        ..cached = CachedPaymentDashboard(
          dashboard: _dashboard(5),
          updatedAt: DateTime(2026, 9, 1),
        )
        ..fresh = _dashboard(8);
      final connectivity = ConnectivityService();
      connectivity.isOnline.value = false;
      final registry = RefreshRegistry();
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
        registry: registry,
        connectivity: connectivity,
      )..onInit();

      await controller.loadPayments();

      expect(controller.dashboard.value?.outstandingBalance.amount, 5);
      expect(controller.isShowingCachedData.value, isTrue);
      expect(repository.dashboardCalls, 0);

      connectivity.isOnline.value = true;
      final refreshed = await registry.refreshIfStale(PaymentController.screen);

      expect(refreshed, isTrue);
      expect(repository.dashboardCalls, 1);
      expect(controller.dashboard.value?.outstandingBalance.amount, 8);
      expect(controller.isShowingCachedData.value, isFalse);
    },
  );

  test(
    'clearing the account drops the dashboard and its device cache',
    () async {
      final repository = _FakeRepository()..fresh = _dashboard(3);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPayments();
      expect(controller.dashboard.value, isNotNull);

      await controller.clear();

      expect(controller.dashboard.value, isNull);
      expect(controller.isShowingCachedData.value, isFalse);
      expect(repository.clearCalls, 1);
    },
  );
}

PaymentDashboard _dashboard(double amount) {
  return PaymentDashboard(
    outstandingBalance: OutstandingBalance(amount: amount, currency: 'USD'),
    feeSummary: const <FeeSummary>[],
    paymentStatistics: const PaymentStatistics(
      currentMonthDue: 0,
      lastPayment: 0,
      paidThisYear: 0,
    ),
    invoiceSummary: const InvoiceSummary(
      total: 0,
      unpaid: 0,
      partial: 0,
      paid: 0,
    ),
    recentInvoices: const <RecentInvoice>[],
    recentPayments: const <RecentPayment>[],
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

Future<void> _waitForRequests(_FakeRepository repository, int count) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (repository.requests.length >= count) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail(
    'Expected $count dashboard requests, got ${repository.requests.length}.',
  );
}

class _FakeCache extends ApiCacheStore {
  // One database instance keeps drift from warning about multiple connections;
  // every method that would touch it is overridden below.
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

class _FakeRepository implements PaymentRepository {
  CachedPaymentDashboard? cached;
  PaymentDashboard fresh = _dashboard(0);
  Object? error;
  bool manualResponses = false;
  int dashboardCalls = 0;
  int clearCalls = 0;

  final requests = <Completer<PaymentDashboard>>[];
  final cacheWrites = <int, PaymentDashboard>{};

  @override
  Future<PaymentDashboard> getDashboard() {
    dashboardCalls++;
    if (manualResponses) {
      final completer = Completer<PaymentDashboard>();
      requests.add(completer);
      return completer.future;
    }
    if (error != null) {
      return Future<PaymentDashboard>.error(error!);
    }
    return Future<PaymentDashboard>.value(fresh);
  }

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) async {
    return cached;
  }

  @override
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) async {
    cacheWrites[userId] = dashboard;
  }

  @override
  Future<void> clearDashboardCache() async {
    clearCalls++;
    cached = null;
  }

  @override
  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<InvoiceDetail> getInvoiceDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<CachedInvoiceList?> getCachedInvoiceList(
    int userId,
    String status,
  ) async {
    return null;
  }

  @override
  Future<void> cacheInvoiceList(
    int userId,
    String status,
    InvoiceListResponse response,
  ) async {}

  @override
  Future<void> clearInvoiceListCache() async {}

  @override
  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<PaymentDetail> getPaymentDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentList?> getCachedPaymentList(int userId) async => null;

  @override
  Future<void> cachePaymentList(
    int userId,
    PaymentListResponse response,
  ) async {}

  @override
  Future<void> clearPaymentListCache() async {}

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

  @override
  Future<List<PaymentMethodOption>> getPaymentMethods() async {
    return const <PaymentMethodOption>[];
  }

  @override
  Future<CachedPaymentMethods?> getCachedPaymentMethods(int userId) async {
    return null;
  }

  @override
  Future<void> cachePaymentMethods(
    int userId,
    List<PaymentMethodOption> methods,
  ) async {}

  @override
  Future<void> clearPaymentMethodsCache() async {}

}

