import '../../domain/entities/invoice.dart';

class InvoiceModel extends Invoice {
  const InvoiceModel({
    required super.id,
    required super.number,
    required super.title,
    required super.billingPeriod,
    required super.unitLabel,
    required super.dueDate,
    required super.status,
    required super.items,
    super.paidDate,
  });
}
