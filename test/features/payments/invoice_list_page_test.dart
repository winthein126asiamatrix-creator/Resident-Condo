import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/widgets/app_segmented_tabs.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/invoice_detail.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/payments/presentation/pages/invoice_list_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('Partial and Paid filters replace the list', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FilteredInvoiceRepository()
      ..responses['all'] = _page(<int>[101], 'INV-ALL')
      ..responses['unpaid'] = _page(<int>[201], 'INV-UNPAID')
      ..responses['partial'] = _page(<int>[301], 'INV-PARTIAL')
      ..responses['paid'] = _page(<int>[401], 'INV-PAID');

    final session = SessionController()..setSession(_user(1));
    final controller = PaymentController(
      PaymentUseCases(repository),
      sessionController: session,
    );
    Get.put(controller);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(home: InvoiceListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INV-ALL'), findsOneWidget);

    final tabsWidth = tester.getSize(find.byType(AppSegmentedTabs)).width;
    final segmentWidth = (tabsWidth - 8) / 4;
    double pillLeft() => tester
        .widget<Positioned>(find.byKey(const Key('invoice-filter-selection')))
        .left!;

    await tester.tap(find.byKey(const Key('invoice-filter-tab-partial')));
    await tester.pumpAndSettle();

    expect(controller.invoiceListStatus.value, 'partial');
    expect(repository.lastStatus, 'partial');
    expect(find.text('INV-PARTIAL'), findsOneWidget);
    expect(find.byKey(const Key('invoice-filter-tab-partial')), findsOneWidget);
    expect(pillLeft(), closeTo(2 * segmentWidth, 0.01));

    await tester.tap(find.byKey(const Key('invoice-filter-tab-paid')));
    await tester.pumpAndSettle();

    expect(controller.invoiceListStatus.value, 'paid');
    expect(repository.lastStatus, 'paid');
    expect(find.text('INV-PAID'), findsOneWidget);
    expect(find.byKey(const Key('invoice-filter-tab-paid')), findsOneWidget);
    expect(pillLeft(), closeTo(3 * segmentWidth, 0.01));
  });

  testWidgets('a failing filter keeps the other filters reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FilteredInvoiceRepository()
      ..responses['all'] = _page(<int>[101], 'INV-ALL')
      ..responses['paid'] = _page(<int>[401], 'INV-PAID')
      ..failures.add('partial');

    final session = SessionController()..setSession(_user(1));
    final controller = PaymentController(
      PaymentUseCases(repository),
      sessionController: session,
    );
    Get.put(controller);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(home: InvoiceListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invoice-filter-tab-partial')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load invoices'), findsOneWidget);
    expect(find.byKey(const Key('invoice-filter-tab-partial')), findsOneWidget);
    expect(find.byKey(const Key('invoice-filter-tab-paid')), findsOneWidget);

    await tester.tap(find.byKey(const Key('invoice-filter-tab-paid')));
    await tester.pumpAndSettle();

    expect(controller.invoiceListStatus.value, 'paid');
    expect(find.text('INV-PAID'), findsOneWidget);
  });
}

InvoiceListResponse _page(List<int> ids, String number) {
  return InvoiceListResponse(
    items: <InvoiceListItem>[
      for (final id in ids)
        InvoiceListItem(
          id: id,
          invoiceNumber: number,
          billingPeriod: '2026-09',
          totalAmount: 100,
          paidAmount: 0,
          remainingAmount: 100,
          currency: 'USD',
          status: 'unpaid',
        ),
    ],
    page: 1,
    limit: 20,
    total: ids.length,
  );
}

AuthUser _user(int id) {
  return AuthUser(
    id: id,
    name: 'Resident $id',
    phone: '080000000$id',
    role: 'owner',
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

class _FilteredInvoiceRepository implements PaymentRepository {
  final responses = <String, InvoiceListResponse>{};
  final failures = <String>{};
  String? lastStatus;

  @override
  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) async {
    lastStatus = status;
    if (failures.contains(status)) {
      throw StateError('The $status filter is unavailable.');
    }
    return responses[status] ?? _page(const <int>[], 'NONE');
  }

  @override
  Future<InvoiceDetail> getInvoiceDetail(int id) async {
    throw StateError('Not used by this test.');
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
  Future<PaymentDashboard> getDashboard() async => _dashboard();

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
