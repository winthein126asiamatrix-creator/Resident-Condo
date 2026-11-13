import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/connectivity_service.dart';
import 'package:test/features/payments/data/datasources/payment_methods_local_data_source.dart';
import 'package:test/features/payments/data/models/payment_method_option_model.dart';
import 'package:test/features/payments/domain/entities/invoice.dart';
import 'package:test/features/payments/domain/entities/invoice_list.dart';
import 'package:test/features/payments/domain/entities/invoice_detail.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/payments/domain/entities/payment.dart';
import 'package:test/features/payments/domain/entities/payment_dashboard.dart';
import 'package:test/features/payments/domain/entities/payment_detail.dart';
import 'package:test/features/payments/domain/entities/payment_list.dart';
import 'package:test/features/payments/domain/entities/payment_method_option.dart';
import 'package:test/features/payments/domain/repositories/payment_repository.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/payments/presentation/pages/payment_method_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  group('payment method model', () {
    test('parses a full response', () {
      final methods = PaymentMethodOptionModel.parseList(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 1,
            'code': 'kbz_pay',
            'name': 'KBZ Pay',
            'account_name': 'ABC Condo',
            'account_number': '09XXXXXXXXX',
            'bank_name': null,
            'qr_image_url': 'https://example.com/qr/kbz.png',
            'instructions': 'Transfer the exact amount to this account.',
            'currency': 'MMK',
            'is_active': true,
            'requires_proof': true,
          },
          <String, dynamic>{
            'id': 2,
            'code': 'bank_transfer',
            'name': 'Bank Transfer',
            'account_name': 'ABC Condo',
            'account_number': '123456789',
            'bank_name': 'KBZ Bank',
            'qr_image_url': null,
            'instructions': 'Please upload your transfer receipt.',
            'currency': 'MMK',
            'is_active': true,
            'requires_proof': true,
          },
        ],
      });

      expect(methods.length, 2);
      expect(methods.first.id, 1);
      expect(methods.first.code, 'kbz_pay');
      expect(methods.first.displayName, 'KBZ Pay');
      expect(methods.first.accountName, 'ABC Condo');
      expect(methods.first.accountNumber, '09XXXXXXXXX');
      expect(methods.first.hasQrImage, isTrue);
      expect(methods.first.requiresProof, isTrue);
      expect(methods.last.bankName, 'KBZ Bank');
      expect(methods.last.qrImageUrl, '');
      expect(methods.last.hasBankDetails, isTrue);
    });

    test('supports bare lists and nested wrappers', () {
      final fromList = PaymentMethodOptionModel.parseList(<dynamic>[
        <String, dynamic>{
          'id': 3,
          'code': 'cash',
          'name': 'Cash',
          'is_active': true,
          'requires_proof': false,
        },
      ]);
      final fromNested = PaymentMethodOptionModel.parseList(<String, dynamic>{
        'data': <String, dynamic>{
          'result': <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 4,
                'code': 'wallet',
                'name': 'Wallet',
                'is_active': false,
                'requires_proof': false,
              },
            ],
          },
        },
      });

      expect(fromList.single.id, 3);
      expect(fromNested.single.isActive, isFalse);
    });

    test('skips entries with malformed booleans', () {
      final methods = PaymentMethodOptionModel.parseList(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 1,
            'code': 'bad',
            'name': 'Bad',
            'is_active': 'true',
            'requires_proof': false,
          },
          <String, dynamic>{
            'id': 2,
            'code': 'good',
            'name': 'Good',
            'is_active': true,
            'requires_proof': false,
          },
        ],
      });

      expect(methods.length, 1);
      expect(methods.single.code, 'good');
    });
  });

  group('payment methods cache', () {
    test('round-trips and stays scoped to the resident', () async {
      final cache = _FakeCache();
      var account = 'user:1';
      final local = PaymentMethodsLocalDataSource(
        cache: cache,
        accountKey: () => account,
      );
      final method = _method(id: 1, code: 'kbz_pay', name: 'KBZ Pay');

      await local.save(1, <PaymentMethodOption>[method]);
      final cached = await local.read(1);

      expect(cached?.methods.single.code, 'kbz_pay');
      expect(cached?.updatedAt, isNotNull);

      account = 'user:2';
      expect(await local.read(1), isNull);

      await local.save(2, <PaymentMethodOption>[_method(id: 2, code: 'cash')]);
      expect((await local.read(2))?.methods.single.code, 'cash');

      account = 'user:1';
      expect((await local.read(1))?.methods.single.code, 'kbz_pay');

      await local.clear();
      expect(await local.read(1), isNull);
    });
  });

  group('payment methods controller', () {
    test('shows cached methods when the API is unreachable', () async {
      final repository = _FakeRepository()
        ..cached = CachedPaymentMethods(
          methods: <PaymentMethodOption>[_method(id: 1, code: 'kbz_pay')],
          updatedAt: DateTime(2026, 9, 1),
        )
        ..methodsError = const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPaymentMethods();

      expect(controller.paymentMethods.single.code, 'kbz_pay');
      expect(controller.isShowingCachedPaymentMethods.value, isTrue);
      expect(controller.paymentMethodsError.value, isNull);
      expect(repository.cacheWrites, isEmpty);
    });

    test('a successful refresh replaces the cache', () async {
      final repository = _FakeRepository()
        ..cached = CachedPaymentMethods(
          methods: <PaymentMethodOption>[_method(id: 1, code: 'kbz_pay')],
          updatedAt: DateTime(2026, 9, 1),
        )
        ..methods = <PaymentMethodOption>[_method(id: 2, code: 'cash')];
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      await controller.loadPaymentMethods();

      expect(controller.paymentMethods.single.code, 'cash');
      expect(controller.isShowingCachedPaymentMethods.value, isFalse);
      expect(repository.cacheWrites[1]?.single.code, 'cash');
    });

    test('offline cached methods stay selectable', () async {
      final repository = _FakeRepository()
        ..cached = CachedPaymentMethods(
          methods: <PaymentMethodOption>[
            _method(id: 1, code: 'kbz_pay', requiresProof: true),
          ],
          updatedAt: DateTime(2026, 9, 1),
        );
      final connectivity = ConnectivityService()..isOnline.value = false;
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
        connectivity: connectivity,
      )..onInit();

      await controller.loadPaymentMethods();

      expect(controller.paymentMethods.single.code, 'kbz_pay');
      expect(controller.selectedPaymentMethod?.code, 'kbz_pay');
      expect(controller.isShowingCachedPaymentMethods.value, isTrue);
    });

    test('defaults to the first active method', () async {
      final repository = _FakeRepository()
        ..methods = <PaymentMethodOption>[
          _method(id: 1, code: 'inactive', isActive: false),
          _method(id: 2, code: 'cash'),
        ];
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );

      await controller.loadPaymentMethods();

      expect(controller.selectedPaymentMethod?.code, 'cash');
    });

    test('inactive methods cannot be selected', () async {
      final repository = _FakeRepository()
        ..methods = <PaymentMethodOption>[
          _method(id: 1, code: 'cash'),
          _method(id: 2, code: 'disabled', isActive: false),
        ];
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      );

      await controller.loadPaymentMethods();
      controller.selectPaymentMethod(
        _method(id: 2, code: 'disabled', isActive: false),
      );

      expect(controller.selectedPaymentMethod?.code, 'cash');
    });

    test('refreshing removes a selected method and falls back', () async {
      final repository = _FakeRepository()
        ..manualResponses = true
        ..methods = <PaymentMethodOption>[_method(id: 1, code: 'cash')];
      final controller = PaymentController(
        PaymentUseCases(repository),
        sessionController: _sessionFor(1),
      )..onInit();

      final initial = controller.loadPaymentMethods();
      await _waitForPaymentMethods(repository, 1);
      repository.requests.single.complete(<PaymentMethodOption>[
        _method(id: 1, code: 'cash'),
      ]);
      await initial;
      expect(controller.selectedPaymentMethod?.code, 'cash');

      final refresh = controller.loadPaymentMethods(refresh: true);
      await _waitForPaymentMethods(repository, 2);
      repository.requests.last.complete(<PaymentMethodOption>[
        _method(id: 2, code: 'wallet'),
      ]);
      await refresh;

      expect(controller.paymentMethods.single.code, 'wallet');
      expect(controller.selectedPaymentMethod?.code, 'wallet');
    });
  });

  testWidgets('payment method page renders dynamic methods', (tester) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRepository()
      ..invoices = <Invoice>[_invoice()]
      ..methods = <PaymentMethodOption>[
        _method(
          id: 1,
          code: 'kbz_pay',
          name: 'KBZ Pay',
          requiresProof: false,
          qrImageUrl: 'https://example.com/qr/kbz.png',
        ),
        _method(
          id: 2,
          code: 'bank_transfer',
          name: 'Bank Transfer',
          bankName: 'KBZ Bank',
          requiresProof: true,
          accountName: 'ABC Condo',
          accountNumber: '123456789',
          instructions: 'Please upload your transfer receipt.',
        ),
      ];
    final controller = PaymentController(
      PaymentUseCases(repository),
      sessionController: _sessionFor(1),
    );
    controller.selectInvoice(_invoice());
    Get.put(controller);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(home: PaymentMethodPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bank Transfer'));
    await tester.pumpAndSettle();

    expect(find.text('KBZ Pay'), findsOneWidget);
    expect(find.text('Bank Transfer'), findsWidgets);
    expect(find.text('KBZ Bank'), findsOneWidget);
    expect(find.text('ABC Condo'), findsOneWidget);
    expect(find.text('123456789'), findsOneWidget);
    expect(find.text('Please upload your transfer receipt.'), findsOneWidget);
  });

  testWidgets('proof is required before confirmation', (tester) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRepository()
      ..invoices = <Invoice>[_invoice()]
      ..methods = <PaymentMethodOption>[
        _method(id: 1, code: 'cash', requiresProof: true),
      ];
    final controller = PaymentController(
      PaymentUseCases(repository),
      sessionController: _sessionFor(1),
    );
    controller.selectInvoice(_invoice());
    Get.put(controller);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(home: PaymentMethodPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-payment')));
    await tester.pumpAndSettle();

    expect(find.text('Attach proof of payment to continue.'), findsOneWidget);
  });
}

PaymentMethodOption _method({
  required int id,
  required String code,
  String name = '',
  String accountName = '',
  String accountNumber = '',
  String bankName = '',
  String qrImageUrl = '',
  String instructions = '',
  String currency = 'MMK',
  bool isActive = true,
  bool requiresProof = false,
}) {
  return PaymentMethodOption(
    id: id,
    code: code,
    name: name.isEmpty ? code : name,
    accountName: accountName,
    accountNumber: accountNumber,
    bankName: bankName,
    qrImageUrl: qrImageUrl,
    instructions: instructions,
    currency: currency,
    isActive: isActive,
    requiresProof: requiresProof,
  );
}

Invoice _invoice() {
  return Invoice(
    id: 'invoice-1',
    number: 'INV-1',
    title: 'Invoice',
    billingPeriod: 'September 2026',
    unitLabel: 'Tower A � 1205',
    dueDate: 'Sep 30, 2026',
    status: InvoiceStatus.unpaid,
    items: const <InvoiceItem>[
      InvoiceItem(type: InvoiceItemType.condoFee, amount: 100, mustPaid: true),
    ],
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

Future<void> _waitForPaymentMethods(
  _FakeRepository repository,
  int count,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (repository.requests.length >= count) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail(
    'Expected $count payment method requests, got ${repository.requests.length}.',
  );
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

class _FakeRepository implements PaymentRepository {
  List<PaymentMethodOption> methods = const <PaymentMethodOption>[];
  List<Invoice> invoices = const <Invoice>[];
  CachedPaymentMethods? cached;
  Object? methodsError;
  bool manualResponses = false;
  int clearCalls = 0;

  final requests = <Completer<List<PaymentMethodOption>>>[];
  final cacheWrites = <int, List<PaymentMethodOption>>{};

  @override
  Future<List<PaymentMethodOption>> getPaymentMethods() {
    if (manualResponses) {
      final completer = Completer<List<PaymentMethodOption>>();
      requests.add(completer);
      return completer.future;
    }
    if (methodsError != null) {
      return Future<List<PaymentMethodOption>>.error(methodsError!);
    }
    return Future<List<PaymentMethodOption>>.value(methods);
  }

  @override
  Future<CachedPaymentMethods?> getCachedPaymentMethods(int userId) async {
    return cached;
  }

  @override
  Future<void> cachePaymentMethods(
    int userId,
    List<PaymentMethodOption> methods,
  ) async {
    cacheWrites[userId] = methods;
  }

  @override
  Future<void> clearPaymentMethodsCache() async {
    clearCalls++;
    cached = null;
  }

  @override
  Future<PaymentDashboard> getDashboard() {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) async {
    return null;
  }

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
  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<PaymentDetail> getPaymentDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<CachedPaymentList?> getCachedPaymentList(int userId) async => null;

  @override
  Future<void> cachePaymentList(
    int userId,
    PaymentListResponse response,
  ) async {}

  @override
  Future<void> clearPaymentListCache() async {}

  @override
  Future<List<Invoice>> getInvoices() async => invoices;

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
