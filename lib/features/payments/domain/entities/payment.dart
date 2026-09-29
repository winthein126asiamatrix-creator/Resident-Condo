import 'invoice.dart';

enum PaymentMethod { card, bankTransfer, digitalWallet }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.card:
        return 'Credit / Debit Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.digitalWallet:
        return 'Digital Wallet';
    }
  }
}

enum PaymentStatus { successful, failed }

extension PaymentStatusLabel on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.successful:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
    }
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.invoiceNumber,
    required this.residentName,
    required this.unitLabel,
    required this.items,
    required this.amount,
    required this.date,
    required this.method,
    required this.transactionId,
    this.status = PaymentStatus.successful,
    this.failureReason,
  });

  final String id;
  final String invoiceNumber;
  final String residentName;
  final String unitLabel;
  final List<InvoiceItem> items;
  final double amount;
  final String date;
  final PaymentMethod method;
  final String transactionId;
  final PaymentStatus status;
  final String? failureReason;

  bool get isSuccessful => status == PaymentStatus.successful;

  bool get isFailed => status == PaymentStatus.failed;
}
