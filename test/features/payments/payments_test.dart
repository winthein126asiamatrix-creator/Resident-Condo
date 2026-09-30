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

  test('selecting an invoice only auto selects the mandatory items', () async {
    final controller = buildController();
    await controller.loadPayments();

    final invoice = controller.invoices.first;
    controller.selectInvoice(invoice);

    final mandatory = invoice.mandatoryItems;
    expect(mandatory, isNotEmpty);
    expect(controller.selectedItems, mandatory);
    expect(
      controller.selectedTotal,
      invoice.mandatoryDue,
    );
    // Optional items are never auto selected.
    expect(
      controller.selectedItems,
      isNot(contains(invoice.itemByKey(
        invoice.items.firstWhere((item) => item.type == InvoiceItemType.parking).key,
      ))),
    );
  });

  test('a mandatory item cannot be deselected and keeps the total', () async {
    final controller = buildController();
    await controller.loadPayments();

    final invoice = controller.invoices.first;
    controller.selectInvoice(invoice);

    final condoFee = invoice.items.firstWhere(
      (item) => item.type == InvoiceItemType.condoFee,
    );
    expect(condoFee.mustPaid, isTrue);
    final before = controller.selectedTotal;

    controller.toggleInvoiceItem(condoFee);
    expect(controller.isItemSelected(condoFee), isTrue);
    expect(controller.selectedTotal, before);

    // Clearing the selection keeps the mandatory fees selected.
    controller.clearSelection();
    expect(controller.isItemSelected(condoFee), isTrue);
    expect(controller.selectedTotal, before);
    expect(controller.missingMandatoryItems, isEmpty);
    expect(controller.canProceedToPayment, isTrue);
  });

  test('an optional item is selected and deselected normally', () async {
    final controller = buildController();
    await controller.loadPayments();

    final invoice = controller.invoices.first;
    controller.selectInvoice(invoice);

    final parking = invoice.items.firstWhere(
      (item) => item.type == InvoiceItemType.parking,
    );
    final facility = invoice.items.firstWhere(
      (item) => item.type == InvoiceItemType.facility,
    );
    expect(parking.mustPaid, isFalse);
    expect(facility.mustPaid, isFalse);

    final mandatoryTotal = controller.selectedTotal;
    expect(controller.isItemSelected(parking), isFalse);

    controller.toggleInvoiceItem(parking);
    expect(controller.isItemSelected(parking), isTrue);
    expect(controller.selectedTotal, mandatoryTotal + 45);

    controller.toggleInvoiceItem(facility);
    expect(controller.selectedTotal, mandatoryTotal + 75);

    controller.toggleInvoiceItem(parking);
    expect(controller.isItemSelected(parking), isFalse);
    expect(controller.selectedTotal, mandatoryTotal + 30);
  });

  test('a mandatory item that is not selected blocks the payment', () async {
    final controller = buildController();
    await controller.loadPayments();

    final invoice = controller.invoices.first;
    controller.selectInvoice(invoice);

    final condoFee = invoice.items.firstWhere(
      (item) => item.type == InvoiceItemType.condoFee,
    );
    // Simulate a corrupted selection: the guard must still stop the payment.
    controller.selectedItems.remove(condoFee);

    expect(controller.missingMandatoryItems, [condoFee]);
    expect(controller.canProceedToPayment, isFalse);
    expect(controller.mandatoryValidationMessage, contains('Monthly Condo Fee'));

    final payment = await controller.confirmPayment();

    expect(payment, isNull);
    expect(controller.errorMessage.value, controller.mandatoryValidationMessage);
    expect(controller.invoices.first.status, InvoiceStatus.unpaid);
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
    // condoFee and lateFee are mandatory and already selected.
    controller.toggleInvoiceItem(parking);
    expect(controller.selectedTotal, 195);

    controller.selectPaymentMethod(PaymentMethod.digitalWallet);
    final payment = await controller.confirmPayment();

    expect(payment, isNotNull);
    expect(payment!.amount, 195);
    expect(payment.isSuccessful, isTrue);
    expect(payment.method, PaymentMethod.digitalWallet);
    expect(payment.transactionId, 'TXN-20260925-001');

    // Only the selected items are settled: the invoice stays partially paid.
    final refreshed = controller.invoices.firstWhere(
      (item) => item.id == invoice.id,
    );
    expect(refreshed.status, InvoiceStatus.partiallyPaid);
    expect(refreshed.amountDue, 227.40);
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

  test('an invoice with no mandatory items keeps the optional behaviour',
      () async {
    final invoice = _invoiceWith(const [
      InvoiceItem(type: InvoiceItemType.parking, amount: 50),
      InvoiceItem(type: InvoiceItemType.facility, amount: 20),
    ]);
    final controller = _controllerFor(invoice);
    await controller.loadPayments();
    controller.selectInvoice(controller.invoices.first);

    expect(controller.selectedItems, isEmpty);
    expect(controller.canProceedToPayment, isFalse);
    expect(controller.missingMandatoryItems, isEmpty);

    controller.toggleInvoiceItem(invoice.items.first);
    controller.toggleInvoiceItem(invoice.items[1]);
    expect(controller.selectedTotal, 70);
    expect(controller.selectedCount, 2);

    controller.toggleInvoiceItem(invoice.items[1]);
    expect(controller.selectedTotal, 50);
    expect(controller.selectedCount, 1);
  });

  test('an invoice where every item is mandatory locks all of them', () async {
    final invoice = _invoiceWith(const [
      InvoiceItem(type: InvoiceItemType.rent, amount: 100, mustPaid: true),
      InvoiceItem(type: InvoiceItemType.condoFee, amount: 20, mustPaid: true),
    ]);
    final controller = _controllerFor(invoice);
    await controller.loadPayments();
    controller.selectInvoice(controller.invoices.first);

    expect(controller.selectedItems, hasLength(2));
    expect(controller.selectedTotal, 120);
    for (final item in invoice.items) {
      controller.toggleInvoiceItem(item);
    }
    expect(controller.selectedItems, hasLength(2));
    expect(controller.selectedTotal, 120);
    expect(controller.canProceedToPayment, isTrue);
  });

  test('a mixed invoice keeps mandatory fees locked and adds optional ones',
      () async {
    final maintenance = const InvoiceItem(
      type: InvoiceItemType.condoFee,
      amount: 100,
      mustPaid: true,
    );
    final parking = const InvoiceItem(
      type: InvoiceItemType.parking,
      amount: 50,
    );
    final facility = const InvoiceItem(
      type: InvoiceItemType.facility,
      amount: 20,
    );
    final controller = _controllerFor(
      _invoiceWith([maintenance, parking, facility]),
    );
    await controller.loadPayments();
    controller.selectInvoice(controller.invoices.first);

    expect(controller.isItemSelected(maintenance), isTrue);
    expect(controller.selectedTotal, 100);

    controller.toggleInvoiceItem(parking);
    expect(controller.selectedTotal, 150);

    controller.toggleInvoiceItem(facility);
    expect(controller.selectedTotal, 170);

    controller.toggleInvoiceItem(maintenance);
    expect(controller.isItemSelected(maintenance), isTrue);
    expect(controller.selectedTotal, 170);

    controller.clearSelection();
    expect(controller.selectedItems, [maintenance]);
    expect(controller.selectedTotal, 100);
  });

  test('an invoice with no items has nothing mandatory to select', () async {
    final invoice = _invoiceWith();    final controller = _controllerFor(invoice);
    await controller.loadPayments();
    controller.selectInvoice(controller.invoices.first);

    expect(invoice.items, isEmpty);
    expect(controller.selectedItems, isEmpty);
    expect(controller.missingMandatoryItems, isEmpty);
    expect(controller.selectedTotal, 0);
    expect(controller.canProceedToPayment, isFalse);
  });

  test('an invoice item defaults to optional when mustPaid is omitted', () {
    const item = InvoiceItem(type: InvoiceItemType.parking, amount: 50);

    expect(item.mustPaid, isFalse);
    expect(item.isMandatory, isFalse);
    expect(item.copyWith(isPaid: true).mustPaid, isFalse);
    expect(item.copyWith(mustPaid: true).mustPaid, isTrue);
    expect(item, const InvoiceItem(type: InvoiceItemType.parking, amount: 50));
    expect(
      item,
      isNot(const InvoiceItem(
        type: InvoiceItemType.parking,
        amount: 50,
        mustPaid: true,
      )),
    );
  });

  test('a paid mandatory fee is no longer part of the mandatory set', () {
    const item = InvoiceItem(
      type: InvoiceItemType.rent,
      amount: 2400,
      mustPaid: true,
      isPaid: true,
    );

    expect(item.mustPaid, isTrue);
    expect(item.isMandatory, isFalse);
    expect(item.isPayable, isFalse);
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

Invoice _invoiceWith([List<InvoiceItem> items = const <InvoiceItem>[]]) {
  return Invoice(
    id: 'invoice-test',
    number: 'INV-TEST-001',
    title: 'Test statement',
    billingPeriod: PaymentController.currentBillingPeriod,
    unitLabel: 'Tower A · 1205',
    dueDate: 'Sep 30, 2026',
    status: InvoiceStatus.unpaid,
    items: items,
  );
}

PaymentController _controllerFor(Invoice invoice) {
  return PaymentController(
    PaymentUseCases(_StubPaymentRepository([invoice])),
  );
}

class _StubPaymentRepository implements PaymentRepository {
  _StubPaymentRepository(this.invoices);

  final List<Invoice> invoices;

  @override
  Future<List<Invoice>> getInvoices() async => List<Invoice>.of(invoices);

  @override
  Future<Invoice?> getInvoice(String id) async {
    for (final invoice in invoices) {
      if (invoice.id == id) return invoice;
    }
    return null;
  }

  @override
  Future<List<Payment>> getPaymentHistory() async => const <Payment>[];

  @override
  Future<Payment> submitPayment(Payment payment) async => payment;

  @override
  Future<List<Invoice>> applyRole(String roleKey) async => List<Invoice>.of(invoices);

  @override
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  }) async {
    final item = InvoiceItem(
      type: InvoiceItemType.storeFee,
      amount: amount,
      note: 'Condo Mart order $reference',
    );
    final index = invoices.indexWhere((invoice) => invoice.isPayable);
    if (index == -1) return invoices.first;
    final updated = invoices[index].copyWith(
      status: InvoiceStatus.partiallyPaid,
      items: [...invoices[index].items, item],
      paidDate: null,
    );
    invoices[index] = updated;
    return updated;
  }
}
