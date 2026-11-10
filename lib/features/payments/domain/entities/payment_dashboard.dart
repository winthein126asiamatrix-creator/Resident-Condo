import '../../../../core/utils/app_dates.dart';
import 'invoice.dart';
import 'payment.dart';

/// The fee types the payment dashboard reports its breakdown under.
abstract final class PaymentFeeType {
  static const String monthlyRent = 'monthly_rent';
  static const String monthlyCondoFee = 'monthly_condo_fee';
  static const String otherFees = 'other_fees';
}

/// `GET /api/v1/payments/dashboard`.
class PaymentDashboard {
  const PaymentDashboard({
    required this.outstandingBalance,
    required this.feeSummary,
    required this.paymentStatistics,
    required this.invoiceSummary,
    required this.recentInvoices,
    required this.recentPayments,
  });

  final OutstandingBalance outstandingBalance;
  final List<FeeSummary> feeSummary;
  final PaymentStatistics paymentStatistics;
  final InvoiceSummary invoiceSummary;
  final List<RecentInvoice> recentInvoices;
  final List<RecentPayment> recentPayments;

  /// Fee matches by `fee_type`, never by position, because the backend is free
  /// to return the lines in any order or omit one.
  FeeSummary? feeFor(String feeType) {
    for (final fee in feeSummary) {
      if (fee.feeType == feeType) {
        return fee;
      }
    }
    return null;
  }
}

/// A dashboard snapshot kept on the device, with the time it was stored.
class CachedPaymentDashboard {
  const CachedPaymentDashboard({
    required this.dashboard,
    required this.updatedAt,
  });

  final PaymentDashboard dashboard;
  final DateTime updatedAt;
}

class OutstandingBalance {
  const OutstandingBalance({required this.amount, required this.currency});

  final double amount;
  final String currency;
}

class FeeSummary {
  const FeeSummary({
    required this.feeType,
    required this.label,
    required this.amount,
  });

  final String feeType;
  final String label;
  final double amount;
}

class PaymentStatistics {
  const PaymentStatistics({
    required this.currentMonthDue,
    required this.lastPayment,
    required this.paidThisYear,
  });

  final double currentMonthDue;
  final double lastPayment;
  final double paidThisYear;
}

class InvoiceSummary {
  const InvoiceSummary({
    required this.total,
    required this.unpaid,
    required this.partial,
    required this.paid,
  });

  final int total;
  final int unpaid;
  final int partial;
  final int paid;

  /// Invoices that still carry an amount the resident has to pay.
  int get open => unpaid + partial;
}

class RecentInvoice {
  const RecentInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.billingPeriod,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.dueDate,
  });

  final int id;
  final String invoiceNumber;
  final String billingPeriod;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status;
  final DateTime? dueDate;

  InvoiceStatus get invoiceStatus => _invoiceStatusFromApi(status);

  /// `2026-09` renders as `September 2026`, the same way the rest of the
  /// payment screens read a billing period.
  String get billingPeriodLabel {
    final raw = billingPeriod.trim();
    if (raw.isEmpty) {
      return '';
    }
    final normalized = raw.length == 7 ? '$raw-01' : raw;
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) {
      return raw;
    }
    return AppDates.formatMonthYear(parsed);
  }

  String get dueDateLabel => dueDate == null ? '' : AppDates.format(dueDate!);
}

class RecentPayment {
  const RecentPayment({
    required this.id,
    required this.paymentNumber,
    required this.amount,
    required this.currency,
    required this.paidAt,
    required this.status,
  });

  final int id;
  final String paymentNumber;
  final double amount;
  final String currency;
  final DateTime? paidAt;
  final String status;

  /// Payment transaction status, kept distinct from the invoice status.
  PaymentStatus? get paymentStatus {
    return switch (status.trim().toLowerCase()) {
      'paid' ||
      'successful' ||
      'succeeded' ||
      'completed' => PaymentStatus.successful,
      'failed' || 'declined' || 'error' => PaymentStatus.failed,
      _ => null,
    };
  }

  String get paidAtLabel => paidAt == null ? '' : AppDates.format(paidAt!);

  String get statusLabel {
    final parsed = paymentStatus;
    if (parsed != null) {
      return parsed.label;
    }
    final raw = status.trim();
    if (raw.isEmpty) {
      return 'Unknown';
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}

InvoiceStatus _invoiceStatusFromApi(String status) {
  switch (status
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_')) {
    case 'paid':
    case 'settled':
      return InvoiceStatus.paid;
    case 'partial':
    case 'partially_paid':
      return InvoiceStatus.partiallyPaid;
    case 'unpaid':
    case 'open':
      return InvoiceStatus.unpaid;
    case 'overdue':
      return InvoiceStatus.overdue;
    case 'pending':
      return InvoiceStatus.pending;
    default:
      // An unfamiliar status must never crash the dashboard. Pending is the
      // neutral label until the backend adds one the app knows.
      return InvoiceStatus.pending;
  }
}
