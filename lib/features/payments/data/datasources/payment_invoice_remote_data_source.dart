import 'package:dio/dio.dart';
import 'package:test/core/utils/super_print.dart';

import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/dio_api_service.dart';
import '../models/invoice_detail_model.dart';
import '../models/invoice_list_model.dart';
import '../models/payment_detail_model.dart';
import '../models/payment_list_model.dart';
import '../models/payment_method_option_model.dart';
import '../models/payment_quote_model.dart';
import '../models/payment_submission_response_model.dart';
import '../../domain/entities/payment.dart';

class PaymentInvoiceRemoteDataSource {
  const PaymentInvoiceRemoteDataSource(this._service);

  final DioApiService _service;

  Future<PaymentQuoteModel> createQuote({
    required int invoiceId,
    required List<int> selectedItemIds,
  }) {
    return _service.post<PaymentQuoteModel>(
      ApiEndPoints.paymentQuote,
      data: <String, dynamic>{
        'invoice_id': invoiceId,
        'selected_item_ids': selectedItemIds,
      },
      parse: PaymentQuoteModel.parse,
    );
  }

  Future<PaymentSubmissionResponseModel> submitPayment(Payment payment) async {
    final quoteId = payment.quoteId?.trim() ?? '';
    if (quoteId.isEmpty) {
      throw StateError('A payment quote is required to submit a payment.');
    }
    final transactionReference = payment.transactionId.trim();
    if (transactionReference.isEmpty) {
      throw StateError(
        'A transaction reference is required to submit a payment.',
      );
    }
    // final selectedItemIds = payment.items
    //     .map((item) => item.id)
    //     .whereType<int>()
    //     .toList();

    final fields = <String, dynamic>{
      'quote_id': quoteId,
      'payment_method_id': payment.paymentMethodId,
     // 'selected_item_ids': selectedItemIds,
      'transaction_reference': transactionReference,
    };
    superPrint(fields, title: "Request");

    final files = <String, MultipartFile>{};
    if (payment.proofPath != null && payment.proofPath!.trim().isNotEmpty) {
      files['proof_image'] = DioApiService.filePart(
        filePath: payment.proofPath!,
        filename: payment.proofFileName,
      );
    }

    return _service.uploadMultipart<PaymentSubmissionResponseModel>(
      ApiEndPoints.payments,
      fields: fields,
      files: files,
      parse: PaymentSubmissionResponseModel.parse,
    );
  }

  Future<List<PaymentMethodOptionModel>> getPaymentMethods() async {
    final response = await _service.get<dynamic>(ApiEndPoints.paymentMethods);
    return PaymentMethodOptionModel.parseList(response);
  }

  Future<PaymentListResponseModel> getPayments({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _service.get<dynamic>(
      ApiEndPoints.payments,
      query: <String, dynamic>{'page': page, 'limit': limit},
    );
    if (response is! Map && response is! List) {
      throw const FormatException('Unexpected payment list response.');
    }
    return PaymentListResponseModel.parse(response);
  }

  Future<PaymentDetailModel> getPayment(int id) async {
    final response = await _service.get<dynamic>(
      ApiEndPoints.paymentDetail(id),
    );
    if (_responseMap(response) == null) {
      throw const FormatException('Unexpected payment detail response.');
    }
    return PaymentDetailModel.parse(response);
  }

  Future<InvoiceListResponseModel> getInvoices({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) async {
    final response = await _service.get<dynamic>(
      ApiEndPoints.invoices,
      query: <String, dynamic>{'page': page, 'limit': limit, 'status': status},
    );
    final map = _responseMap(response);
    if (map == null || map['items'] is! List) {
      throw const FormatException('Unexpected invoice list response.');
    }
    return InvoiceListResponseModel.fromJson(map);
  }

  Future<InvoiceDetailModel> getInvoice(int id) async {
    final response = await _service.get<dynamic>(
      ApiEndPoints.invoiceDetail(id),
    );
    if (_responseMap(response) == null) {
      throw const FormatException('Unexpected invoice detail response.');
    }
    return InvoiceDetailModel.parse(response);
  }

  static Map<String, dynamic>? _responseMap(Object? response) {
    if (response is! Map) {
      return null;
    }
    var map = Map<String, dynamic>.from(response);
    final nested = map['data'] ?? map['result'];
    if (nested is Map) {
      map = Map<String, dynamic>.from(nested);
    }
    return map;
  }
}
