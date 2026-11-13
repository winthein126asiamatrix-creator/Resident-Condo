import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/features/payments/data/models/invoice_detail_model.dart';
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
import 'package:test/features/payments/presentation/pages/payment_summary_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  group('invoice remaining amount mapping', () {
    test('preserves invoice and item remaining amounts', () {
      final detail = InvoiceDetailModel.fromJson(_partialInvoiceJson());

      expect(detail.totalAmount, 500000);
      expect(detail.paidAmount, 200000);
      expect(detail.remainingAmount, 300000);

      final invoice = detail.toInvoice();
      expect(invoice.total, 500000);
      expect(invoice.amountPaid, 200000);
      expect(invoice.remainingAmount, 300000);
      expect(invoice.amountDue, 300000);
      expect(invoice.isFullyPaid, isFalse);
      expect(invoice.isPayable, isTrue);

      final item = invoice.items.single;
      expect(item.amount, 500000);
      expect(item.paidAmount, 200000);
      expect(item.dueAmount, 300000);
    });

    test('fully paid invoices have no remaining balance', () {
      final detail = InvoiceDetailModel.fromJson(
        _partialInvoiceJson(
          totalAmount: 500000,
          paidAmount: 500000,
          remainingAmount: 0,
          itemPaidAmount: 500000,
          itemRemainingAmount: 0,
          isPaid: true,
          isPayable: false,
          status: 'paid',
        ),
      );

      final invoice = detail.toInvoice();
      expect(invoice.remainingAmount, 0);
      expect(invoice.amountDue, 0);
      expect(invoice.isFullyPaid, isTrue);
      expect(invoice.isPayable, isFalse);
      expect(invoice.items.single.dueAmount, 0);
    });

    test('legacy invoices keep their item-derived fallback', () {
      const invoice = Invoice(
        id: 'invoice-2026-011',
        number: 'INV-2026-011',
        title: 'September 2026 statement',
        billingPeriod: 'September 2026',
        unitLabel: 'Tower A · 1205',
        dueDate: 'Sep 30, 2026',
        status: InvoiceStatus.unpaid,
        items: <InvoiceItem>[
          InvoiceItem(type: InvoiceItemType.rent, amount: 500),
        ],
      );

      expect(invoice.remainingAmount, 500);
      expect(invoice.amountDue, 500);
      expect(invoice.total, 500);
      expect(invoice.amountPaid, 0);
    });

    test('selected total uses the payable item balance', () {
      final detail = InvoiceDetailModel.fromJson(
        _partialInvoiceJson(isMandatory: true),
      );
      final controller = PaymentController(
        PaymentUseCases(_NoopPaymentRepository()),
        sessionController: SessionController(),
      );
      addTearDown(controller.onClose);

      controller.selectInvoice(detail.toInvoice());

      expect(controller.selectedTotal, 300000);
    });
  });

  testWidgets('payment summary shows the invoice remaining amount', (
    tester,
  ) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = InvoiceDetailModel.fromJson(_partialInvoiceJson());
    final controller = PaymentController(
      PaymentUseCases(_NoopPaymentRepository()),
      sessionController: SessionController(),
    );
    controller.selectInvoice(detail.toInvoice());
    Get.put(controller);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(home: PaymentSummaryPage()),
      ),
    );
    await tester.pumpAndSettle();

    final amount = tester.widget<Text>(
      find.byKey(const Key('payment-summary-remaining-amount')),
    );
    expect(amount.data, '300,000 Ks');
    expect(find.text('500,000 Ks'), findsOneWidget);
  });
}

Map<String, dynamic> _partialInvoiceJson({
  double totalAmount = 500000,
  double paidAmount = 200000,
  double remainingAmount = 300000,
  double itemPaidAmount = 200000,
  double itemRemainingAmount = 300000,
  bool isPaid = false,
  bool isPayable = true,
  bool isMandatory = false,
  String status = 'partial',
}) {
  return <String, dynamic>{
    'id': 101,
    'invoice_number': 'INV-2026-011',
    'billing_period': '2026-09',
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'remaining_amount': remainingAmount,
    'currency': 'MMK',
    'status': status,
    'items': <dynamic>[
      <String, dynamic>{
        'id': 1,
        'fee_type': 'monthly_rent',
        'name': 'Monthly Rent',
        'amount': totalAmount,
        'paid_amount': itemPaidAmount,
        'remaining_amount': itemRemainingAmount,
        'is_paid': isPaid,
        'is_payable': isPayable,
        'is_mandatory': isMandatory,
      },
    ],
  };
}

class _NoopPaymentRepository implements PaymentRepository {
  @override
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Invoice>> applyRole(String roleKey) {
    throw UnimplementedError();
  }

  @override
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) {
    throw UnimplementedError();
  }

  @override
  Future<void> cacheInvoiceList(
    int userId,
    String status,
    InvoiceListResponse response,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> cachePaymentList(int userId, PaymentListResponse response) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearDashboardCache() {
    throw UnimplementedError();
  }

  @override
  Future<void> clearInvoiceListCache() {
    throw UnimplementedError();
  }

  @override
  Future<void> clearPaymentListCache() {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) {
    throw UnimplementedError();
  }

  @override
  Future<CachedInvoiceList?> getCachedInvoiceList(int userId, String status) {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentList?> getCachedPaymentList(int userId) {
    throw UnimplementedError();
  }

  @override
  Future<PaymentDashboard> getDashboard() {
    throw UnimplementedError();
  }

  @override
  Future<Invoice?> getInvoice(String id) {
    throw UnimplementedError();
  }

  @override
  Future<InvoiceDetail> getInvoiceDetail(int id) {
    throw UnimplementedError();
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
  Future<List<Invoice>> getInvoices() {
    throw UnimplementedError();
  }

  @override
  Future<PaymentDetail> getPaymentDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Payment>> getPaymentHistory() {
    throw UnimplementedError();
  }

  @override
  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<Payment> submitPayment(Payment payment) {
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

