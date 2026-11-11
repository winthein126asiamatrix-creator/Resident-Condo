import '../../../../core/utils/app_dates.dart';
import 'payment.dart';

class PaymentReceiptInfo {
  const PaymentReceiptInfo({
    required this.receiptNumber,
    required this.downloadUrl,
  });

  final String receiptNumber;
  final String downloadUrl;

  bool get hasDownloadUrl => downloadUrl.trim().isNotEmpty;

  bool get isEmpty => receiptNumber.trim().isEmpty && !hasDownloadUrl;
}

class PaymentDetail {
  const PaymentDetail({
    required this.id,
    required this.paymentNumber,
    required this.invoiceNumber,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.transactionReference,
    required this.status,
    this.invoiceId,
    this.paidAt,
    this.receipt,
  });

  final int id;
  final String paymentNumber;
  final int? invoiceId;
  final String invoiceNumber;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String transactionReference;
  final String status;
  final DateTime? paidAt;
  final PaymentReceiptInfo? receipt;

  PaymentStatus? get paymentStatus => paymentStatusFromApi(status);

  String get statusLabel => paymentStatusLabelFromApi(status);

  String get paymentMethodLabel => paymentMethodLabelFromApi(paymentMethod);

  String get paidAtLabel =>
      paidAt == null ? '' : AppDates.formatDateTime(paidAt!.toLocal());

  bool get hasReceipt => receipt != null && !receipt!.isEmpty;
}
