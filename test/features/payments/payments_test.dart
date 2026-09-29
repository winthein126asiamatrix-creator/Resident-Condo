import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/payments/data/datasources/payment_local_data_source.dart';
import 'package:test/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/bindings/payment_binding.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  PaymentController buildController() {
    final repository = PaymentRepositoryImpl(PaymentLocalDataSource());
    return PaymentController(PaymentUseCases(repository));
  }

  test('loads invoices with separate rent, condo and other fee types', () async {
    final controller = buildController();
    await controller.loadPayments();

    expect(controller.invoices, hasLength(3));
    expect(controller.invoices.first.status, InvoiceStatus.unpaid);
    expect(controller.invoices.first.total, 422.40);
    expect(controller.invoices.first.amountDue, 422.40);

    // Owner ledger has no Monthly Rent line.
    expect(controller.rentDueTotal, 0);
    expect(controller.condoFeeDueTotal, 135);
    expect(controller.otherChargesDueTotal, 327.40);

    final types = controller.invoices.first.items.map((item) => item.type).toSet();
    expect(types, contains(InvoiceItemType.condoFee));
    expect(types, contains(InvoiceItemType.parking));
    expect(types, contains(InvoiceItemType.utility));
    expect(types, contains(InvoiceItemType.facility));
    expect(types, contains(InvoiceItemType.service));
    expect(types, contains(InvoiceItemType.violation));
    expect(types, contains(InvoiceItemType.lateFee));
    expect(types, isNot(contains(InvoiceItemType.rent)));
  });

  test('selecting an invoice does not auto select any item', () async {
    final controller = buildController();
    await controller.loadPayments();

    final invoice = controller.invoices.first;
    controller.selectInvoice(invoice);

    expect(controller.selectedItems, isEmpty);
    expect(controller.selectedTotal, 0);
  });

  test('pays only the selected items and locks them afterwards', () async {
    final controller = buildController();
    await controller.loadPayments();

    final invoice = controller.invoices.first;
    controller.selectInvoice(invoice);

    final condoFee = invoice.items.firstWhere(
      (item) => item.type == InvoiceItemType.condoFee,
    );
    final parking = invoice.items.firstWhere(
      (item) => item.type == InvoiceItemType.parking,
    );
    controller.toggleInvoiceItem(condoFee);
    controller.toggleInvoiceItem(parking);
    expect(controller.selectedTotal, 180);

    controller.selectPaymentMethod(PaymentMethod.digitalWallet);
    final payment = await controller.confirmPayment();

    expect(payment, isNotNull);
    expect(payment!.amount, 180);
    expect(payment.isSuccessful, isTrue);
    expect(payment.method, PaymentMethod.digitalWallet);
    expect(payment.transactionId, 'TXN-20260925-001');

    // Only the selected items are settled: the invoice stays partially paid.
    final refreshed = controller.invoices.firstWhere(
      (item) => item.id == invoice.id,
    );
    expect(refreshed.status, InvoiceStatus.partiallyPaid);
    expect(refreshed.amountDue, 242.40);
    expect(refreshed.isFullyPaid, isFalse);
    expect(
      refreshed.itemByKey(condoFee.key)!.isPaid,
      isTrue,
      reason: 'paid items must never be selectable again',
    );
    expect(refreshed.itemByKey(parking.key)!.isPaid, isTrue);

    // A paid item cannot be toggled again.
    controller.toggleInvoiceItem(refreshed.itemByKey(condoFee.key)!);
    expect(controller.selectedItems, isEmpty);
  });

  test('a declined payment never marks items as paid', () async {
    final controller = buildController();
    await controller.loadPayments();

    final invoice = controller.invoices.first;
    controller.selectInvoice(invoice);
    controller.toggleInvoiceItem(invoice.items.first);

    final payment = await controller.confirmPayment(cardNumber: '4000 0000 0000 0000');

    expect(payment, isNotNull);
    expect(payment!.status, PaymentStatus.failed);
    expect(payment.failureReason, isNotNull);

    final refreshed = controller.invoices.firstWhere(
      (item) => item.id == invoice.id,
    );
    expect(refreshed.status, InvoiceStatus.unpaid);
    expect(refreshed.amountDue, invoice.amountDue);
    expect(
      controller.paymentHistory.any((item) => item.isFailed),
      isTrue,
    );
  });

  test('the tenant ledger keeps Monthly Rent separate from the condo fee',
      () async {
    final controller = buildController();
    await controller.applyRole('tenant');
    await controller.loadPayments();

    final rent = controller.invoices.first.items.firstWhere(
      (item) => item.type == InvoiceItemType.rent,
    );
    final condoFee = controller.invoices.first.items.firstWhere(
      (item) => item.type == InvoiceItemType.condoFee,
    );

    expect(rent.amount, 2400);
    expect(condoFee.amount, 135);
    expect(controller.rentDueTotal, greaterThan(0));
    expect(controller.condoFeeDueTotal, 135);
  });

  test('binding provides the payment dependency graph', () {
    PaymentBinding().dependencies();

    expect(Get.find<PaymentRepository>(), isA<PaymentRepositoryImpl>());
    expect(Get.find<PaymentUseCases>(), isA<PaymentUseCases>());
    expect(Get.find<PaymentController>(), isA<PaymentController>());
    expect(
      Get.find<PaymentController>().useCases.repository,
      isA<PaymentRepositoryImpl>(),
    );
  });
}
