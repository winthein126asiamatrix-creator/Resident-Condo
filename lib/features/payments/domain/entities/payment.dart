import 'invoice.dart';

enum PaymentMethod { card, bankTransfer, digitalWallet, other }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.card:
        return 'Credit / Debit Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.digitalWallet:
        return 'Digital Wallet';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}

PaymentMethod paymentMethodFromCode(String code) {
  return switch (code.trim().toLowerCase()) {
    'card' || 'credit_card' || 'debit_card' => PaymentMethod.card,
    'bank_transfer' || 'bank' => PaymentMethod.bankTransfer,
    'digital_wallet' || 'wallet' => PaymentMethod.digitalWallet,
    _ => PaymentMethod.other,
  };
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

PaymentStatus? paymentStatusFromApi(String value) {
  return switch (value.trim().toLowerCase()) {
    'paid' ||
    'successful' ||
    'succeeded' ||
    'completed' ||
    'settled' => PaymentStatus.successful,
    'failed' || 'declined' || 'error' => PaymentStatus.failed,
    _ => null,
  };
}

String paymentStatusLabelFromApi(String value) {
  final parsed = paymentStatusFromApi(value);
  if (parsed != null) {
    return parsed.label;
  }
  final raw = value.trim();
  if (raw.isEmpty) {
    return 'Unknown';
  }
  final normalized = raw.replaceAll(RegExp(r'[_-]+'), ' ');
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

String paymentMethodLabelFromApi(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    return '';
  }
  return switch (raw.toLowerCase()) {
    'card' || 'credit_card' || 'debit_card' => 'Credit / Debit Card',
    'bank_transfer' || 'bank' => 'Bank Transfer',
    'digital_wallet' || 'wallet' => 'Digital Wallet',
    'kbz_pay' || 'kbzpay' => 'KBZ Pay',
    'wave_money' || 'wavemoney' => 'Wave Money',
    'cash' => 'Cash',
    _ => _humanizePaymentMethod(raw),
  };
}

String _humanizePaymentMethod(String value) {
  final words = value
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
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
    this.paymentMethodCode,
    this.paymentMethodName,
    this.proofPath,
    this.proofFileName,
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
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final String? proofPath;
  final String? proofFileName;

  String get methodLabel {
    final name = paymentMethodName?.trim() ?? '';
    return name.isEmpty ? method.label : name;
  }

  bool get hasProof => (proofPath?.trim() ?? '').isNotEmpty;

  bool get isSuccessful => status == PaymentStatus.successful;

  bool get isFailed => status == PaymentStatus.failed;
}
