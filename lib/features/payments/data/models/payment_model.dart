import '../../domain/entities/payment.dart';

class PaymentModel extends Payment {
  const PaymentModel({
    required super.id,
    required super.invoiceNumber,
    required super.residentName,
    required super.unitLabel,
    required super.items,
    required super.amount,
    required super.date,
    required super.method,
    required super.transactionId,
    super.status,
    super.failureReason,
  });
}
