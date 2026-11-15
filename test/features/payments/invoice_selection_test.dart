import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/network/connectivity_service.dart';
import 'package:test/core/network/refresh_registry.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/payments/domain/entities/invoice_detail.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';
import 'package:test/features/payments/domain/entities/payment_detail.dart';
import 'package:test/features/payments/domain/entities/payment_list.dart';
import 'package:test/features/payments/domain/entities/payment_method_option.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/payments/presentation/pages/invoice_selection_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';
import 'package:test/app/routes/app_routes.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('payable invoice flags', () {
    test('keeps unpaid, partial and overdue invoices with a balance', () {
      expect(_invoice(id: 1, status: 'unpaid').isPayable, isTrue);
      expect(
        _invoice(id: 2, status: 'partial', remaining: 40).isPayable,
        isTrue,
      );
      expect(
        _invoice(id: 3, status: 'overdue', remaining: 70).isPayable,
        isTrue,
      );
      expect(
        _invoice(id: 4, status: 'mystery', remaining: 10).isPayable,
        isTrue,
      );
    });

    test('skips settled, cancelled and id-less invoices', () {
      expect(_invoice(id: 1, status: 'paid', remaining: 0).isPayable, isFalse);
      expect(
        _invoice(id: 2, status: 'unpaid', remaining: 0).isPayable,
        isFalse,
      );
      expect(
        _invoice(id: 3, status: 'cancelled', remaining: 90).isPayable,
        isFalse,
      );
      expect(
        _invoice(id: 4, status: 'canceled', remaining: 90).isPayable,
        isFalse,
      );
      expect(_invoice(id: 5, status: 'void', remaining: 90).isPayable, isFalse);
      expect(
        _invoice(id: 0, status: 'unpaid', remaining: 90).isPayable,
        isFalse,
      );
    });

    test('overdue is date-only and ignores settled invoices', () {
      final now = DateTime.now();
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final today = DateTime(now.year, now.month, now.day);

      expect(_invoice(id: 1, dueDate: yesterday).isOverdue, isTrue);
      expect(_invoice(id: 2, dueDate: today).isOverdue, isFalse);
      expect(_invoice(id: 3).isOverdue, isFalse);
      expect(
        _invoice(id: 4, dueDate: yesterday, remaining: 0).isOverdue,
        isFalse,
      );
    });
  });

  group('payable invoice controller', () {
    test(
      'dashboard helpers count only invoices that still owe money',
      () async {
        final repository = _SelectionRepository()
          ..dashboard = PaymentDashboard(
            outstandingBalance: const OutstandingBalance(
              amount: 130,
              currency: 'USD',
            ),
            feeSummary: const <FeeSummary>[],
            paymentStatistics: const PaymentStatistics(
              currentMonthDue: 0,
              lastPayment: 0,
              paidThisYear: 0,
            ),
            invoiceSummary: const InvoiceSummary(
              total: 3,
              unpaid: 1,
              partial: 1,
              paid: 1,
            ),
            recentInvoices: <RecentInvoice>[
              _recent(id: 21, status: 'unpaid', remaining: 100),
              _recent(id: 22, status: 'paid', remaining: 0),
            ],
            recentPayments: const <RecentPayment>[],
          );
        final controller = PaymentController(
          PaymentUseCases(repository),
          sessionController: _sessionFor(1),
        );

        await controller.loadPayments();

        expect(controller.openInvoiceCount, 2);
        expect(controller.singleOpenInvoice?.id, 21);
      },
    );

    test('walks every page and keeps only payable invoices', () async {
      final repository = _SelectionRepository()
        ..pages[1] = _page(
          page: 1,
          limit: 3,
          total: 7,
          items: <InvoiceListItem>[
            _invoice(id: 1, number: 'INV-1', status: 'unpaid', remaining: 100),
            _invoice(id: 2, number: 'INV-2', status: 'paid', remaining: 0),
            _invoice(
              id: 3,
              number: 'INV-3',
              status: 'cancelled',
              remaining: 50,
            ),
          ],
        )
        ..pages[2] = _page(
          page: 2,
          limit: 3,
          total: 7,
          items: <InvoiceListItem>[
            _invoice(id: 4, number: 'INV-4', status: 'partial', remaining: 40),
            _invoice(id: 5, number: 'INV-5', status: 'unpaid', remaining: 0),
            _invoice(id: 6, number: 'INV-6', status: 'overdue', remaining: 70),
          ],
        )
        ..pages[3] = _page(
          page: 3,
          limit: 3,
          total: 7,
          items: <InvoiceListItem>[
            _invoice(id: 7, number: 'INV-7', status: 'unpaid', remaining: 20),
          ],
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );

      await controller.loadPayableInvoices();

      expect(repository.requestedPages, <int>[1, 2, 3]);
      expect(controller.payableInvoices.map((invoice) => invoice.id), <int>[
        1,
        4,
        6,
        7,
      ]);
      expect(controller.isLoadingPayableInvoices.value, isFalse);
      expect(controller.payableInvoicesError.value, isNull);
      expect(repository.cacheWrites, hasLength(1));
      expect(repository.cacheWrites.single.response.page, 1);
    });

    test('reuses a fully loaded All filter without another request', () async {
      final repository = _SelectionRepository()
        ..pages[1] = _page(
          page: 1,
          limit: 20,
          total: 1,
          items: <InvoiceListItem>[
            _invoice(id: 8, number: 'INV-8', status: 'unpaid', remaining: 10),
          ],
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );

      await controller.loadInvoices();
      expect(repository.listCalls, 1);

      await controller.loadPayableInvoices();

      expect(repository.listCalls, 1);
      expect(controller.payableInvoices.single.id, 8);
    });

    test('shows cached payable invoices while offline', () async {
      final repository = _SelectionRepository()
        ..cached = CachedInvoiceList(
          response: _page(
            page: 1,
            limit: 20,
            total: 2,
            items: <InvoiceListItem>[
              _invoice(id: 1, status: 'paid', remaining: 0),
              _invoice(id: 2, status: 'unpaid', remaining: 30),
            ],
          ),
          updatedAt: DateTime(2026, 9, 1),
        );
      final connectivity = ConnectivityService()..isOnline.value = false;
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
        connectivity: connectivity,
      );

      await controller.loadPayableInvoices();

      expect(repository.listCalls, 0);
      expect(controller.payableInvoices.single.id, 2);
      expect(controller.isShowingCachedPayableInvoices.value, isTrue);
      expect(controller.payableInvoicesError.value, isNull);
    });

    test('reconnect refreshes the stale payable list once', () async {
      final repository = _SelectionRepository()
        ..dashboard = _dashboard()
        ..cached = CachedInvoiceList(
          response: _page(
            page: 1,
            limit: 20,
            total: 1,
            items: <InvoiceListItem>[
              _invoice(id: 2, status: 'unpaid', remaining: 30),
            ],
          ),
          updatedAt: DateTime(2026, 9, 1),
        )
        ..pages[1] = _page(
          page: 1,
          limit: 20,
          total: 1,
          items: <InvoiceListItem>[
            _invoice(id: 9, status: 'unpaid', remaining: 30),
          ],
        );
      final connectivity = ConnectivityService()..isOnline.value = false;
      final registry = RefreshRegistry();
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
        registry: registry,
        connectivity: connectivity,
      )..onInit();

      await controller.loadPayableInvoices();
      expect(controller.payableInvoices.single.id, 2);
      expect(controller.isShowingCachedPayableInvoices.value, isTrue);
      expect(repository.listCalls, 0);

      connectivity.isOnline.value = true;
      final refreshed = await registry.refreshIfStale(
        PaymentController.invoiceSelectionScreen,
      );

      expect(refreshed, isTrue);
      expect(repository.listCalls, 1);
      expect(controller.payableInvoices.single.id, 9);
      expect(controller.isShowingCachedPayableInvoices.value, isFalse);
    });
  });

  group('invoice selection page', () {
    testWidgets('lists payable invoices and opens the tapped one', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _SelectionRepository()
        ..pages[1] = _page(
          page: 1,
          limit: 20,
          total: 4,
          items: <InvoiceListItem>[
            _invoice(
              id: 11,
              number: 'INV-11',
              status: 'unpaid',
              remaining: 100,
              dueDate: DateTime.now().subtract(const Duration(days: 2)),
            ),
            _invoice(
              id: 12,
              number: 'INV-12',
              status: 'partial',
              remaining: 40,
            ),
            _invoice(id: 13, number: 'INV-13', status: 'paid', remaining: 0),
            _invoice(
              id: 14,
              number: 'INV-14',
              status: 'cancelled',
              remaining: 90,
            ),
          ],
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );
      Get.put(controller);

      int? openedInvoiceId;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => GetMaterialApp(
            initialRoute: AppRoutes.invoiceSelection,
            getPages: <GetPage<dynamic>>[
              GetPage<dynamic>(
                name: AppRoutes.invoiceSelection,
                page: () => const InvoiceSelectionPage(),
              ),
              GetPage<dynamic>(
                name: AppRoutes.paymentDetail,
                page: () {
                  openedInvoiceId = Get.arguments as int;
                  return const Scaffold(body: Text('Invoice detail'));
                },
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INV-11'), findsOneWidget);
      expect(find.text('INV-12'), findsOneWidget);
      expect(find.text('INV-13'), findsNothing);
      expect(find.text('INV-14'), findsNothing);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Partial'), findsOneWidget);

      await tester.tap(find.byKey(const Key('payable-invoice-11')));
      await tester.pumpAndSettle();

      expect(openedInvoiceId, 11);
      expect(find.text('Invoice detail'), findsOneWidget);
    });
  });
}

InvoiceListResponse _page({
  required int page,
  required int limit,
  required int total,
  required List<InvoiceListItem> items,
}) {
  return InvoiceListResponse(
    items: items,
    page: page,
    limit: limit,
    total: total,
  );
}

InvoiceListItem _invoice({
  required int id,
  String number = 'INV',
  String status = 'unpaid',
  double remaining = 100,
  DateTime? dueDate,
}) {
  return InvoiceListItem(
    id: id,
    invoiceNumber: number,
    billingPeriod: '2026-09',
    totalAmount: 100,
    paidAmount: 100 - remaining,
    remainingAmount: remaining,
    currency: 'USD',
    status: status,
    dueDate: dueDate,
  );
}

RecentInvoice _recent({
  required int id,
  required String status,
  required double remaining,
}) {
  return RecentInvoice(
    id: id,
    invoiceNumber: 'INV-$id',
    billingPeriod: '2026-09',
    totalAmount: 100,
    paidAmount: 100 - remaining,
    remainingAmount: remaining,
    status: status,
  );
}

PaymentDashboard _dashboard() {
  return const PaymentDashboard(
    outstandingBalance: OutstandingBalance(amount: 0, currency: 'USD'),
    feeSummary: <FeeSummary>[],
    paymentStatistics: PaymentStatistics(
      currentMonthDue: 0,
      lastPayment: 0,
      paidThisYear: 0,
    ),
    invoiceSummary: InvoiceSummary(total: 0, unpaid: 0, partial: 0, paid: 0),
    recentInvoices: <RecentInvoice>[],
    recentPayments: <RecentPayment>[],
  );
}

SessionController _sessionFor(int userId) {
  final session = SessionController();
  session.setSession(
    AuthUser(
      id: userId,
      name: 'Resident $userId',
      phone: '080000000$userId',
      role: 'owner',
    ),
  );
  return session;
}

class _SelectionRepository implements PaymentRepository {
  final Map<int, InvoiceListResponse> pages = <int, InvoiceListResponse>{};
  PaymentDashboard? dashboard;
  CachedInvoiceList? cached;
  Object? error;
  int listCalls = 0;
  final List<int> requestedPages = <int>[];
  final List<_CacheWrite> cacheWrites = <_CacheWrite>[];

  @override
  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) async {
    listCalls++;
    requestedPages.add(page);
    if (error != null) {
      throw error!;
    }
    return pages[page] ??
        InvoiceListResponse(
          items: const <InvoiceListItem>[],
          page: page,
          limit: limit,
          total: 0,
        );
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
  Future<InvoiceDetail> getInvoiceDetail(int id) async {
    throw UnimplementedError();
  }

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
  Future<PaymentDashboard> getDashboard() async {
    final value = dashboard;
    if (value == null) {
      throw UnimplementedError();
    }
    return value;
  }

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) async => null;

  @override
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) async {}

  @override
  Future<void> clearDashboardCache() async {}

  @override
  Future<Payment> submitPayment(Payment payment) async => payment;

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

class _CacheWrite {
  const _CacheWrite(this.userId, this.status, this.response);

  final int userId;
  final String status;
  final InvoiceListResponse response;
}
