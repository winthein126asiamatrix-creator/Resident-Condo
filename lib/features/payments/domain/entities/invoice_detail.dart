import '../../../../core/utils/app_dates.dart';
import 'invoice.dart';

/// The unit attached to an invoice detail response.
class InvoiceUnit {
  const InvoiceUnit({
    this.id,
    this.name = '',
    this.number = '',
    this.block = '',
    this.floor = '',
  });

  final int? id;
  final String name;
  final String number;
  final String block;
  final String floor;

  /// A readable label that never depends on one particular API field shape.
  String get label {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    final numberText = number.trim();
    final blockText = block.trim();
    if (blockText.isNotEmpty && numberText.isNotEmpty) {
      return '$blockText-$numberText';
    }
    if (numberText.isNotEmpty) {
      return numberText;
    }
    if (blockText.isNotEmpty) {
      return blockText;
    }
    return floor.trim().isEmpty ? '' : 'Floor ${floor.trim()}';
  }
}

/// One charge line in an invoice detail response.
class InvoiceDetailItem {
  const InvoiceDetailItem({
    required this.feeType,
    required this.amount,
    this.id,
    this.name = '',
    this.description = '',
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.isMandatory = false,
    this.isPayable = false,
    this.isPaid = false,
    this.paidDate,
    this.status = '',
  });

  final int? id;
  final String feeType;
  final String name;
  final String description;
  final double amount;
  final double paidAmount;
  final double remainingAmount;
  final bool isMandatory;
  final bool isPayable;
  final bool isPaid;
  final DateTime? paidDate;
  final String status;

  String get paidDateLabel =>
      paidDate == null ? '' : AppDates.format(paidDate!);

  /// Converts the API line to the ledger line the existing payment screens use.
  ///
  /// The API's own `is_payable` flag is preserved, so a non-payable charge can
  /// never be selected just because it still has a positive amount.
  InvoiceItem toInvoiceItem() {
    final note = description.trim().isNotEmpty ? description : name;
    return InvoiceItem(
      type: invoiceItemTypeFromApi(feeType),
      amount: amount,
      note: note,
      isPaid: isPaid,
      paidDate: paidDateLabel.isEmpty ? null : paidDateLabel,
      mustPaid: isMandatory,
      apiPayable: isPayable,
    );
  }
}

/// `GET /api/v1/payments/invoices/{invoice_id}`.
class InvoiceDetail {
  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.billingPeriod,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.currency,
    required this.status,
    required this.items,
    this.unit,
    this.invoiceDate,
    this.dueDate,
    this.paidDate,
  });

  final int id;
  final String invoiceNumber;
  final String billingPeriod;
  final InvoiceUnit? unit;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String currency;
  final String status;
  final List<InvoiceDetailItem> items;

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

  String get paidDateLabel =>
      paidDate == null ? '' : AppDates.format(paidDate!);

  /// Adapts the API detail to the entity the existing detail/payment UI uses.
  ///
  /// Kept as an adapter rather than making the API model inherit [Invoice]: the
  /// ledger still owns payment writes, while this screen only reads the invoice.
  Invoice toInvoice() {
    return Invoice(
      id: id.toString(),
      number: invoiceNumber,
      title: invoiceNumber,
      billingPeriod: billingPeriodLabel,
      unitLabel: unit?.label ?? '',
      dueDate: dueDateLabel,
      status: invoiceStatus,
      currency: currency,
      items: items.map((item) => item.toInvoiceItem()).toList(growable: false),
      paidDate: paidDateLabel.isEmpty ? null : paidDateLabel,
    );
  }
}
