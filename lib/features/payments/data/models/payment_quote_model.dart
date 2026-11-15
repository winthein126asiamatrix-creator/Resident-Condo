import '../../domain/entities/payment_quote.dart';

/// Parsed `POST /payments/quote` response.
class PaymentQuoteModel extends PaymentQuote {
  const PaymentQuoteModel({
    required super.quoteId,
    required super.invoiceId,
    required super.totalAmount,
    required super.currency,
    required super.expiresAt,
    required super.items,
  });

  static PaymentQuoteModel parse(Object? json) {
    final map = _payloadMap(json);
    if (map == null) {
      return const PaymentQuoteModel(
        quoteId: '',
        invoiceId: 0,
        totalAmount: 0,
        currency: '',
        expiresAt: null,
        items: <PaymentQuoteItem>[],
      );
    }
    return PaymentQuoteModel.fromJson(map);
  }

  factory PaymentQuoteModel.fromJson(Map<String, dynamic> json) {
    return PaymentQuoteModel(
      quoteId: _asString(json['quote_id']),
      invoiceId: _asInt(json['invoice_id']) ?? 0,
      totalAmount: _asDouble(json['total_amount'] ?? json['amount']),
      currency: _asString(json['currency']),
      expiresAt: _asDate(json['expires_at']),
      items: _itemMaps(json['items'])
          .map(
            (item) => PaymentQuoteItem(
              id: _asInt(item['item_id'] ?? item['id']) ?? 0,
              amount: _asDouble(item['amount']),
            ),
          )
          .toList(growable: false),
    );
  }
}

Map<String, dynamic>? _payloadMap(Object? json) {
  if (json is! Map) {
    return null;
  }
  var map = Map<String, dynamic>.from(json);
  for (var depth = 0; depth < 2; depth++) {
    final nested = map['data'] ?? map['result'] ?? map['quote'];
    if (nested is Map) {
      map = Map<String, dynamic>.from(nested);
      continue;
    }
    break;
  }
  return map;
}

List<Map<String, dynamic>> _itemMaps(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

String _asString(Object? value) {
  if (value is String) {
    return value.trim();
  }
  if (value == null || value == false) {
    return '';
  }
  return value.toString().trim();
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
