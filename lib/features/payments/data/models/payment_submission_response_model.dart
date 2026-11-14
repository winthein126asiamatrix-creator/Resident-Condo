import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/payment.dart';

class PaymentSubmissionResponseModel {
  const PaymentSubmissionResponseModel({
    required this.paymentId,
    required this.paymentNumber,
    required this.quoteId,
    required this.amount,
    required this.currency,
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.status,
    this.proofImageUrl,
    this.submittedAt,
  });

  final int paymentId;
  final String paymentNumber;
  final String quoteId;
  final double amount;
  final String currency;
  final int paymentMethodId;
  final String paymentMethodName;
  final String? proofImageUrl;
  final String status;
  final DateTime? submittedAt;

  static PaymentSubmissionResponseModel parse(Object? json) {
    final map = _payloadMap(json);
    if (map == null) {
      throw const FormatException('Unexpected payment response.');
    }

    final paymentId = _asInt(map['payment_id'] ?? map['id']);
    if (paymentId == null || paymentId <= 0) {
      throw const FormatException('Payment response is missing payment_id.');
    }

    final paymentNumber = _asString(
      map['payment_number'] ?? map['number'] ?? map['reference'],
    );
    if (paymentNumber.isEmpty) {
      throw const FormatException('Payment response is missing payment_number.');
    }

    final quoteId = _asString(map['quote_id'] ?? map['invoice_number']);
    final amount = _asDouble(map['amount'] ?? map['total_amount']);
    final currency = _asString(map['currency']);
    final methodJson = map['payment_method'];
    final methodId = methodJson is Map
        ? _asInt(methodJson['id'] ?? methodJson['payment_method_id'])
        : _asInt(map['payment_method_id']);
    final methodName = methodJson is Map
        ? _asString(methodJson['name'] ?? methodJson['payment_method_name'])
        : _asString(map['payment_method_name'] ?? map['payment_method']);
    final status = _asString(map['status']);
    if (status.isEmpty) {
      throw const FormatException('Payment response is missing status.');
    }

    return PaymentSubmissionResponseModel(
      paymentId: paymentId,
      paymentNumber: paymentNumber,
      quoteId: quoteId,
      amount: amount,
      currency: currency,
      paymentMethodId: methodId ?? 0,
      paymentMethodName: methodName,
      proofImageUrl: _nullableString(
        map['proof_image_url'] ?? map['proof_url'],
      ),
      status: status,
      submittedAt: _asDate(map['submitted_at'] ?? map['submittedAt']),
    );
  }

  Payment toPayment(Payment request) {
    return Payment(
      id: paymentId.toString(),
      invoiceNumber: quoteId.isNotEmpty ? quoteId : request.invoiceNumber,
      residentName: request.residentName,
      unitLabel: request.unitLabel,
      items: request.items,
      amount: amount,
      date: submittedAt == null
          ? request.date
          : AppDates.format(submittedAt!),
      method: request.method,
      transactionId: request.transactionId,
      status: paymentStatusFromApi(status) ?? PaymentStatus.unknown,
      failureReason: null,
      paymentMethodCode: request.paymentMethodCode,
      paymentMethodName: paymentMethodName.isNotEmpty
          ? paymentMethodName
          : request.paymentMethodName,
      paymentMethodId: paymentMethodId > 0
          ? paymentMethodId
          : request.paymentMethodId,
      proofPath: request.proofPath,
      proofFileName: request.proofFileName,
      proofImageUrl: proofImageUrl,
      paymentNumber: paymentNumber,
      quoteId: quoteId.isNotEmpty ? quoteId : request.quoteId,
      currency: currency.isNotEmpty ? currency : request.currency,
      submittedAt: submittedAt,
      rawStatus: status,
    );
  }

  static Map<String, dynamic>? _payloadMap(Object? json) {
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

  static int? _asInt(Object? value) {
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

  static double _asDouble(Object? value) {
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

  static String _asString(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value == null || value == false) {
      return '';
    }
    return value.toString().trim();
  }

  static String? _nullableString(Object? value) {
    final text = _asString(value);
    return text.isEmpty ? null : text;
  }

  static DateTime? _asDate(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
