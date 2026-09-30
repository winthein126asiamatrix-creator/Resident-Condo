import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/payments/data/datasources/payment_local_data_source.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/payment.dart';

void main() {
  group('Store Fee is billed on its own statement line', () {
    late PaymentLocalDataSource dataSource;

    setUp(() => dataSource = PaymentLocalDataSource());

    test('adds a store fee to the open statement as a separate item', () async {
      final before = await dataSource.getInvoices();
      final open = before.firstWhere((invoice) => invoice.isPayable);
      final openBefore = open.amountDue;

      final updated = await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );

      expect(updated.id, open.id);
      expect(updated.amountDue, closeTo(openBefore + 9, 0.001));

      final storeFeeItems = updated.items
          .where((item) => item.type == InvoiceItemType.storeFee)
          .toList();
      expect(storeFeeItems, hasLength(1));
      expect(storeFeeItems.single.amount, 9);
      expect(storeFeeItems.single.isPaid, isFalse);
      expect(storeFeeItems.single.note, contains('ST-20260930-01'));
    });

    test('never folds the store fee into rent, condo fee or other charges', () async {
      final before = await dataSource.getInvoices();
      final open = before.firstWhere((invoice) => invoice.isPayable);

      final updated = await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );

      for (final type in [
        InvoiceItemType.rent,
        InvoiceItemType.condoFee,
        InvoiceItemType.parking,
        InvoiceItemType.utility,
        InvoiceItemType.facility,
        InvoiceItemType.service,
        InvoiceItemType.violation,
        InvoiceItemType.lateFee,
      ]) {
        expect(
          updated.amountFor(type),
          closeTo(open.amountFor(type), 0.001),
          reason: '$type must be untouched by a store fee',
        );
      }
    });

    test('keeps the store fee payable on its own, not mandatory', () async {
      final updated = await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );

      final item = updated.items.firstWhere(
        (candidate) => candidate.type == InvoiceItemType.storeFee,
      );
      expect(item.isPayable, isTrue);
      // A store fee rides along with the next payment, it does not travel
      // automatically with the mandatory charges like rent does.
      expect(item.isMandatory, isFalse);
    });

    test('does not double charge when the same order is submitted twice', () async {
      await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );
      final updated = await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );

      final storeFeeItems = updated.items
          .where((item) => item.type == InvoiceItemType.storeFee)
          .toList();
      expect(storeFeeItems, hasLength(1));
    });

    test('the store fee can be settled on its own', () async {
      final withFee = await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );
      final item = withFee.items.firstWhere(
        (candidate) => candidate.type == InvoiceItemType.storeFee,
      );
      final open = withFee.items
          .where((candidate) => candidate.type != InvoiceItemType.storeFee)
          .fold(0.0, (sum, candidate) => sum + candidate.dueAmount);

      final payment = await dataSource.submitPayment(
        _paymentFor(withFee.number, [item]),
      );

      expect(payment.isSuccessful, isTrue);
      final settled = await dataSource.getInvoice(withFee.id);
      expect(settled!.amountFor(InvoiceItemType.storeFee), 0);
      // The rest of the statement is still owed.
      expect(settled.amountDue, closeTo(open, 0.001));
      expect(settled.isFullyPaid, isFalse);
    });

    test('adds a Store Fee for a second order alongside the first', () async {
      await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );
      final updated = await dataSource.addStoreFee(
        amount: 4.5,
        reference: 'ST-20260930-02',
      );

      final storeFeeItems = updated.items
          .where((item) => item.type == InvoiceItemType.storeFee)
          .toList();
      expect(storeFeeItems, hasLength(2));
      expect(updated.amountFor(InvoiceItemType.storeFee), closeTo(13.5, 0.001));
    });

    test('rejects a zero or negative store fee', () async {
      await expectLater(
        dataSource.addStoreFee(amount: 0, reference: 'ST-1'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        dataSource.addStoreFee(amount: -5, reference: 'ST-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('a tenant store fee does not disturb the separate rent line', () async {
      await dataSource.applyRole('tenant');
      final tenant = (await dataSource.getInvoices())
          .firstWhere((invoice) => invoice.isPayable);
      final rentBefore = tenant.amountFor(InvoiceItemType.rent);

      final updated = await dataSource.addStoreFee(
        amount: 9,
        reference: 'ST-20260930-01',
      );

      expect(updated.amountFor(InvoiceItemType.rent), closeTo(rentBefore, 0.001));
      expect(
        updated.items.where((item) => item.type == InvoiceItemType.rent),
        hasLength(1),
      );
    });
  });
}

Payment _paymentFor(String invoiceNumber, List<InvoiceItem> items) {
  return Payment(
    id: 'pay-1',
    invoiceNumber: invoiceNumber,
    residentName: 'Alex Johnson',
    unitLabel: 'Tower A · 1205',
    items: items,
    amount: items.fold(0, (sum, item) => sum + item.amount),
    date: 'Sep 30, 2026',
    method: PaymentMethod.card,
    transactionId: 'TX-1',
  );
}
