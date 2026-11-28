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

  FeeSummary? feeFor(String feeType) {
    for (final fee in feeSummary) {
      if (fee.feeType == feeType) {
        return fee;
      }
    }
    return null;
  }
}

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
    this.invoiceDate,
    this.dueDate,
  });

  final int id;
  final String invoiceNumber;
  final String billingPeriod;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status;
  final DateTime? invoiceDate;
  final DateTime? dueDate;

  InvoiceStatus get invoiceStatus => invoiceStatusFromApi(status);

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

  /// Progress through the invoice's issue-to-due window, from `0.0` to `1.0`.
  ///
  /// This is a date-based timeline, not the payment completion percentage
  /// (`paidAmount / totalAmount`). Returns `null` when either date is missing or
  /// when the due date is before the invoice date, so the card can hide the
  /// indicator instead of producing an invalid calculation. A same-day invoice
  /// is valid: it has no elapsed window, but it is complete once due.
  double? get dateProgress => dateProgressOn(DateTime.now());

  /// [dateProgress] evaluated against a supplied day, which keeps the
  /// calculation deterministic in tests.
  double? dateProgressOn(DateTime today) {
    final issued = invoiceDate;
    final due = dueDate;
    if (issued == null || due == null) {
      return null;
    }

    // Work with local calendar days so a UTC timestamp cannot shift the day.
    final start = AppDates.dateOnly(issued.toLocal());
    final end = AppDates.dateOnly(due.toLocal());
    final currentDay = AppDates.dateOnly(today.toLocal());
    final totalDays = AppDates.daysBetween(start, end);
    if (totalDays < 0) {
      return null;
    }
    if (totalDays == 0) {
      // Invoice date and due date are the same day; avoid dividing by zero.
      return currentDay.isBefore(end) ? 0.0 : 1.0;
    }

    final elapsedDays = AppDates.daysBetween(start, currentDay);
    return (elapsedDays / totalDays).clamp(0.0, 1.0);
  }

  /// True when the invoice still owes money and its due date is before today.
  ///
  /// Uses the same shared calculation as the invoice list, so both screens add
  /// the Overdue badge for exactly the same invoices.
  bool get isOverdue => isInvoiceOverdue(
    dueDate: dueDate,
    remainingAmount: remainingAmount,
    status: invoiceStatus,
  );
}

class RecentPayment {
  const RecentPayment({
    required this.id,
    required this.paymentNumber,
    required this.amount,
    required this.currency,
    required this.paidAt,
    required this.status,
    required this.invoiceNumber,
  });

  final int id;
  final String paymentNumber;
  final double amount;
  final String currency;
  final DateTime? paidAt;
  final PaymentStatus status;
  final String invoiceNumber;



  String get paidAtLabel => paidAt == null ? '' : AppDates.format(paidAt!);

}
