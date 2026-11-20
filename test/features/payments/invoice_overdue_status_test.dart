import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final tomorrow = today.add(const Duration(days: 1));

  group('InvoiceListItem overdue detection', () {
    test('keeps Unpaid while reporting the invoice as overdue', () {
      final invoice = _invoice(status: 'unpaid', dueDate: yesterday);

      expect(invoice.invoiceStatus, InvoiceStatus.unpaid);
      expect(invoice.isOverdue, isTrue);
    });

    test('keeps Partial while reporting the invoice as overdue', () {
      final invoice = _invoice(
        status: 'partial',
        remaining: 60,
        dueDate: yesterday,
      );

      expect(invoice.invoiceStatus, InvoiceStatus.partiallyPaid);
      expect(invoice.isOverdue, isTrue);
    });

    test('a paid invoice is not overdue', () {
      final invoice = _invoice(
        status: 'paid',
        remaining: 0,
        dueDate: yesterday,
      );

      expect(invoice.invoiceStatus, InvoiceStatus.paid);
      expect(invoice.isOverdue, isFalse);
    });

    test('a cancelled invoice is not overdue', () {
      final invoice = _invoice(
        status: 'cancelled',
        remaining: 80,
        dueDate: yesterday,
      );

      expect(invoice.invoiceStatus, InvoiceStatus.cancelled);
      expect(invoice.isOverdue, isFalse);
    });

    test('a zero remaining balance is not overdue', () {
      final invoice = _invoice(
        status: 'unpaid',
        remaining: 0,
        dueDate: yesterday,
      );

      expect(invoice.isOverdue, isFalse);
    });

    test('an invoice due today is not overdue', () {
      expect(_invoice(status: 'unpaid', dueDate: today).isOverdue, isFalse);
    });

    test('a future due date is not overdue', () {
      expect(_invoice(status: 'unpaid', dueDate: tomorrow).isOverdue, isFalse);
    });

    test('a missing due date is not overdue', () {
      expect(_invoice(status: 'unpaid').isOverdue, isFalse);
    });

    test('cancelled vocabulary maps to the cancelled status', () {
      for (final raw in <String>['cancelled', 'canceled', 'void']) {
        expect(invoiceStatusFromApi(raw), InvoiceStatus.cancelled);
      }
    });
  });

  group('RecentInvoice overdue detection', () {
    test('keeps the original status and reports overdue independently', () {
      final invoice = _recent(
        status: 'unpaid',
        remaining: 100,
        dueDate: yesterday,
      );

      expect(invoice.invoiceStatus, InvoiceStatus.unpaid);
      expect(invoice.isOverdue, isTrue);
    });

    test('a paid recent invoice is not overdue', () {
      final invoice = _recent(status: 'paid', remaining: 0, dueDate: yesterday);

      expect(invoice.invoiceStatus, InvoiceStatus.paid);
      expect(invoice.isOverdue, isFalse);
    });

    test('a cancelled recent invoice is not overdue', () {
      final invoice = _recent(
        status: 'cancelled',
        remaining: 50,
        dueDate: yesterday,
      );

      expect(invoice.invoiceStatus, InvoiceStatus.cancelled);
      expect(invoice.isOverdue, isFalse);
    });
  });
}

InvoiceListItem _invoice({
  String status = 'unpaid',
  double remaining = 100,
  DateTime? dueDate,
}) {
  return InvoiceListItem(
    id: 1,
    invoiceNumber: 'INV-1',
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
  String status = 'unpaid',
  double remaining = 100,
  DateTime? dueDate,
}) {
  return RecentInvoice(
    id: 1,
    invoiceNumber: 'INV-1',
    billingPeriod: '2026-09',
    totalAmount: 100,
    paidAmount: 100 - remaining,
    remainingAmount: remaining,
    status: status,
    dueDate: dueDate,
  );
}
