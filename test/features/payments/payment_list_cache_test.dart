import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/app/routes/app_routes.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/network/api_end_points.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/in_memory_token_storage.dart';
import 'package:test/core/utils/app_formatters.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/payments/data/datasources/payment_invoice_remote_data_source.dart';
import 'package:test/features/payments/data/datasources/payment_list_local_data_source.dart';
import 'package:test/features/payments/data/models/payment_detail_model.dart';
import 'package:test/features/payments/data/models/payment_list_model.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/invoice_detail.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';
import 'package:test/features/payments/domain/entities/payment_detail.dart';
import 'package:test/features/payments/domain/entities/payment_list.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/payments/presentation/pages/payment_details_page.dart';
import 'package:test/features/payments/presentation/pages/payment_history_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  group('payment amount formatting', () {
    test('formats MMK and USD like the API examples', () {
      expect(AppFormatters.money(1500000, 'MMK'), '1,500,000 Ks');
      expect(AppFormatters.money(1500, 'USD'), r'$1,500.00');
      expect(AppFormatters.money(-1500, 'USD'), r'-$1,500.00');
    });
  });

  group('payment list parsing', () {
    test('parses wrapped payments, pagination and statuses', () {
      final response = PaymentListResponseModel.parse(<String, dynamic>{
        'data': <String, dynamic>{
          'payments': <dynamic>[
            <String, dynamic>{
              'id': 501,
              'payment_number': 'PAY-2026-501',
              'invoice_number': 'INV-2026-011',
              'amount': '422.40',
              'currency': 'USD',
              'payment_method': 'bank_transfer',
              'transaction_reference': 'TXN-501',
              'status': 'paid',
              'paid_at': '2026-09-25T10:30:00Z',
            },
            <String, dynamic>{
              'id': '502',
              'payment_number': 'PAY-2026-502',
              'invoice': <String, dynamic>{'invoice_number': 'INV-2026-012'},
              'total_amount': 100,
              'currency': 'MMK',
              'method': 'kbz_pay',
              'status': 'mystery-status',
            },
          ],
          'pagination': <String, dynamic>{
            'current_page': '1',
            'per_page': '20',
            'total': '2',
          },
        },
      });

      expect(response.items, hasLength(2));
      expect(response.page, 1);
      expect(response.limit, 20);
      expect(response.total, 2);

      final first = response.items.first;
      expect(first.id, 501);
      expect(first.amount, 422.40);
      expect(first.paymentStatus, PaymentStatus.successful);
      expect(first.paymentMethodLabel, 'Bank Transfer');
      expect(first.paidAt, isNotNull);

      final second = response.items[1];
      expect(second.id, 502);
      expect(second.invoiceNumber, 'INV-2026-012');
      expect(second.paymentStatus, isNull);
      expect(second.statusLabel, 'Mystery status');
      expect(second.paymentMethodLabel, 'KBZ Pay');
    });

    test('missing optional fields fall back without throwing', () {
      final item = PaymentListItemModel.fromJson(<String, dynamic>{
        'payment_number': null,
        'amount': 'not-a-number',
        'paid_at': 'not-a-date',
      });

      expect(item.id, 0);
      expect(item.paymentNumber, '');
      expect(item.amount, 0);
      expect(item.paidAt, isNull);
      expect(item.hasValidId, isFalse);
    });
  });

  group('payment detail parsing', () {
    test('parses receipt and nested payment payload', () {
      final detail = PaymentDetailModel.parse(<String, dynamic>{
        'data': <String, dynamic>{
          'payment': <String, dynamic>{
            'id': 501,
            'payment_number': 'PAY-2026-501',
            'invoice_number': 'INV-2026-011',
            'amount': 422.40,
            'currency': 'USD',
            'payment_method': 'card',
            'transaction_reference': 'TXN-501',
            'status': 'completed',
            'paid_at': '2026-09-25T10:30:00Z',
            'receipt': <String, dynamic>{
              'receipt_number': 'RCT-501',
              'download_url': 'https://example.com/receipts/501.pdf',
            },
          },
        },
      });

      expect(detail.id, 501);
      expect(detail.paymentStatus, PaymentStatus.successful);
      expect(detail.paymentMethodLabel, 'Credit / Debit Card');
      expect(detail.hasReceipt, isTrue);
      expect(detail.receipt?.receiptNumber, 'RCT-501');
      expect(detail.receipt?.hasDownloadUrl, isTrue);
    });

    test('receipt falls back to top-level fields', () {
      final detail = PaymentDetailModel.fromJson(<String, dynamic>{
        'id': 501,
        'receipt_number': 'RCT-501',
        'receipt_url': 'https://example.com/receipts/501.pdf',
      });

      expect(detail.receipt?.receiptNumber, 'RCT-501');
      expect(detail.receipt?.downloadUrl, contains('501.pdf'));
    });

    test('a null receipt is treated as missing', () {
      final detail = PaymentDetailModel.fromJson(<String, dynamic>{
        'id': 501,
        'receipt': null,
      });

      expect(detail.receipt, isNull);
      expect(detail.hasReceipt, isFalse);
    });
  });

  group('payment API', () {
    test('requests the paginated list and parses the response', () async {
      final captured = _CapturedRequest();
      final remote = _remote(
        captured,
        body: <String, dynamic>{
          'data': <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 501,
                'payment_number': 'PAY-2026-010',
                'invoice_number': 'INV-2026-011',
                'amount': 242.40,
                'currency': 'USD',
                'payment_method': 'kbz_pay',
                'transaction_reference': 'TXN-123456',
                'status': 'paid',
                'paid_at': '2026-11-09T08:45:00Z',
              },
            ],
            'page': 1,
            'limit': 20,
            'total': 1,
          },
        },
      );

      final response = await remote.getPayments(page: 1, limit: 20);

      expect(captured.path, ApiEndPoints.payments);
      expect(captured.path, '/payments');
      expect(
        captured.uri.toString(),
        'https://api.example.com/api/v1/payments?page=1&limit=20',
      );
      expect(response.items, hasLength(1));
      expect(response.items.single.id, 501);
      expect(response.items.single.paymentNumber, 'PAY-2026-010');
      expect(response.items.single.amount, 242.40);
      expect(response.page, 1);
      expect(response.limit, 20);
      expect(response.total, 1);
    });

    test('requests one payment by id and parses its receipt', () async {
      final captured = _CapturedRequest();
      final remote = _remote(
        captured,
        body: <String, dynamic>{
          'id': 501,
          'payment_number': 'PAY-2026-010',
          'invoice_id': 101,
          'invoice_number': 'INV-2026-011',
          'amount': 242.40,
          'currency': 'USD',
          'payment_method': 'kbz_pay',
          'transaction_reference': 'TXN-123456',
          'status': 'paid',
          'paid_at': '2026-11-09T08:45:00Z',
          'receipt': <String, dynamic>{
            'receipt_number': 'RCP-2026-010',
            'download_url': 'https://example.com/receipts/501.pdf',
          },
        },
      );

      final detail = await remote.getPayment(501);

      expect(captured.path, '/payments/501');
      expect(
        captured.uri.toString(),
        'https://api.example.com/api/v1/payments/501',
      );
      expect(detail.id, 501);
      expect(detail.paymentNumber, 'PAY-2026-010');
      expect(detail.invoiceNumber, 'INV-2026-011');
      expect(detail.amount, 242.40);
      expect(detail.currency, 'USD');
      expect(detail.paymentMethodLabel, 'KBZ Pay');
      expect(detail.transactionReference, 'TXN-123456');
      expect(detail.status, 'paid');
      expect(detail.receipt?.receiptNumber, 'RCP-2026-010');
      expect(detail.receipt?.hasDownloadUrl, isTrue);
    });
  });

  group('payment list cache', () {
    test('keeps only the latest twenty first-page rows', () async {
      final cache = _FakeCache();
      final local = PaymentListLocalDataSource(
        cache: cache,
        accountKey: () => 'user:1',
      );

      await local.save(1, _page(page: 1, startId: 100, count: 25));
      final cached = await local.read(1);

      expect(cached, isNotNull);
      expect(cached!.response.items, hasLength(20));
      expect(
        cached.response.items.map((item) => item.id).toList(),
        List<int>.generate(20, (index) => 100 + index),
      );

      await local.save(1, _page(page: 2, startId: 200, count: 20));
      final afterOlderPage = await local.read(1);
      expect(afterOlderPage!.response.items, hasLength(20));
      expect(afterOlderPage.response.items.first.id, 100);
    });

    test('scopes entries by resident and account key', () async {
      final cache = _FakeCache();
      var account = 'user:1';
      final local = PaymentListLocalDataSource(
        cache: cache,
        accountKey: () => account,
      );

      await local.save(1, _page(page: 1, startId: 100, count: 20));

      expect(await local.read(2), isNull);

      account = 'user:2';
      expect(await local.read(1), isNull);

      account = 'user:1';
      expect((await local.read(1))!.response.items.first.id, 100);
    });

    test('a valid empty response replaces the cached snapshot', () async {
      final cache = _FakeCache();
      final local = PaymentListLocalDataSource(
        cache: cache,
        accountKey: () => 'user:1',
      );

      await local.save(1, _page(page: 1, startId: 100, count: 10));
      await local.save(1, _page(page: 1, startId: 0, count: 0));

      final cached = await local.read(1);
      expect(cached, isNotNull);
      expect(cached!.response.items, isEmpty);
    });
  });

  group('payment controller', () {
    test('shows cached payments when the first page fails', () async {
      final repository = _PaymentRepository()
        ..cached = CachedPaymentList(
          response: _page(page: 1, startId: 100, count: 10),
          updatedAt: DateTime(2026, 9, 1),
        )
        ..error = const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPaymentList();

      expect(controller.paymentList, hasLength(10));
      expect(controller.paymentList.first.id, 100);
      expect(controller.isShowingCachedPayments.value, isTrue);
      expect(controller.paymentListError.value, isNull);
      expect(repository.cacheWrites, isEmpty);
    });

    test('caches only after a successful first page', () async {
      final repository = _PaymentRepository()
        ..fresh = _page(page: 1, startId: 500, count: 20);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPaymentList();

      expect(controller.paymentList, hasLength(20));
      expect(controller.isShowingCachedPayments.value, isFalse);
      expect(repository.cacheWrites, hasLength(1));
      expect(repository.cacheWrites.single.userId, 1);
      expect(repository.cacheWrites.single.response.items, hasLength(20));
    });

    test('concurrent first-page loads share one request', () async {
      final repository = _PaymentRepository()..manualResponses = true;
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      final first = controller.loadPaymentList();
      final second = controller.loadPaymentList();
      await _waitForRequests(repository, 1);

      expect(repository.listCalls, 1);

      repository.requests[0].complete(_page(page: 1, startId: 100, count: 2));
      await Future.wait(<Future<void>>[first, second]);

      expect(controller.paymentList, hasLength(2));
      expect(controller.paymentList.first.id, 100);
    });

    test('load more shares one request and stops at the last page', () async {
      final repository = _PaymentRepository()
        ..fresh = _page(page: 1, startId: 0, count: 20, total: 40);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPaymentList();
      expect(controller.hasMorePayments, isTrue);

      repository.manualResponses = true;
      final first = controller.loadMorePayments();
      final second = controller.loadMorePayments();
      await _waitForRequests(repository, 1);

      expect(repository.listCalls, 2);
      expect(repository.requestedPages, <int>[1, 2]);

      repository.requests[0].complete(
        _page(page: 2, startId: 20, count: 20, total: 40),
      );
      await Future.wait(<Future<void>>[first, second]);

      expect(controller.paymentList, hasLength(40));
      expect(controller.hasMorePayments, isFalse);
      expect(repository.cacheWrites, hasLength(1));

      await controller.loadMorePayments();

      expect(repository.requests, hasLength(1));
      expect(repository.listCalls, 2);
      expect(repository.cacheWrites, hasLength(1));
    });

    test('an empty older page stops pagination', () async {
      final repository = _PaymentRepository()
        ..fresh = _page(page: 1, startId: 0, count: 20, total: 40);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPaymentList();
      expect(controller.hasMorePayments, isTrue);

      repository.manualResponses = true;
      final more = controller.loadMorePayments();
      await _waitForRequests(repository, 1);
      repository.requests[0].complete(
        _page(page: 2, startId: 0, count: 0, total: 40),
      );
      await more;

      expect(controller.hasMorePayments, isFalse);
      expect(controller.paymentList, hasLength(20));

      final calls = repository.listCalls;
      await controller.loadMorePayments();

      expect(repository.listCalls, calls);
      expect(repository.requests, hasLength(1));
    });

    test(
      'detail is fetched fresh and never written through the cache',
      () async {
        final repository = _PaymentRepository()
          ..detail = const PaymentDetail(
            id: 501,
            paymentNumber: 'PAY-2026-501',
            invoiceNumber: 'INV-2026-011',
            amount: 422.40,
            currency: 'USD',
            paymentMethod: 'card',
            transactionReference: 'TXN-501',
            status: 'paid',
            receipt: PaymentReceiptInfo(
              receiptNumber: 'RCT-501',
              downloadUrl: 'https://example.com/receipts/501.pdf',
            ),
          );
        final controller = PaymentController(
          PaymentUseCases(repository),
          sessionController: _sessionFor(1),
        )..onInit();

        await controller.loadPaymentDetail(501);

        expect(controller.paymentDetail.value?.paymentNumber, 'PAY-2026-501');
        expect(repository.cacheWrites, isEmpty);
        expect(repository.detailCalls, 1);
      },
    );

    test('an invalid payment id never reaches the API', () async {
      final repository = _PaymentRepository();
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPaymentDetail(0);

      expect(repository.detailCalls, 0);
      expect(controller.paymentDetail.value, isNull);
    });

    test('an older resident response cannot replace the new one', () async {
      final repository = _PaymentRepository()..manualResponses = true;
      final session = SessionController();
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: session,
      )..onInit();

      session.setSession(_user(1));
      final first = controller.loadPaymentList();
      await _waitForRequests(repository, 1);

      session.setSession(_user(2));
      final second = controller.loadPaymentList();
      await _waitForRequests(repository, 2);

      repository.requests[1].complete(_page(page: 1, startId: 900, count: 2));
      await second;
      expect(controller.paymentList.first.id, 900);

      repository.requests[0].complete(_page(page: 1, startId: 100, count: 2));
      await first;

      expect(controller.paymentList.first.id, 900);
      expect(repository.cacheWrites.map((write) => write.userId), <int>[2]);
    });
  });

  group('payment pages', () {
    setUp(() {
      Get.testMode = true;
    });

    tearDown(Get.reset);

    testWidgets('history page renders API payments', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _PaymentRepository()
        ..fresh = _page(page: 1, startId: 700, count: 2);
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );
      Get.put(controller);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => const MaterialApp(home: PaymentHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PAY-700-0'), findsOneWidget);
      expect(find.text('INV-700-0'), findsOneWidget);
      expect(find.byKey(const Key('payment-history-scroll')), findsOneWidget);
    });

    testWidgets('detail page renders API payment details', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _PaymentRepository()
        ..detail = const PaymentDetail(
          id: 501,
          paymentNumber: 'PAY-2026-501',
          invoiceNumber: 'INV-2026-011',
          amount: 422.40,
          currency: 'USD',
          paymentMethod: 'card',
          transactionReference: 'TXN-501',
          status: 'paid',
          receipt: PaymentReceiptInfo(
            receiptNumber: 'RCT-501',
            downloadUrl: 'https://example.com/receipts/501.pdf',
          ),
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );
      Get.put(controller);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              const MaterialApp(home: PaymentDetailsPage(paymentId: 501)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PAY-2026-501'), findsWidgets);
      expect(find.text('INV-2026-011'), findsOneWidget);
      expect(find.text('RCT-501'), findsOneWidget);
      expect(find.byKey(const Key('payment-receipt-download')), findsOneWidget);
    });

    testWidgets('tapping a payment opens details with the selected id', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _PaymentRepository()
        ..fresh = _page(page: 1, startId: 700, count: 2)
        ..detail = const PaymentDetail(
          id: 700,
          paymentNumber: 'PAY-2026-700',
          invoiceNumber: 'INV-2026-700',
          amount: 100,
          currency: 'USD',
          paymentMethod: 'card',
          transactionReference: 'TXN-700',
          status: 'paid',
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );
      Get.put(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.paymentHistory,
          getPages: <GetPage<dynamic>>[
            GetPage<dynamic>(
              name: AppRoutes.paymentHistory,
              page: () => const PaymentHistoryPage(),
            ),
            GetPage<dynamic>(
              name: AppRoutes.paymentDetails,
              page: () => PaymentDetailsPage(paymentId: Get.arguments as int),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('PAY-700-0'));
      await tester.pumpAndSettle();

      expect(repository.detailCalls, 1);
      expect(controller.paymentDetailId.value, 700);
      expect(controller.paymentDetail.value?.id, 700);
      expect(find.text('PAY-2026-700'), findsWidgets);
      expect(find.text('INV-2026-700'), findsOneWidget);
    });

    testWidgets('detail page explains when the receipt is missing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _PaymentRepository()
        ..detail = const PaymentDetail(
          id: 501,
          paymentNumber: 'PAY-2026-501',
          invoiceNumber: 'INV-2026-011',
          amount: 100,
          currency: 'USD',
          paymentMethod: 'card',
          transactionReference: 'TXN-501',
          status: 'paid',
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );
      Get.put(controller);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              const MaterialApp(home: PaymentDetailsPage(paymentId: 501)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No receipt is available for this payment.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('payment-receipt-download')), findsNothing);
    });
  });
}

typedef _ResponseHandler = FutureOr<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handle);

  final _ResponseHandler handle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => await handle(options, requestStream);

  @override
  void close({bool force = false}) {}
}

class _CapturedRequest {
  String? path;
  Uri? uri;
  Map<String, dynamic>? query;
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

PaymentInvoiceRemoteDataSource _remote(
  _CapturedRequest captured, {
  required Object body,
}) {
  final dio = Dio()
    ..httpClientAdapter = _FakeAdapter((options, _) async {
      captured.path = options.path;
      captured.uri = options.uri;
      captured.query = options.queryParameters;
      return _json(200, body);
    });
  return PaymentInvoiceRemoteDataSource(
    DioApiService(
      dio: dio,
      tokenStorage: InMemoryTokenStorage(),
      baseUrl: 'https://api.example.com/api/v1',
    ),
  );
}

PaymentListResponse _page({
  required int page,
  required int startId,
  required int count,
  int? total,
}) {
  return PaymentListResponse(
    items: List<PaymentListItem>.generate(
      count,
      (index) => PaymentListItem(
        id: startId + index,
        paymentNumber: 'PAY-$startId-$index',
        invoiceNumber: 'INV-$startId-$index',
        amount: 100,
        currency: 'USD',
        paymentMethod: 'card',
        transactionReference: 'TXN-$startId-$index',
        status: 'paid',
      ),
    ),
    page: page,
    limit: 20,
    total: total ?? count,
  );
}

SessionController _sessionFor(int userId) {
  final session = SessionController();
  session.setSession(_user(userId));
  return session;
}

AuthUser _user(int id) {
  return AuthUser(
    id: id,
    name: 'Resident $id',
    phone: '080000000$id',
    role: 'owner',
  );
}

Future<void> _waitForRequests(_PaymentRepository repository, int count) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (repository.requests.length >= count) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected $count payment requests, got ${repository.requests.length}.');
}

class _FakeCache extends ApiCacheStore {
  static final AppCacheDatabase _database = AppCacheDatabase();

  _FakeCache() : super(_database);

  final entries = <String, CachedApiEntry>{};

  @override
  Future<CachedApiEntry?> read(String key) async => entries[key];

  @override
  Future<void> save({
    required String key,
    String? accountKey,
    required Object payload,
  }) async {
    entries[key] = CachedApiEntry(
      key: key,
      accountKey: accountKey,
      payloadJson: jsonEncode(payload),
      updatedAt: DateTime(2026, 9, 25),
    );
  }

  @override
  Future<void> invalidate(String key) async {
    entries.remove(key);
  }

  @override
  Future<void> invalidatePrefix(String prefix) async {
    entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clearAll() async => entries.clear();
}

class _CacheWrite {
  const _CacheWrite(this.userId, this.response);

  final int userId;
  final PaymentListResponse response;
}

class _PaymentRepository implements PaymentRepository {
  CachedPaymentList? cached;
  PaymentListResponse fresh = _page(page: 1, startId: 0, count: 0);
  PaymentDetail? detail;
  Object? error;
  bool manualResponses = false;
  int listCalls = 0;
  int detailCalls = 0;

  final pages = <int, PaymentListResponse>{};
  final requestedPages = <int>[];
  final requests = <Completer<PaymentListResponse>>[];
  final cacheWrites = <_CacheWrite>[];

  @override
  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20}) {
    listCalls++;
    requestedPages.add(page);
    if (manualResponses) {
      final completer = Completer<PaymentListResponse>();
      requests.add(completer);
      return completer.future;
    }
    if (error != null) {
      return Future<PaymentListResponse>.error(error!);
    }
    return Future<PaymentListResponse>.value(pages[page] ?? fresh);
  }

  @override
  Future<PaymentDetail> getPaymentDetail(int id) async {
    detailCalls++;
    final value = detail;
    if (value == null) {
      throw StateError('No payment detail configured.');
    }
    return value;
  }

  @override
  Future<CachedPaymentList?> getCachedPaymentList(int userId) async => cached;

  @override
  Future<void> cachePaymentList(
    int userId,
    PaymentListResponse response,
  ) async {
    cacheWrites.add(_CacheWrite(userId, response));
  }

  @override
  Future<void> clearPaymentListCache() async {}

  @override
  Future<PaymentDashboard> getDashboard() {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) async => null;

  @override
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) async {}

  @override
  Future<void> clearDashboardCache() async {}

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
  Future<void> clearInvoiceListCache() async {}

  @override
  Future<List<Invoice>> getInvoices() async => const <Invoice>[];

  @override
  Future<Invoice?> getInvoice(String id) async => null;

  @override
  Future<List<Payment>> getPaymentHistory() async => const <Payment>[];

  @override
  Future<Payment> submitPayment(Payment payment) async => payment;

  @override
  Future<List<Invoice>> applyRole(String roleKey) async => const <Invoice>[];

  @override
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  }) {
    throw UnimplementedError();
  }
}
