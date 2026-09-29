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
/// items, and parking / utility / facility / service / violation charges are
/// never bundled into the condo fee.
enum InvoiceItemType {
  rent,
  condoFee,
  parking,
  utility,
  facility,
  service,
  violation,
  lateFee,
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
      case InvoiceItemType.violation:
        return 'Violation Fine';
      case InvoiceItemType.lateFee:
        return 'Late Fee';
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
      case InvoiceItemType.violation:
        return 'Fine';
      case InvoiceItemType.lateFee:
        return 'Late fee';
    }
  }

  /// Fee types that belong to the management company rather than the landlord.
  bool get isManagementCharge => this != InvoiceItemType.rent;
}

class InvoiceItem {
  const InvoiceItem({
    required this.type,
    required this.amount,
    this.note = '',
    this.isPaid = false,
    this.paidDate,
    this.mustPaid = false,
  });

  final InvoiceItemType type;
  final double amount;
  final String note;
  final bool isPaid;
  final String? paidDate;

  /// Mandatory charges (rent, condo fee, late fees) always travel with the
  /// payment: they are pre-selected and cannot be unchecked.
  final bool mustPaid;

  /// Stable identity used when paying a subset of the invoice.
  String get key => '${type.name}|${note.isEmpty ? label : note}';

  String get label => type.label;

  /// Only unpaid, non-zero charges can be selected for payment.
  bool get isPayable => !isPaid && amount > 0;

  /// A mandatory charge still has to be outstanding to be payable, and it can
  /// never be deselected by the resident.
  bool get isMandatory => mustPaid && isPayable;

  bool get isZero => amount <= 0;

  double get dueAmount => isPaid ? 0 : amount;

  double get paidAmount => isPaid ? amount : 0;

  InvoiceItem copyWith({
    bool? isPaid,
    String? paidDate,
    bool? mustPaid,
  }) {
    return InvoiceItem(
      type: type,
      amount: amount,
      note: note,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      mustPaid: mustPaid ?? this.mustPaid,
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
          other.mustPaid == mustPaid;

  @override
  int get hashCode => Object.hash(type, amount, note, isPaid, mustPaid);

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

  /// Full value of the invoice including everything already settled.
  double get total => items.fold(0, (sum, item) => sum + item.amount);

  /// Value that is still open. This is what the resident has to pay.
  double get amountDue =>
      items.fold(0, (sum, item) => sum + item.dueAmount);

  double get amountPaid => total - amountDue;

  List<InvoiceItem> get unpaidItems =>
      items.where((item) => item.isPayable).toList();

  /// Charges that must always be part of the payment.
  List<InvoiceItem> get mandatoryItems =>
      items.where((item) => item.isMandatory).toList();

  /// Value of the mandatory charges that are still open.
  double get mandatoryDue => mandatoryItems.fold(
    0,
    (sum, item) => sum + item.dueAmount,
  );

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
    );
  }
}
