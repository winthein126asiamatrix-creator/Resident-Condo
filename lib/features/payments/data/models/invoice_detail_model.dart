import '../../domain/entities/invoice_detail.dart';

/// Parsed `GET /api/v1/payments/invoices/{invoice_id}` response.
class InvoiceDetailModel extends InvoiceDetail {
  const InvoiceDetailModel({
    required super.id,
    required super.invoiceNumber,
    required super.billingPeriod,
    required super.totalAmount,
    required super.paidAmount,
    required super.remainingAmount,
    required super.currency,
    required super.status,
    required super.items,
    super.unit,
    super.invoiceDate,
    super.dueDate,
    super.paidDate,
  });

  static InvoiceDetailModel parse(Object? json) {
    final map = _payloadMap(json);
    if (map == null) {
      return const InvoiceDetailModel(
        id: 0,
        invoiceNumber: '',
        billingPeriod: '',
        totalAmount: 0,
        paidAmount: 0,
        remainingAmount: 0,
        currency: '',
        status: '',
        items: <InvoiceItemModel>[],
      );
    }
    return InvoiceDetailModel.fromJson(map);
  }

  factory InvoiceDetailModel.fromJson(Map<String, dynamic> json) {
    final items = _itemMaps(json['items'])
        .map(InvoiceItemModel.fromJson)
        .toList(growable: false);
    final itemTotal = items.fold<double>(0, (sum, item) => sum + item.amount);
    final itemPaid = items.fold<double>(
      0,
      (sum, item) => sum + item.paidAmount,
    );
    final itemRemaining = items.fold<double>(
      0,
      (sum, item) => sum + item.remainingAmount,
    );
    final total = _asDouble(json['total_amount'] ?? json['total'] ?? itemTotal);
    final paid = _asDouble(json['paid_amount'] ?? json['paid'] ?? itemPaid);
    final remaining = _asDouble(
      json['remaining_amount'] ??
          json['balance'] ??
          (total - paid > 0 ? total - paid : itemRemaining),
    );
    return InvoiceDetailModel(
      id: _asInt(json['id']) ?? 0,
      invoiceNumber: _asString(
        json['invoice_number'] ?? json['number'] ?? json['reference'],
      ),
      billingPeriod: _asString(
        json['billing_period'] ?? json['period'] ?? json['billing_month'],
      ),
      unit: _unit(json['unit'] ?? json['unit_info']),
      invoiceDate: _asDate(
        json['invoice_date'] ?? json['issued_at'] ?? json['date'],
      ),
      dueDate: _asDate(json['due_date']),
      paidDate: _asDate(json['paid_at'] ?? json['paid_date']),
      totalAmount: total,
      paidAmount: paid,
      remainingAmount: remaining < 0 ? 0 : remaining,
      currency: _asString(json['currency']),
      status: _asString(json['status']),
      items: items,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'invoice_number': invoiceNumber,
    'billing_period': billingPeriod,
    if (unit != null)
      'unit': <String, dynamic>{
        'id': unit!.id,
        'name': unit!.name,
        'unit_number': unit!.number,
        'block': unit!.block,
        'floor': unit!.floor,
      },
    'invoice_date': invoiceDate?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'paid_date': paidDate?.toIso8601String(),
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'remaining_amount': remainingAmount,
    'currency': currency,
    'status': status,
    'items': items
        .map(
          (item) => item is InvoiceItemModel
              ? item.toJson()
              : InvoiceItemModel.fromEntity(item).toJson(),
        )
        .toList(),
  };
}

class InvoiceUnitModel extends InvoiceUnit {
  const InvoiceUnitModel({
    super.id,
    super.name,
    super.number,
    super.block,
    super.floor,
  });

  factory InvoiceUnitModel.fromJson(Map<String, dynamic> json) {
    return InvoiceUnitModel(
      id: _asInt(json['id']),
      name: _asString(json['name'] ?? json['unit_name'] ?? json['label']),
      number: _asString(
        json['unit_number'] ?? json['number'] ?? json['unit_no'],
      ),
      block: _asString(json['block'] ?? json['building']),
      floor: _asString(json['floor']),
    );
  }
}

class InvoiceItemModel extends InvoiceDetailItem {
  const InvoiceItemModel({
    required super.feeType,
    required super.amount,
    super.id,
    super.name,
    super.description,
    super.paidAmount,
    super.remainingAmount,
    super.isMandatory,
    super.isPayable,
    super.isPaid,
    super.paidDate,
    super.status,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    final amount = _asDouble(json['amount'] ?? json['total_amount']);
    final paid = _asDouble(json['paid_amount'] ?? json['paid']);
    final remaining = _asDouble(
      json['remaining_amount'] ?? json['balance'] ?? (amount - paid),
    );
    final status = _asString(json['status']);
    final normalizedStatus = status.trim().toLowerCase();
    final isPaid =
        _asBool(json['is_paid'] ?? json['paid']) ??
        (normalizedStatus == 'paid' ||
            normalizedStatus == 'settled' ||
            (remaining <= 0 && amount > 0));
    final isPayable =
        _asBool(json['is_payable'] ?? json['payable']) ??
        (remaining > 0 && !isPaid);
    return InvoiceItemModel(
      id: _asInt(json['id']),
      feeType: _asString(
        json['fee_type'] ?? json['type'] ?? json['charge_type'],
      ),
      name: _asString(json['name'] ?? json['label']),
      description: _asString(
        json['description'] ?? json['note'] ?? json['name'] ?? json['label'],
      ),
      amount: amount,
      paidAmount: paid,
      remainingAmount: remaining < 0 ? 0 : remaining,
      isMandatory: _asBool(json['is_mandatory'] ?? json['mandatory']) ?? false,
      isPayable: isPayable,
      isPaid: isPaid,
      paidDate: _asDate(json['paid_at'] ?? json['paid_date']),
      status: status,
    );
  }

  factory InvoiceItemModel.fromEntity(InvoiceDetailItem item) {
    return InvoiceItemModel(
      id: item.id,
      feeType: item.feeType,
      name: item.name,
      description: item.description,
      amount: item.amount,
      paidAmount: item.paidAmount,
      remainingAmount: item.remainingAmount,
      isMandatory: item.isMandatory,
      isPayable: item.isPayable,
      isPaid: item.isPaid,
      paidDate: item.paidDate,
      status: item.status,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fee_type': feeType,
    'name': name,
    'description': description,
    'amount': amount,
    'paid_amount': paidAmount,
    'remaining_amount': remainingAmount,
    'is_mandatory': isMandatory,
    'is_payable': isPayable,
    'is_paid': isPaid,
    'paid_date': paidDate?.toIso8601String(),
    'status': status,
  };
}

Map<String, dynamic>? _payloadMap(Object? json) {
  if (json is! Map) {
    return null;
  }
  var map = Map<String, dynamic>.from(json);
  for (var depth = 0; depth < 2; depth++) {
    final nested = map['data'] ?? map['result'] ?? map['invoice'];
    if (nested is Map) {
      map = Map<String, dynamic>.from(nested);
      continue;
    }
    break;
  }
  return map;
}

InvoiceUnitModel? _unit(Object? value) {
  if (value is Map) {
    return InvoiceUnitModel.fromJson(Map<String, dynamic>.from(value));
  }
  if (value is String && value.trim().isNotEmpty) {
    return InvoiceUnitModel(name: value.trim());
  }
  return null;
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

bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
        return false;
    }
  }
  return null;
}

DateTime? _asDate(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value.trim());
}
