import '../../domain/entities/payment_list.dart';

class PaymentListResponseModel extends PaymentListResponse {
  const PaymentListResponseModel({
    required super.items,
    required super.page,
    required super.limit,
    required super.total,
  });

  static PaymentListResponseModel parse(Object? json) {
    if (json is List) {
      return PaymentListResponseModel.fromJson(<String, dynamic>{
        'items': json,
      });
    }
    final map = _payloadMap(json);
    if (map == null) {
      return const PaymentListResponseModel(
        items: <PaymentListItemModel>[],
        page: 1,
        limit: 20,
        total: 0,
      );
    }
    return PaymentListResponseModel.fromJson(map);
  }

  factory PaymentListResponseModel.fromJson(Map<String, dynamic> json) {
    final map = _payloadMap(json) ?? json;
    final rawItems = map['items'] ?? map['payments'] ?? map['records'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => PaymentListItemModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <PaymentListItemModel>[];
    final meta = _metaMap(map);
    final page =
        _asInt(
          map['page'] ??
              map['current_page'] ??
              meta['page'] ??
              meta['current_page'],
        ) ??
        1;
    final limit =
        _asInt(
          map['limit'] ??
              map['per_page'] ??
              map['page_size'] ??
              meta['limit'] ??
              meta['per_page'] ??
              meta['page_size'],
        ) ??
        (items.isEmpty ? 20 : items.length);
    var total =
        _asInt(map['total'] ?? meta['total'] ?? meta['total_count']) ??
        items.length;
    final lastPage = _asInt(map['last_page'] ?? meta['last_page']);
    if (lastPage != null && lastPage > 0) {
      final lastPageTotal = lastPage * limit;
      if (lastPageTotal > total) {
        total = lastPageTotal;
      }
    }
    return PaymentListResponseModel(
      items: items,
      page: page <= 0 ? 1 : page,
      limit: limit <= 0 ? 20 : limit,
      total: total < items.length ? items.length : total,
    );
  }

  factory PaymentListResponseModel.fromEntity(
    PaymentListResponse response, {
    List<PaymentListItem>? items,
    int? page,
    int? limit,
    int? total,
  }) {
    final source = items ?? response.items;
    return PaymentListResponseModel(
      items: source
          .map(
            (item) => item is PaymentListItemModel
                ? item
                : PaymentListItemModel.fromEntity(item),
          )
          .toList(growable: false),
      page: page ?? response.page,
      limit: limit ?? response.limit,
      total: total ?? response.total,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'items': items
        .map(
          (item) => item is PaymentListItemModel
              ? item.toJson()
              : PaymentListItemModel.fromEntity(item).toJson(),
        )
        .toList(),
    'page': page,
    'limit': limit,
    'total': total,
  };
}

class PaymentListItemModel extends PaymentListItem {
  const PaymentListItemModel({
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
  });

  factory PaymentListItemModel.fromJson(Map<String, dynamic> json) {
    return PaymentListItemModel(
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
    );
  }

  factory PaymentListItemModel.fromEntity(PaymentListItem item) {
    return PaymentListItemModel(
      id: item.id,
      paymentNumber: item.paymentNumber,
      invoiceId: item.invoiceId,
      invoiceNumber: item.invoiceNumber,
      amount: item.amount,
      currency: item.currency,
      paymentMethod: item.paymentMethod,
      transactionReference: item.transactionReference,
      status: item.status,
      paidAt: item.paidAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'payment_number': paymentNumber,
    'invoice_id': invoiceId,
    'invoice_number': invoiceNumber,
    'amount': amount,
    'currency': currency,
    'payment_method': paymentMethod,
    'transaction_reference': transactionReference,
    'status': status,
    'paid_at': paidAt?.toIso8601String(),
  };
}

Map<String, dynamic>? _payloadMap(Object? json) {
  if (json is! Map) {
    return null;
  }
  var map = Map<String, dynamic>.from(json);
  for (var depth = 0; depth < 2; depth++) {
    final nested = map['data'] ?? map['result'] ?? map['payments'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      for (final key in const <String>[
        'page',
        'limit',
        'total',
        'current_page',
        'per_page',
        'page_size',
        'last_page',
        'meta',
        'pagination',
      ]) {
        nestedMap.putIfAbsent(key, () => map[key]);
      }
      map = nestedMap;
      continue;
    }
    if (nested is List) {
      map['items'] = nested;
    }
    break;
  }
  return map;
}

Map<String, dynamic> _metaMap(Map<String, dynamic> map) {
  for (final key in const <String>['meta', 'pagination', 'page_info']) {
    final value = map[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }
  return const <String, dynamic>{};
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
