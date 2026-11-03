import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/api_log_store.dart';
import 'package:test/core/network/interceptors/api_log_interceptor.dart';
import 'package:test/core/network/interceptors/api_log_redactor.dart';
import 'package:test/core/network/interceptors/token_refresh_interceptor.dart';

RequestOptions _options({
  String path = '/api/test',
  String method = 'GET',
  Map<String, dynamic>? query,
  Object? data,
  Map<String, dynamic>? headers,
}) {
  return RequestOptions(
    path: path,
    method: method,
    baseUrl: 'https://api.example.com',
    queryParameters: query,
    data: data,
    headers: headers ?? <String, dynamic>{'Content-Type': 'application/json'},
  );
}

void _request(ApiLogInterceptor interceptor, RequestOptions options) {
  interceptor.onRequest(options, RequestInterceptorHandler());
}

void _response(
  ApiLogInterceptor interceptor,
  RequestOptions options, {
  int status = 200,
  Object? data,
}) {
  interceptor.onResponse(
    Response<dynamic>(requestOptions: options, statusCode: status, data: data),
    ResponseInterceptorHandler(),
  );
}

void main() {
  late ApiLogStore store;
  late ApiLogInterceptor interceptor;

  setUp(() {
    store = ApiLogStore();
    interceptor = ApiLogInterceptor(enabled: true, store: store);
  });

  test('pairs a request with its success response and redacts both', () async {
    final options = _options(
      query: <String, dynamic>{'access_token': 'query-secret', 'page': '1'},
      headers: <String, dynamic>{
        'Authorization': 'Bearer header-secret',
        'Content-Type': 'application/json',
      },
      data: <String, dynamic>{'name': 'A', 'password': 'body-secret'},
    );

    _request(interceptor, options);

    final pending = store.logs.single;
    expect(pending.isPending, isTrue);
    expect(pending.queryParameters['access_token'], ApiLogRedactor.mask);
    expect(pending.url, isNot(contains('query-secret')));
    expect(pending.requestHeaders['Authorization'], ApiLogRedactor.mask);
    expect(
      (pending.requestBody as Map<String, Object?>)['password'],
      ApiLogRedactor.mask,
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    _response(
      interceptor,
      options,
      data: <String, dynamic>{'ok': true, 'refresh_token': 'response-secret'},
    );

    final completed = store.logs.single;
    expect(completed.id, pending.id);
    expect(completed.isSuccess, isTrue);
    expect(completed.statusCode, 200);
    expect(completed.durationMs, greaterThanOrEqualTo(10));
    expect(
      (completed.responseBody as Map<String, Object?>)['refresh_token'],
      ApiLogRedactor.mask,
    );
  });

  test('classifies a non-2xx response as failed', () {
    final options = _options();

    _request(interceptor, options);
    _response(interceptor, options, status: 500, data: <String, dynamic>{});

    final log = store.logs.single;
    expect(log.isFailed, isTrue);
    expect(log.isSuccess, isFalse);
    expect(log.statusCode, 500);
    expect(log.errorMessage, contains('500'));
  });

  test('captures a transport error with its type and response body', () async {
    final options = _options(method: 'POST', path: '/auth/login');
    _request(interceptor, options);

    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      message: 'login rejected',
      stackTrace: StackTrace.current,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 401,
        data: <String, dynamic>{'password': 'response-secret'},
      ),
    );
    final handler = ErrorInterceptorHandler();
    interceptor.onError(error, handler);
    await expectLater(
      (handler as dynamic).future as Future<Object?>,
      throwsA(anything),
    );

    final log = store.logs.single;
    expect(log.isFailed, isTrue);
    expect(log.statusCode, 401);
    expect(log.dioExceptionType, DioExceptionType.badResponse.name);
    expect(log.errorMessage, 'login rejected');
    expect(log.stackTrace, isNotNull);
    expect(
      (log.responseBody as Map<String, Object?>)['password'],
      ApiLogRedactor.mask,
    );
  });

  test(
    'keeps concurrent requests paired when responses arrive out of order',
    () {
      final first = _options(path: '/first');
      final second = _options(path: '/second', method: 'POST');

      _request(interceptor, first);
      _request(interceptor, second);
      expect(store.total, 2);

      _response(
        interceptor,
        second,
        status: 201,
        data: <String, dynamic>{'which': 'second'},
      );
      _response(interceptor, first, data: <String, dynamic>{'which': 'first'});

      final firstLog = store.logs.firstWhere((log) => log.endpoint == '/first');
      final secondLog = store.logs.firstWhere(
        (log) => log.endpoint == '/second',
      );

      expect(firstLog.isSuccess, isTrue);
      expect(firstLog.statusCode, 200);
      expect((firstLog.responseBody as Map<String, Object?>)['which'], 'first');
      expect(secondLog.isSuccess, isTrue);
      expect(secondLog.statusCode, 201);
      expect(
        (secondLog.responseBody as Map<String, Object?>)['which'],
        'second',
      );
    },
  );

  test('an auth replay reuses the original log entry', () {
    final options = _options(method: 'POST', path: '/payments');

    _request(interceptor, options);
    final id = store.logs.single.id;

    options.extra[TokenRefreshInterceptor.retriedExtra] = true;
    _request(interceptor, options);

    expect(store.total, 1);
    expect(store.logs.single.id, id);

    _response(interceptor, options, data: <String, dynamic>{'ok': true});

    expect(store.total, 1);
    expect(store.logs.single.isSuccess, isTrue);
  });

  test('does nothing when disabled', () {
    final disabled = ApiLogInterceptor(enabled: false, store: store);

    _request(disabled, _options());

    expect(store.total, 0);
  });
}
