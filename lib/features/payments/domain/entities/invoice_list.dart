import '../../../../core/utils/app_dates.dart';
import 'invoice.dart';
import 'payment_dashboard.dart';

/// One invoice row returned by `GET /api/v1/payments/invoices`.
class InvoiceListItem {
  const InvoiceListItem({
    required this.id,
    required this.invoiceNumber,
    required this.billingPeriod,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.currency,
    required this.status,
    this.invoiceDate,
    this.dueDate,
  });

  final int id;
  final String invoiceNumber;
  final String billingPeriod;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String currency;
  final String status;

  InvoiceStatus get invoiceStatus => invoiceStatusFromApi(status);

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

  String get invoiceDateLabel =>
      invoiceDate == null ? '' : AppDates.format(invoiceDate!);

  String get dueDateLabel => dueDate == null ? '' : AppDates.format(dueDate!);

  bool get isSettled =>
      remainingAmount <= 0 || invoiceStatus == InvoiceStatus.paid;

  /// Cancelled invoices must never be offered for payment, even when the
  /// backend left an amount on them.
  bool get isCancelled {
    final normalized = status.trim().toLowerCase().replaceAll('-', '_');
    return normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'void';
  }

  /// True when this invoice still has an amount the resident can pay.
  bool get isPayable => id > 0 && !isSettled && !isCancelled;

  /// Date-based, using the same shared calculation as the dashboard.
  bool get isOverdue => isInvoiceOverdue(
    dueDate: dueDate,
    remainingAmount: remainingAmount,
    status: invoiceStatus,
  );

  /// Adapts this invoice-list row to the shared invoice-card shape.
  ///
  /// Uses only fields already provided by the invoice-list API; no data is
  /// invented and the same shared [RecentInvoice.dateProgress] logic is reused.
  RecentInvoice toRecentInvoice() {
    return RecentInvoice(
      id: id,
      invoiceNumber: invoiceNumber,
      billingPeriod: billingPeriod,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      status: status,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
    );
  }
}

/// A page of invoices plus the pagination metadata the list needs to keep
/// loading more pages without changing the API's page size.
class InvoiceListResponse {
  const InvoiceListResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<InvoiceListItem> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;
}

/// A cached first page, with the time it was stored.
class CachedInvoiceList {
  const CachedInvoiceList({required this.response, required this.updatedAt});

  final InvoiceListResponse response;
  final DateTime updatedAt;
}
