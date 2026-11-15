import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/payments/data/models/payment_quote_model.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/invoice_detail.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';
import 'package:test/features/payments/domain/entities/payment_detail.dart';
import 'package:test/features/payments/domain/entities/payment_list.dart';
import 'package:test/features/payments/domain/entities/payment_method_option.dart';
import 'package:test/features/payments/domain/entities/payment_quote.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  group('payment quote model', () {
    test('parses the data envelope and item amounts', () {
      final quote = PaymentQuoteModel.parse(<String, dynamic>{
        'data': <String, dynamic>{
          'quote_id': 'Q-100',
          'invoice_id': 42,
          'total_amount': 175.5,
          'currency': 'MMK',
          'expires_at': '2026-11-15T12:30:00Z',
          'items': <dynamic>[
            <String, dynamic>{'id': 11, 'amount': 100},
            <String, dynamic>{'id': 12, 'amount': 75.5},
          ],
        },
      });

      expect(quote.quoteId, 'Q-100');
      expect(quote.invoiceId, 42);
      expect(quote.totalAmount, 175.5);
      expect(quote.currency, 'MMK');
      expect(quote.expiresAt?.toUtc(), DateTime.utc(2026, 11, 15, 12, 30));
      expect(quote.items.map((item) => item.id), <int>[11, 12]);
      expect(quote.items.last.amount, 75.5);
    });

    test('an unparseable expiry is treated as missing', () {
      final quote = PaymentQuoteModel.parse(<String, dynamic>{
        'data': <String, dynamic>{
          'quote_id': 'Q-101',
          'invoice_id': 42,
          'total_amount': 10,
          'currency': 'MMK',
          'expires_at': 'not-a-date',
          'items': <dynamic>[],
        },
      });

      expect(quote.expiresAt, isNull);
    });
  });

  group('payment quote validation', () {
    test('accepts a fresh quote for the same invoice and fees', () {
      final quote = _quote();

      expect(
        quote.validationError(invoiceId: 42, selectedItemIds: <int>{11, 12}),
        isNull,
      );
    });

    test('rejects an expired quote across time zones', () {
      final quote = _quote(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
      );

      expect(
        quote.validationError(invoiceId: 42, selectedItemIds: <int>{11, 12}),
        contains('expired'),
      );
    });

    test('rejects incomplete or mismatched quotes', () {
      final selected = <int>{11, 12};
      String? error(PaymentQuote quote) =>
          quote.validationError(invoiceId: 42, selectedItemIds: selected);

      expect(error(_quote(quoteId: '')), contains('incomplete'));
      expect(error(_quote(invoiceId: 7)), contains('does not match'));
      expect(error(_quote(totalAmount: 0)), contains('no amount'));
      expect(error(_quote(currency: '')), contains('no currency'));
      expect(error(_quote(noExpiry: true)), contains('no expiry'));
      expect(
        error(_quote(itemIds: const <int>[11])),
        contains('selected fees'),
      );
      expect(
        error(_quote(itemIds: const <int>[11, 12, 13])),
        contains('selected fees'),
      );
      expect(
        error(_quote(itemIds: const <int>[11, 11, 12])),
        contains('selected fees'),
      );
    });
  });

  group('confirm payment quote workflow', () {
    test('prices the selection then submits the quote id and total', () async {
      final repository = _QuoteRepository()..quote = _quote(totalAmount: 175.5);
      final controller = _controller(repository);

      final payment = await controller.confirmPayment(transactionId: 'TX-1');

      expect(payment, isNotNull);
      expect(repository.quoteCalls, 1);
      expect(repository.quoteInvoiceIds.single, 42);
      expect(repository.quoteItemIds.single, <int>[11, 12]);
      expect(repository.submissions, hasLength(1));
      final submitted = repository.submissions.single;
      expect(submitted.quoteId, 'Q-100');
      expect(submitted.amount, 175.5);
      expect(submitted.currency, 'MMK');
      expect(submitted.transactionId, 'TX-1');
      expect(controller.isPaymentProcessing.value, isFalse);
      expect(controller.paymentSuccess.value, isNotNull);
      expect(controller.errorMessage.value, isNull);
    });

    test('an expired quote blocks submission and keeps the form', () async {
      final repository = _QuoteRepository()
        ..quote = _quote(
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        );
      final controller = _controller(repository);

      final payment = await controller.confirmPayment(transactionId: 'TX-1');

      expect(payment, isNull);
      expect(repository.submissions, isEmpty);
      expect(controller.errorMessage.value, contains('expired'));
      expect(controller.isPaymentProcessing.value, isFalse);
      expect(controller.selectedItems, hasLength(2));
      expect(controller.selectedPaymentMethod?.id, 1);
    });

    test('a quote for different fees blocks submission', () async {
      final repository = _QuoteRepository()
        ..quote = _quote(itemIds: const <int>[11]);
      final controller = _controller(repository);

      final payment = await controller.confirmPayment(transactionId: 'TX-1');

      expect(payment, isNull);
      expect(repository.submissions, isEmpty);
      expect(controller.errorMessage.value, contains('selected fees'));
      expect(controller.selectedItems, hasLength(2));
    });

    test(
      'a quote request failure does not submit and is not retried',
      () async {
        final repository = _QuoteRepository()
          ..quoteError = const ApiException(
            'The server took too long to respond. Please try again.',
            kind: ApiFailureKind.timeout,
          );
        final controller = _controller(repository);

        final payment = await controller.confirmPayment(transactionId: 'TX-1');

        expect(payment, isNull);
        expect(repository.quoteCalls, 1);
        expect(repository.submissions, isEmpty);
        expect(controller.errorMessage.value, contains('too long'));
        expect(controller.isPaymentProcessing.value, isFalse);
        expect(controller.selectedItems, hasLength(2));
      },
    );

    test(
      'a payment failure keeps the selection and clears processing',
      () async {
        final repository = _QuoteRepository()
          ..submitError = const AppException('Backend rejected the payment.');
        final controller = _controller(repository);

        final payment = await controller.confirmPayment(transactionId: 'TX-1');

        expect(payment, isNull);
        expect(repository.quoteCalls, 1);
        expect(repository.submitCalls, 1);
        expect(controller.errorMessage.value, 'Backend rejected the payment.');
        expect(controller.paymentSuccess.value, isNull);
        expect(controller.isPaymentProcessing.value, isFalse);
        expect(controller.selectedItems, hasLength(2));
      },
    );

    test('a blank transaction reference is rejected before quoting', () async {
      final repository = _QuoteRepository();
      final controller = _controller(repository);

      final payment = await controller.confirmPayment(transactionId: '   ');

      expect(payment, isNull);
      expect(repository.quoteCalls, 0);
      expect(repository.submitCalls, 0);
      expect(controller.errorMessage.value, contains('transaction reference'));
      expect(controller.isPaymentProcessing.value, isFalse);
      expect(controller.selectedItems, hasLength(2));
    });

    test('a successful submission trims the transaction reference', () async {
      final repository = _QuoteRepository();
      final controller = _controller(repository);

      final payment = await controller.confirmPayment(
        transactionId: '  TX-100  ',
      );

      expect(payment, isNotNull);
      expect(repository.submissions.single.transactionId, 'TX-100');
      expect(controller.paymentSuccess.value?.transactionId, 'TX-100');
      expect(controller.paymentFailure.value, isNull);
    });

    test('a pending verification payment is treated as submitted', () async {
      final repository = _QuoteRepository()
        ..submitStatus = PaymentStatus.pendingVerification;
      final controller = _controller(repository);

      final payment = await controller.confirmPayment(transactionId: 'TX-200');

      expect(payment, isNotNull);
      expect(controller.paymentSuccess.value, isNotNull);
      expect(
        controller.paymentSuccess.value?.status,
        PaymentStatus.pendingVerification,
      );
      expect(controller.paymentFailure.value, isNull);
    });

    test('a second confirm while processing does not quote twice', () async {
      final repository = _QuoteRepository()..quotePending = Completer();
      final controller = _controller(repository);

      final first = controller.confirmPayment(transactionId: 'TX-1');
      final second = await controller.confirmPayment(transactionId: 'TX-1');

      expect(second, isNull);
      expect(repository.quoteCalls, 1);

      repository.quotePending!.complete(_quote());
      await first;
      expect(repository.submissions, hasLength(1));
    });

    test('selected fees without identifiers are never quoted', () async {
      final repository = _QuoteRepository();
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );
      controller.selectInvoice(
        _invoice(
          items: const <InvoiceItem>[
            InvoiceItem(
              type: InvoiceItemType.condoFee,
              amount: 100,
              mustPaid: true,
            ),
          ],
        ),
      );
      controller.paymentMethods.add(_method());
      controller.selectPaymentMethod(_method());

      final payment = await controller.confirmPayment(transactionId: 'TX-1');

      expect(payment, isNull);
      expect(repository.quoteCalls, 0);
      expect(repository.submissions, isEmpty);
      expect(controller.errorMessage.value, contains('cannot be paid'));
    });
  });
}

PaymentController _controller(_QuoteRepository repository) {
  final controller = PaymentController(
    PaymentUseCases(repository),
    sessionController: _sessionFor(1),
  );
  controller.paymentMethods.add(_method());
  controller.selectInvoice(_invoice());
  controller.selectPaymentMethod(_method());
  return controller;
}

PaymentQuote _quote({
  String quoteId = 'Q-100',
  int invoiceId = 42,
  double totalAmount = 150,
  String currency = 'MMK',
  DateTime? expiresAt,
  bool noExpiry = false,
  List<int> itemIds = const <int>[11, 12],
}) {
  return PaymentQuote(
    quoteId: quoteId,
    invoiceId: invoiceId,
    totalAmount: totalAmount,
    currency: currency,
    expiresAt: noExpiry
        ? null
        : (expiresAt ?? DateTime.now().add(const Duration(minutes: 10))),
    items: itemIds
        .map((id) => PaymentQuoteItem(id: id, amount: 10))
        .toList(growable: false),
  );
}

Invoice _invoice({List<InvoiceItem>? items}) {
  return Invoice(
    id: '42',
    number: 'INV-42',
    title: 'Invoice',
    billingPeriod: 'November 2026',
    unitLabel: 'Tower A - 1205',
    dueDate: 'Nov 30, 2026',
    currency: 'MMK',
    status: InvoiceStatus.unpaid,
    items:
        items ??
        const <InvoiceItem>[
          InvoiceItem(
            type: InvoiceItemType.condoFee,
            amount: 100,
            id: 11,
            mustPaid: true,
          ),
          InvoiceItem(
            type: InvoiceItemType.parking,
            amount: 50,
            id: 12,
            mustPaid: true,
          ),
        ],
  );
}

PaymentMethodOption _method() {
  return const PaymentMethodOption(
    id: 1,
    code: 'cash',
    name: 'Cash',
    isActive: true,
    requiresProof: false,
  );
}

SessionController _sessionFor(int userId) {
  final session = SessionController();
  session.setSession(
    AuthUser(
      id: userId,
      name: 'Resident $userId',
      phone: '080000000$userId',
      role: 'owner',
    ),
  );
  return session;
}

class _QuoteRepository implements PaymentRepository {
  PaymentQuote? quote;
  Object? quoteError;
  Object? submitError;
  PaymentStatus submitStatus = PaymentStatus.successful;
  Completer<PaymentQuote>? quotePending;
  int quoteCalls = 0;
  int submitCalls = 0;
  final List<int> quoteInvoiceIds = <int>[];
  final List<List<int>> quoteItemIds = <List<int>>[];
  final List<Payment> submissions = <Payment>[];

  @override
  Future<PaymentQuote> getPaymentQuote({
    required int invoiceId,
    required List<int> selectedItemIds,
  }) {
    quoteCalls++;
    quoteInvoiceIds.add(invoiceId);
    quoteItemIds.add(List<int>.of(selectedItemIds));
    final pending = quotePending;
    if (pending != null) {
      return pending.future;
    }
    final error = quoteError;
    if (error != null) {
      return Future<PaymentQuote>.error(error);
    }
    return Future<PaymentQuote>.value(quote ?? _quote());
  }

  @override
  Future<Payment> submitPayment(Payment payment) {
    submitCalls++;
    final error = submitError;
    if (error != null) {
      return Future<Payment>.error(error);
    }
    submissions.add(payment);
    return Future<Payment>.value(
      Payment(
        id: '1',
        invoiceNumber: payment.invoiceNumber,
        residentName: payment.residentName,
        unitLabel: payment.unitLabel,
        items: payment.items,
        amount: payment.amount,
        date: payment.date,
        method: payment.method,
        status: submitStatus,
        transactionId: payment.transactionId,
        paymentMethodCode: payment.paymentMethodCode,
        paymentMethodName: payment.paymentMethodName,
        proofPath: payment.proofPath,
        proofFileName: payment.proofFileName,
        paymentMethodId: payment.paymentMethodId,
        quoteId: payment.quoteId,
        currency: payment.currency,
      ),
    );
  }

  @override
  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20}) {
    return Future<PaymentListResponse>.value(
      const PaymentListResponse(
        items: <PaymentListItem>[],
        page: 1,
        limit: 20,
        total: 0,
      ),
    );
  }

  @override
  Future<void> cachePaymentList(
    int userId,
    PaymentListResponse response,
  ) async {}

  @override
  Future<void> clearPaymentListCache() async {}

  @override
  Future<void> clearDashboardCache() async {}

  @override
  Future<void> clearInvoiceListCache() async {}

  @override
  Future<PaymentDashboard> getDashboard() async {
    return const PaymentDashboard(
      outstandingBalance: OutstandingBalance(amount: 0, currency: 'MMK'),
      feeSummary: <FeeSummary>[],
      paymentStatistics: PaymentStatistics(
        currentMonthDue: 0,
        lastPayment: 0,
        paidThisYear: 0,
      ),
      invoiceSummary: InvoiceSummary(total: 0, unpaid: 0, partial: 0, paid: 0),
      recentInvoices: <RecentInvoice>[],
      recentPayments: <RecentPayment>[],
    );
  }

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) async => null;

  @override
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) async {}

  @override
  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<InvoiceDetail> getInvoiceDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<CachedInvoiceList?> getCachedInvoiceList(
    int userId,
    String status,
  ) async {
    return null;
  }

  @override
  Future<void> cacheInvoiceList(
    int userId,
    String status,
    InvoiceListResponse response,
  ) async {}

  @override
  Future<PaymentDetail> getPaymentDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentList?> getCachedPaymentList(int userId) async => null;

  @override
  Future<List<PaymentMethodOption>> getPaymentMethods() async {
    return <PaymentMethodOption>[_method()];
  }

  @override
  Future<CachedPaymentMethods?> getCachedPaymentMethods(int userId) async {
    return null;
  }

  @override
  Future<void> cachePaymentMethods(
    int userId,
    List<PaymentMethodOption> methods,
  ) async {}

  @override
  Future<void> clearPaymentMethodsCache() async {}
}
