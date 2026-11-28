import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/payments/data/models/payment_dashboard_model.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';

void main() {
  test('parses the payment dashboard response', () {
    final dashboard = PaymentDashboardModel.parse(<String, dynamic>{
      'outstanding_balance': <String, dynamic>{
        'amount': 462.40,
        'currency': 'USD',
      },
      'fee_summary': <dynamic>[
        <String, dynamic>{
          'fee_type': 'monthly_rent',
          'label': 'Monthly Rent',
          'amount': 0.00,
        },
        <String, dynamic>{
          'fee_type': 'monthly_condo_fee',
          'label': 'Monthly Condo Fee',
          'amount': 135.00,
        },
        <String, dynamic>{
          'fee_type': 'other_fees',
          'label': 'Parking, Utility, Facility & Service Fees',
          'amount': 327.40,
        },
      ],
      'payment_statistics': <String, dynamic>{
        'current_month_due': 422.40,
        'last_payment': 238.10,
        'paid_this_year': 1192.30,
      },
      'invoice_summary': <String, dynamic>{
        'total': 3,
        'unpaid': 1,
        'partial': 1,
        'paid': 1,
      },
      'recent_invoices': <dynamic>[
        <String, dynamic>{
          'id': 101,
          'invoice_number': 'INV-2026-011',
          'billing_period': '2026-09',
          'total_amount': 422.40,
          'paid_amount': 0.00,
          'remaining_amount': 422.40,
          'status': 'unpaid',
          'due_date': '2026-09-30',
        },
      ],
      'recent_payments': <dynamic>[
        <String, dynamic>{
          'id': 501,
          'payment_number': 'PAY-2026-009',
          'amount': 238.10,
          'currency': 'USD',
          'paid_at': '2026-09-02T10:30:00Z',
          'status': 'paid',
        },
      ],
    });

    expect(dashboard.outstandingBalance.amount, 462.40);
    expect(dashboard.outstandingBalance.currency, 'USD');
    expect(dashboard.feeFor(PaymentFeeType.monthlyRent)?.amount, 0.00);
    expect(dashboard.feeFor(PaymentFeeType.monthlyCondoFee)?.amount, 135.00);
    expect(
      dashboard.feeFor(PaymentFeeType.otherFees)?.label,
      'Parking, Utility, Facility & Service Fees',
    );
    expect(dashboard.paymentStatistics.currentMonthDue, 422.40);
    expect(dashboard.paymentStatistics.lastPayment, 238.10);
    expect(dashboard.paymentStatistics.paidThisYear, 1192.30);
    expect(dashboard.invoiceSummary.total, 3);
    expect(dashboard.invoiceSummary.unpaid, 1);
    expect(dashboard.invoiceSummary.partial, 1);
    expect(dashboard.invoiceSummary.paid, 1);
    expect(dashboard.invoiceSummary.open, 2);

    final invoice = dashboard.recentInvoices.single;
    expect(invoice.invoiceNumber, 'INV-2026-011');
    expect(invoice.billingPeriodLabel, 'September 2026');
    expect(invoice.totalAmount, 422.40);
    expect(invoice.paidAmount, 0.00);
    expect(invoice.remainingAmount, 422.40);
    expect(invoice.invoiceStatus, InvoiceStatus.unpaid);
    expect(invoice.dueDateLabel, 'Sep 30, 2026');

    final payment = dashboard.recentPayments.single;
    expect(payment.paymentNumber, 'PAY-2026-009');
    expect(payment.amount, 238.10);
    expect(payment.currency, 'USD');
    expect(payment.paidAtLabel, 'Sep 2, 2026');
  });

  test('handles missing fields, numeric strings and unknown statuses', () {
    final dashboard = PaymentDashboardModel.parse(<String, dynamic>{
      'outstanding_balance': <String, dynamic>{
        'amount': '10.50',
        'currency': 'EUR',
      },
      'fee_summary': <dynamic>[
        <String, dynamic>{
          'fee_type': 'other_fees',
          'label': 'Other',
          'amount': 5,
        },
      ],
      'recent_invoices': <dynamic>[
        <String, dynamic>{
          'id': '101',
          'invoice_number': 'INV-X',
          'billing_period': '2026-09',
          'total_amount': '1',
          'status': 'mystery',
        },
      ],
    });

    expect(dashboard.outstandingBalance.amount, 10.5);
    expect(dashboard.feeFor(PaymentFeeType.monthlyRent), isNull);
    expect(dashboard.feeFor(PaymentFeeType.otherFees)?.amount, 5.0);
    expect(
      dashboard.recentInvoices.single.invoiceStatus,
      InvoiceStatus.pending,
    );
    expect(dashboard.recentInvoices.single.dueDate, isNull);
    expect(dashboard.recentInvoices.single.isOverdue, isFalse);
    expect(dashboard.recentPayments, isEmpty);
    expect(dashboard.invoiceSummary.total, 0);
  });

  test('a non-map response does not crash', () {
    final dashboard = PaymentDashboardModel.parse(null);
    expect(dashboard.outstandingBalance.amount, 0);
    expect(dashboard.recentInvoices, isEmpty);
    expect(dashboard.recentPayments, isEmpty);
  });

  group('RecentInvoice overdue detection', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    test('a future due date is not overdue', () {
      expect(_invoice(dueDate: tomorrow).isOverdue, isFalse);
    });

    test('a due date of today is not overdue', () {
      expect(_invoice(dueDate: today).isOverdue, isFalse);
    });

    test('a past due date with an outstanding balance is overdue', () {
      expect(_invoice(dueDate: yesterday).isOverdue, isTrue);
    });

    test('a past due date on a fully paid invoice is not overdue', () {
      expect(
        _invoice(
          dueDate: yesterday,
          total: 100,
          paid: 100,
          remaining: 0,
          status: 'paid',
        ).isOverdue,
        isFalse,
      );
    });

    test('a partially paid invoice past due is overdue', () {
      expect(
        _invoice(
          dueDate: yesterday,
          total: 100,
          paid: 40,
          remaining: 60,
        ).isOverdue,
        isTrue,
      );
    });

    test('a missing due date is not overdue', () {
      expect(_invoice(dueDate: null).isOverdue, isFalse);
    });
  });
}

RecentInvoice _invoice({
  required DateTime? dueDate,
  double total = 100,
  double paid = 0,
  double? remaining,
  String status = 'unpaid',
}) {
  return RecentInvoice(
    id: 1,
    invoiceNumber: 'INV-1',
    billingPeriod: '2026-09',
    totalAmount: total,
    paidAmount: paid,
    remainingAmount: remaining ?? (total - paid),
    status: status,
    dueDate: dueDate,
  );
}
