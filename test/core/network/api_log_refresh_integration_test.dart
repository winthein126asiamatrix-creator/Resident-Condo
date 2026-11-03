import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/api_end_points.dart';
import 'package:test/core/network/api_log_store.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/interceptors/api_log_interceptor.dart';
import 'package:test/core/network/token_refresher.dart';
import 'package:test/core/network/token_storage.dart';

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(this.tokens);

  AuthTokens? tokens;

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<bool> writeTokens(AuthTokens value) async {
    tokens = value;
    return true;
  }

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handle);

  final Future<ResponseBody> Function(RequestOptions options) handle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);

  @override
  void close({bool force = false}) {}
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

void main() {
  test(
    'refresh keeps one request entry and logs the refresh separately',
    () async {
      final store = ApiLogStore();
      final storage = _MemoryTokenStorage(
        const AuthTokens(accessToken: 'old', refreshToken: 'refresh-old'),
      );

      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = _FakeAdapter((options) async {
          if (options.path == ApiEndPoints.refreshToken) {
            return _json(200, <String, dynamic>{
              'access_token': 'new',
              'refresh_token': 'refresh-new',
            });
          }
          return _json(404, <String, dynamic>{'error': 'unexpected'});
        });
      refreshDio.interceptors.add(
        ApiLogInterceptor(
          enabled: true,
          store: store,
          label: ApiLogInterceptor.refreshLabel,
        ),
      );

      final mainDio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          final bearer = options.headers['Authorization'];
          if (options.path == '/secure' && bearer == 'Bearer old') {
            return _json(401, <String, dynamic>{'message': 'expired'});
          }
          if (options.path == '/secure' && bearer == 'Bearer new') {
            return _json(200, <String, dynamic>{'ok': true});
          }
          return _json(404, <String, dynamic>{'error': 'unexpected'});
        });

      final service = DioApiService(
        tokenStorage: storage,
        dio: mainDio,
        tokenRefresher: TokenRefresher(refreshDio),
        apiLogStore: store,
        baseUrl: 'https://api.example.com',
      );

      final payload = await service.get<Map<String, dynamic>>(
        '/secure',
        parse: (json) => Map<String, dynamic>.from(json as Map),
      );

      expect(payload['ok'], isTrue);
      expect(storage.tokens?.accessToken, 'new');
      expect(storage.tokens?.refreshToken, 'refresh-new');

      expect(store.total, 2);
      final requestLogs = store.logs
          .where((log) => log.endpoint == '/secure')
          .toList();
      final refreshLogs = store.logs
          .where((log) => log.label == ApiLogInterceptor.refreshLabel)
          .toList();

      expect(requestLogs, hasLength(1));
      expect(requestLogs.single.isSuccess, isTrue);
      expect(requestLogs.single.statusCode, 200);
      expect(refreshLogs, hasLength(1));
      expect(refreshLogs.single.isSuccess, isTrue);
      expect(
        (refreshLogs.single.requestBody
            as Map<String, Object?>)['refresh_token'],
        '***',
      );
    },
  );
}
