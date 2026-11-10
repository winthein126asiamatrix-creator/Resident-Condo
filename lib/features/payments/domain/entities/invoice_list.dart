import '../../../../core/utils/app_dates.dart';
import 'invoice.dart';

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
