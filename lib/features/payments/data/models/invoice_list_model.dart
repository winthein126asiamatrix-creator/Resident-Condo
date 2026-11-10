import '../../domain/entities/invoice_list.dart';

/// Parsed first page of `GET /api/v1/payments/invoices`.
class InvoiceListResponseModel extends InvoiceListResponse {
  const InvoiceListResponseModel({
    required super.items,
    required super.page,
    required super.limit,
    required super.total,
  });

  static InvoiceListResponseModel parse(Object? json) {
    final map = _payloadMap(json);
    if (map == null) {
      return const InvoiceListResponseModel(
        items: <InvoiceListItemModel>[],
        page: 1,
        limit: 20,
        total: 0,
      );
    }
    return InvoiceListResponseModel.fromJson(map);
  }

  factory InvoiceListResponseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => InvoiceListItemModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <InvoiceListItemModel>[];
    final page = _asInt(json['page']) ?? 1;
    final limit = _asInt(json['limit']) ?? (items.isEmpty ? 20 : items.length);
    final total = _asInt(json['total']) ?? items.length;
    return InvoiceListResponseModel(
      items: items,
      page: page,
      limit: limit,
      total: total,
    );
  }

  factory InvoiceListResponseModel.fromEntity(
    InvoiceListResponse response, {
    List<InvoiceListItem>? items,
    int? page,
    int? limit,
    int? total,
  }) {
    final source = items ?? response.items;
    return InvoiceListResponseModel(
      items: source
          .map(
            (item) => item is InvoiceListItemModel
                ? item
                : InvoiceListItemModel.fromEntity(item),
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
          (item) => item is InvoiceListItemModel
              ? item.toJson()
              : InvoiceListItemModel.fromEntity(item).toJson(),
        )
        .toList(),
    'page': page,
    'limit': limit,
    'total': total,
  };
}

class InvoiceListItemModel extends InvoiceListItem {
  const InvoiceListItemModel({
    required super.id,
    required super.invoiceNumber,
    required super.billingPeriod,
    required super.totalAmount,
    required super.paidAmount,
    required super.remainingAmount,
    required super.currency,
    required super.status,
    super.invoiceDate,
    super.dueDate,
  });

  factory InvoiceListItemModel.fromJson(Map<String, dynamic> json) {
    final total = _asDouble(json['total_amount'] ?? json['total']);
    final paid = _asDouble(json['paid_amount'] ?? json['paid']);
    final remaining = _asDouble(
      json['remaining_amount'] ?? json['balance'] ?? (total - paid),
    );
    return InvoiceListItemModel(
      id: _asInt(json['id']) ?? 0,
      invoiceNumber: _asString(
        json['invoice_number'] ?? json['number'] ?? json['reference'],
      ),
      billingPeriod: _asString(
        json['billing_period'] ?? json['period'] ?? json['billing_month'],
      ),
      invoiceDate: _asDate(
        json['invoice_date'] ?? json['issued_at'] ?? json['date'],
      ),
      dueDate: _asDate(json['due_date']),
      totalAmount: total,
      paidAmount: paid,
      remainingAmount: remaining < 0 ? 0 : remaining,
      currency: _asString(json['currency']),
      status: _asString(json['status']),
    );
  }

  factory InvoiceListItemModel.fromEntity(InvoiceListItem item) {
    return InvoiceListItemModel(
      id: item.id,
      invoiceNumber: item.invoiceNumber,
      billingPeriod: item.billingPeriod,
      invoiceDate: item.invoiceDate,
      dueDate: item.dueDate,
      totalAmount: item.totalAmount,
      paidAmount: item.paidAmount,
      remainingAmount: item.remainingAmount,
      currency: item.currency,
      status: item.status,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'invoice_number': invoiceNumber,
    'billing_period': billingPeriod,
    'invoice_date': invoiceDate?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'remaining_amount': remainingAmount,
    'currency': currency,
    'status': status,
  };
}

Map<String, dynamic>? _payloadMap(Object? json) {
  if (json is! Map) {
    return null;
  }
  final map = Map<String, dynamic>.from(json);
  for (final key in const <String>['data', 'result', 'invoices']) {
    final nested = map[key];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
  }
  return map;
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
