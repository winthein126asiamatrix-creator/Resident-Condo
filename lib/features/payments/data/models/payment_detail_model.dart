import '../../domain/entities/payment_detail.dart';

class PaymentDetailModel extends PaymentDetail {
  const PaymentDetailModel({
    required super.id,
    required super.paymentNumber,
    required super.invoiceNumber,
    required super.amount,
    required super.currency,
    required super.paymentMethod,
    required super.transactionReference,
    required super.status,
    super.invoiceId,
    super.paidAt,
    super.receipt,
  });

  static PaymentDetailModel parse(Object? json) {
    final map = _payloadMap(json);
    if (map == null) {
      return const PaymentDetailModel(
        id: 0,
        paymentNumber: '',
        invoiceNumber: '',
        amount: 0,
        currency: '',
        paymentMethod: '',
        transactionReference: '',
        status: '',
      );
    }
    return PaymentDetailModel.fromJson(map);
  }

  factory PaymentDetailModel.fromJson(Map<String, dynamic> json) {
    return PaymentDetailModel(
      id: _asInt(json['id'] ?? json['payment_id']) ?? 0,
      paymentNumber: _asString(
        json['payment_number'] ?? json['number'] ?? json['reference'],
      ),
      invoiceId: _asInt(json['invoice_id']),
      invoiceNumber: _invoiceNumber(json['invoice_number'] ?? json['invoice']),
      amount: _asDouble(json['amount'] ?? json['total_amount']),
      currency: _asString(json['currency']),
      paymentMethod: _asString(
        json['payment_method'] ?? json['method'] ?? json['payment_type'],
      ),
      transactionReference: _asString(
        json['transaction_reference'] ??
            json['transaction_id'] ??
            json['reference'],
      ),
      status: _asString(json['status']),
      paidAt: _asDate(
        json['paid_at'] ??
            json['paid_date'] ??
            json['payment_date'] ??
            json['created_at'],
      ),
      receipt: _receipt(json['receipt'] ?? json['receipt_info'], json),
    );
  }
}

Map<String, dynamic>? _payloadMap(Object? json) {
  if (json is! Map) {
    return null;
  }
  var map = Map<String, dynamic>.from(json);
  for (var depth = 0; depth < 2; depth++) {
    final nested = map['data'] ?? map['result'] ?? map['payment'];
    if (nested is Map) {
      map = Map<String, dynamic>.from(nested);
      continue;
    }
    break;
  }
  return map;
}

PaymentReceiptInfo? _receipt(Object? value, Map<String, dynamic> parent) {
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final receipt = PaymentReceiptInfo(
      receiptNumber: _asString(
        map['receipt_number'] ?? map['number'] ?? map['reference'],
      ),
      downloadUrl: _asString(
        map['download_url'] ?? map['receipt_url'] ?? map['url'],
      ),
    );
    return receipt.isEmpty ? null : receipt;
  }
  if (value is String && value.trim().isNotEmpty) {
    return PaymentReceiptInfo(receiptNumber: value.trim(), downloadUrl: '');
  }
  final fallback = PaymentReceiptInfo(
    receiptNumber: _asString(
      parent['receipt_number'] ?? parent['receipt_reference'],
    ),
    downloadUrl: _asString(
      parent['receipt_url'] ??
          parent['receipt_download_url'] ??
          parent['download_url'],
    ),
  );
  return fallback.isEmpty ? null : fallback;
}

String _invoiceNumber(Object? value) {
  if (value is Map) {
    return _asString(value['invoice_number'] ?? value['number']);
  }
  return _asString(value);
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _asString(Object? value) => value is String
    ? value
    : (value == null || value == false ? '' : value.toString());

DateTime? _asDate(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value.trim());
}
