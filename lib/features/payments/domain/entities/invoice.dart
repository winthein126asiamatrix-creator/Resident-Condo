enum InvoiceStatus { paid, partiallyPaid, pending, overdue, unpaid }

extension InvoiceStatusLabel on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.partiallyPaid:
        return 'Partial';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.unpaid:
        return 'Unpaid';
    }
  }
}

/// Every charge keeps its own identity so the resident can pay for one, some
/// or all of them separately.
///
/// Business rule: Monthly Rent and Monthly Condo Fee are always separate line
/// items, and parking / utility / facility / service / store / violation charges
/// are never bundled into the condo fee.
enum InvoiceItemType {
  rent,
  condoFee,
  parking,
  utility,
  facility,
  service,
  storeFee,
  violation,
  lateFee,
  other,
}

extension InvoiceItemTypeLabel on InvoiceItemType {
  String get label {
    switch (this) {
      case InvoiceItemType.rent:
        return 'Monthly Rent';
      case InvoiceItemType.condoFee:
        return 'Monthly Condo Fee';
      case InvoiceItemType.parking:
        return 'Parking Fee';
      case InvoiceItemType.utility:
        return 'Utility Fee';
      case InvoiceItemType.facility:
        return 'Facility Fee';
      case InvoiceItemType.service:
        return 'Service Fee';
      case InvoiceItemType.storeFee:
        return 'Store Fee';
      case InvoiceItemType.violation:
        return 'Violation Fine';
      case InvoiceItemType.lateFee:
        return 'Late Fee';
      case InvoiceItemType.other:
        return 'Other Fee';
    }
  }

  String get shortLabel {
    switch (this) {
      case InvoiceItemType.rent:
        return 'Rent';
      case InvoiceItemType.condoFee:
        return 'Condo fee';
      case InvoiceItemType.parking:
        return 'Parking';
      case InvoiceItemType.utility:
        return 'Utilities';
      case InvoiceItemType.facility:
        return 'Facility';
      case InvoiceItemType.service:
        return 'Service';
      case InvoiceItemType.storeFee:
        return 'Store';
      case InvoiceItemType.violation:
        return 'Fine';
      case InvoiceItemType.lateFee:
        return 'Late fee';
      case InvoiceItemType.other:
        return 'Other';
    }
  }

  /// Fee types that belong to the management company rather than the landlord.
  bool get isManagementCharge => this != InvoiceItemType.rent;
}

/// Maps the backend's invoice status vocabulary onto the app's enum.
///
/// Shared by the dashboard and the invoice list/detail, so an unfamiliar status
/// is treated the same way everywhere instead of crashing or inventing a new
/// state.
InvoiceStatus invoiceStatusFromApi(Object? value) {
  final status = value is String
      ? value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')
      : '';
  switch (status) {
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
      return InvoiceStatus.pending;
  }
}

/// Maps a backend `fee_type` onto the app's charge line type.
InvoiceItemType invoiceItemTypeFromApi(Object? value) {
  final type = value is String
      ? value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')
      : '';
  switch (type) {
    case 'monthly_rent':
    case 'rent':
    case 'rent_fee':
      return InvoiceItemType.rent;
    case 'monthly_condo_fee':
    case 'condo_fee':
    case 'condominium_fee':
    case 'maintenance_fee':
      return InvoiceItemType.condoFee;
    case 'parking':
    case 'parking_fee':
      return InvoiceItemType.parking;
    case 'utility':
    case 'utilities':
    case 'utility_fee':
      return InvoiceItemType.utility;
    case 'facility':
    case 'facility_fee':
      return InvoiceItemType.facility;
    case 'service':
    case 'service_fee':
      return InvoiceItemType.service;
    case 'store':
    case 'store_fee':
      return InvoiceItemType.storeFee;
    case 'violation':
    case 'violation_fine':
    case 'fine':
      return InvoiceItemType.violation;
    case 'late_fee':
    case 'latefee':
      return InvoiceItemType.lateFee;
    default:
      return InvoiceItemType.other;
  }
}

class InvoiceItem {
  const InvoiceItem({
    required this.type,
    required this.amount,
    this.note = '',
    this.isPaid = false,
    this.paidDate,
    this.mustPaid = false,
    this.apiPayable,
    this.sourcePaidAmount,
    this.sourceRemainingAmount,
  });

  final InvoiceItemType type;
  final double amount;
  final String note;
  final bool isPaid;
  final String? paidDate;

  /// Mandatory charges (rent, condo fee, late fees) always travel with the
  /// payment: they are pre-selected and cannot be unchecked.
  final bool mustPaid;

  /// The API's explicit `is_payable` answer, when the line came from an API
  /// response. Null keeps the local ledger's amount-based rule.
  final bool? apiPayable;

  /// The API's item-level `paid_amount` and `remaining_amount`, when present.
  ///
  /// They are kept separately from [amount] because [amount] is the original
  /// charge, while a partially paid line only owes its remaining balance.
  final double? sourcePaidAmount;
  final double? sourceRemainingAmount;

  /// Stable identity used when paying a subset of the invoice.
  String get key => '${type.name}|${note.isEmpty ? label : note}';

  String get label => type.label;

  /// Only unpaid, non-zero charges the API allows can be selected for payment.
  bool get isPayable => !isPaid && (apiPayable ?? amount > 0);

  /// A mandatory charge still has to be outstanding to be payable, and it can
  /// never be deselected by the resident.
  bool get isMandatory => mustPaid && isPayable;

  bool get isZero => amount <= 0;

  double get dueAmount => isPaid ? 0 : (sourceRemainingAmount ?? amount);

  double get paidAmount => sourcePaidAmount ?? (isPaid ? amount : 0);

  InvoiceItem copyWith({
    bool? isPaid,
    String? paidDate,
    bool? mustPaid,
    bool? apiPayable,
    double? sourcePaidAmount,
    double? sourceRemainingAmount,
  }) {
    return InvoiceItem(
      type: type,
      amount: amount,
      note: note,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      mustPaid: mustPaid ?? this.mustPaid,
      apiPayable: apiPayable ?? this.apiPayable,
      sourcePaidAmount: sourcePaidAmount ?? this.sourcePaidAmount,
      sourceRemainingAmount:
          sourceRemainingAmount ?? this.sourceRemainingAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceItem &&
          other.type == type &&
          other.amount == amount &&
          other.note == note &&
          other.isPaid == isPaid &&
          other.mustPaid == mustPaid &&
          other.apiPayable == apiPayable &&
          other.sourcePaidAmount == sourcePaidAmount &&
          other.sourceRemainingAmount == sourceRemainingAmount;

  @override
  int get hashCode => Object.hash(
    type,
    amount,
    note,
    isPaid,
    mustPaid,
    apiPayable,
    sourcePaidAmount,
    sourceRemainingAmount,
  );

  @override
  String toString() =>
      'InvoiceItem(${type.name}, $amount, paid: $isPaid, mustPaid: $mustPaid)';
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.title,
    required this.billingPeriod,
    required this.unitLabel,
    required this.dueDate,
    required this.status,
    required this.items,
    this.paidDate,
    this.currency = '',
    this.sourceTotalAmount,
    this.sourcePaidAmount,
    this.sourceRemainingAmount,
  });

  final String id;
  final String number;
  final String title;
  final String billingPeriod;
  final String unitLabel;
  final String dueDate;
  final InvoiceStatus status;
  final List<InvoiceItem> items;
  final String? paidDate;

  /// The API's currency code, when this invoice came from the backend.
  final String currency;

  /// Invoice-level amounts from the API, when this invoice came from a detail
  /// response. Null keeps the local ledger's item-derived calculations.
  final double? sourceTotalAmount;
  final double? sourcePaidAmount;
  final double? sourceRemainingAmount;

  /// Full value of the invoice including everything already settled.
  double get total =>
      sourceTotalAmount ?? items.fold(0, (sum, item) => sum + item.amount);

  /// Value that is still open. The backend's `remaining_amount` is authoritative
  /// when present; local ledger invoices fall back to their item balances.
  double get remainingAmount =>
      sourceRemainingAmount ??
      items.fold(0, (sum, item) => sum + item.dueAmount);

  /// Value that is still open. This is what the resident has to pay.
  double get amountDue => remainingAmount;

  double get amountPaid => sourcePaidAmount ?? (total - remainingAmount);

  List<InvoiceItem> get unpaidItems =>
      items.where((item) => item.isPayable).toList();

  /// Charges that must always be part of the payment.
  List<InvoiceItem> get mandatoryItems =>
      items.where((item) => item.isMandatory).toList();

  /// Value of the mandatory charges that are still open.
  double get mandatoryDue =>
      mandatoryItems.fold(0, (sum, item) => sum + item.dueAmount);

  bool get hasPaidItems => items.any((item) => item.isPaid);

  bool get isFullyPaid => amountDue <= 0;

  bool get isPartiallyPaid => hasPaidItems && !isFullyPaid;

  /// An invoice can be paid while it is unpaid, overdue or partially paid.
  bool get isPayable => !isFullyPaid;

  double amountFor(InvoiceItemType type) => items
      .where((item) => item.type == type)
      .fold(0, (sum, item) => sum + item.dueAmount);

  double get rentDue => amountFor(InvoiceItemType.rent);

  double get condoFeeDue => amountFor(InvoiceItemType.condoFee);

  InvoiceItem? itemByKey(String key) {
    for (final item in items) {
      if (item.key == key) {
        return item;
      }
    }
    return null;
  }

  Invoice copyWith({
    InvoiceStatus? status,
    List<InvoiceItem>? items,
    String? paidDate,
    double? sourceTotalAmount,
    double? sourcePaidAmount,
    double? sourceRemainingAmount,
  }) {
    return Invoice(
      id: id,
      number: number,
      title: title,
      billingPeriod: billingPeriod,
      unitLabel: unitLabel,
      dueDate: dueDate,
      status: status ?? this.status,
      items: items ?? this.items,
      paidDate: paidDate ?? this.paidDate,
      currency: currency,
      sourceTotalAmount: sourceTotalAmount ?? this.sourceTotalAmount,
      sourcePaidAmount: sourcePaidAmount ?? this.sourcePaidAmount,
      sourceRemainingAmount:
          sourceRemainingAmount ?? this.sourceRemainingAmount,
    );
  }
}
