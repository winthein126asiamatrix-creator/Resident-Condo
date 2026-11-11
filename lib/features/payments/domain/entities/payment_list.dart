import '../../../../core/utils/app_dates.dart';
import 'payment.dart';

class PaymentListItem {
  const PaymentListItem({
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

  PaymentStatus? get paymentStatus => paymentStatusFromApi(status);

  String get statusLabel => paymentStatusLabelFromApi(status);

  String get paymentMethodLabel => paymentMethodLabelFromApi(paymentMethod);

  String get paidAtLabel => paidAt == null ? '' : AppDates.format(paidAt!);

  bool get hasValidId => id > 0;
}

class PaymentListResponse {
  const PaymentListResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<PaymentListItem> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;
}

class CachedPaymentList {
  const CachedPaymentList({required this.response, required this.updatedAt});

  final PaymentListResponse response;
  final DateTime updatedAt;
}
