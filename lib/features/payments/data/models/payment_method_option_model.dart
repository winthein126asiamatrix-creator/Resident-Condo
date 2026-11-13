import '../../domain/entities/payment_method_option.dart';

class PaymentMethodOptionModel extends PaymentMethodOption {
  const PaymentMethodOptionModel({
    required super.id,
    required super.code,
    required super.name,
    required super.isActive,
    required super.requiresProof,
    super.accountName,
    super.accountNumber,
    super.bankName,
    super.qrImageUrl,
    super.instructions,
    super.currency,
  });

  factory PaymentMethodOptionModel.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id'] ?? json['method_id']);
    final code = _asString(json['code'] ?? json['method_code']);
    if ((id == null || id <= 0) && code.trim().isEmpty) {
      throw const FormatException('Payment method is missing its identity.');
    }

    final isActive = _asBool(json['is_active']);
    final requiresProof = _asBool(json['requires_proof']);
    if (isActive == null || requiresProof == null) {
      throw const FormatException('Payment method flags are malformed.');
    }

    return PaymentMethodOptionModel(
      id: id ?? 0,
      code: code,
      name: _asString(json['name'] ?? json['display_name']),
      accountName: _asString(json['account_name']),
      accountNumber: _asString(json['account_number']),
      bankName: _asString(json['bank_name']),
      qrImageUrl: _asString(json['qr_image_url'] ?? json['qr_image']),
      instructions: _asString(json['instructions']),
      currency: _asString(json['currency']),
      isActive: isActive,
      requiresProof: requiresProof,
    );
  }

  factory PaymentMethodOptionModel.fromEntity(PaymentMethodOption method) {
    return PaymentMethodOptionModel(
      id: method.id,
      code: method.code,
      name: method.name,
      accountName: method.accountName,
      accountNumber: method.accountNumber,
      bankName: method.bankName,
      qrImageUrl: method.qrImageUrl,
      instructions: method.instructions,
      currency: method.currency,
      isActive: method.isActive,
      requiresProof: method.requiresProof,
    );
  }

  static List<PaymentMethodOptionModel> parseList(Object? json) {
    final rawItems = _items(json);
    if (rawItems == null) {
      throw const FormatException('Unexpected payment methods response.');
    }

    final methods = <PaymentMethodOptionModel>[];
    for (final item in rawItems) {
      if (item is! Map) {
        continue;
      }
      try {
        methods.add(
          PaymentMethodOptionModel.fromJson(Map<String, dynamic>.from(item)),
        );
      } on FormatException {
        continue;
      }
    }
    return methods;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'name': name,
    'account_name': accountName,
    'account_number': accountNumber,
    'bank_name': bankName,
    'qr_image_url': qrImageUrl,
    'instructions': instructions,
    'currency': currency,
    'is_active': isActive,
    'requires_proof': requiresProof,
  };

  static List<dynamic>? _items(Object? json) {
    if (json is List) {
      return json;
    }
    if (json is! Map) {
      return null;
    }

    var map = Map<String, dynamic>.from(json);
    for (var depth = 0; depth < 2; depth++) {
      final items = map['items'];
      if (items is List) {
        return items;
      }
      final nested = map['data'] ?? map['result'];
      if (nested is Map) {
        map = Map<String, dynamic>.from(nested);
        continue;
      }
      if (nested is List) {
        return nested;
      }
      break;
    }
    final items = map['items'];
    return items is List ? items : null;
  }
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  return null;
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

String _asString(Object? value) {
  if (value is String) {
    return value;
  }
  if (value == null || value == false) {
    return '';
  }
  return value.toString();
}
