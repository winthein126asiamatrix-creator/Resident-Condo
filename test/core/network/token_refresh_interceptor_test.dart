import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/api_config.dart';
import 'package:test/core/network/api_end_points.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/token_refresher.dart';
import 'package:test/core/network/token_storage.dart';

const _oldAccess = 'old-access-token';
const _newAccess = 'new-access-token';
const _oldRefresh = 'old-refresh-token';
const _newRefresh = 'new-refresh-token';

AuthTokens _oldTokens() =>
    const AuthTokens(accessToken: _oldAccess, refreshToken: _oldRefresh);

Map<String, dynamic> _asMap(Object? json) =>
    Map<String, dynamic>.from(json as Map);

String? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString();
    }
  }
  return null;
}

String? _bearer(RequestOptions options) =>
    _header(options, ApiConfig.authorizationHeader);

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(this.tokens);

  AuthTokens? tokens;
  int writes = 0;
  int clears = 0;

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<bool> writeTokens(AuthTokens value) async {
    writes++;
    tokens = value;
    return true;
  }

  @override
  Future<void> clearTokens() async {
    clears++;
    tokens = null;
  }
}

typedef _Handler = Future<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handle);

  final _Handler handle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options, requestStream);

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

DioApiService _service({
  required _MemoryTokenStorage storage,
  required _Handler main,
  required _Handler refresh,
}) {
  final mainDio = Dio()..httpClientAdapter = _FakeAdapter(main);
  final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..httpClientAdapter = _FakeAdapter(refresh);

  return DioApiService(
    tokenStorage: storage,
    dio: mainDio,
    tokenRefresher: TokenRefresher(refreshDio),
    baseUrl: 'https://api.example.com',
  );
}

Future<void> _drain(Stream<Uint8List>? stream) async {
  if (stream != null) {
    await stream.drain<void>();
  }
}

void main() {
  test('normal authenticated request succeeds without refreshing', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    var refreshCalls = 0;

    final service = _service(
      storage: storage,
      main: (options, _) async {
        expect(_bearer(options), 'Bearer $_oldAccess');
        return _json(200, <String, dynamic>{'ok': true});
      },
      refresh: (_, _) async {
        refreshCalls++;
        return _json(200, <String, dynamic>{
          'access_token': _newAccess,
          'refresh_token': _newRefresh,
        });
      },
    );

    final payload = await service.get<Map<String, dynamic>>(
      '/secure',
      parse: _asMap,
    );

    expect(payload['ok'], isTrue);
    expect(refreshCalls, 0);
    expect(storage.tokens?.accessToken, _oldAccess);
    expect(storage.writes, 0);
    expect(storage.clears, 0);
  });

  test('401 refreshes, saves both tokens, and retries the request', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    var mainCalls = 0;
    var refreshCalls = 0;
    String? retriedBearer;

    final service = _service(
      storage: storage,
      main: (options, _) async {
        mainCalls++;
        final bearer = _bearer(options);
        if (bearer == 'Bearer $_oldAccess') {
          return _json(401, <String, dynamic>{'message': 'expired'});
        }
        if (bearer == 'Bearer $_newAccess') {
          retriedBearer = bearer;
          return _json(200, <String, dynamic>{'ok': true});
        }
        return _json(500, <String, dynamic>{'error': 'unexpected bearer'});
      },
      refresh: (options, _) async {
        refreshCalls++;
        expect(options.path, ApiEndPoints.refreshToken);
        expect(
          (options.data as Map<String, dynamic>)['refresh_token'],
          _oldRefresh,
        );
        return _json(200, <String, dynamic>{
          'access_token': _newAccess,
          'refresh_token': _newRefresh,
        });
      },
    );

    final payload = await service.get<Map<String, dynamic>>(
      '/secure',
      parse: _asMap,
    );

    expect(payload['ok'], isTrue);
    expect(mainCalls, 2);
    expect(refreshCalls, 1);
    expect(retriedBearer, 'Bearer $_newAccess');
    expect(storage.tokens?.accessToken, _newAccess);
    expect(storage.tokens?.refreshToken, _newRefresh);
    expect(storage.writes, 1);
    expect(storage.clears, 0);
  });

  test(
    'an access-only refresh keeps the stored refresh token and retries',
    () async {
      final storage = _MemoryTokenStorage(_oldTokens());
      var refreshCalls = 0;
      String? retriedBearer;
      var expired = 0;

      final service = _service(
        storage: storage,
        main: (options, _) async {
          final bearer = _bearer(options);
          if (bearer == 'Bearer $_oldAccess') {
            return _json(401, <String, dynamic>{'message': 'expired'});
          }
          retriedBearer = bearer;
          return _json(200, <String, dynamic>{'ok': true});
        },
        refresh: (_, _) async {
          refreshCalls++;
          return _json(200, <String, dynamic>{'access_token': _newAccess});
        },
      )..onSessionExpired = () => expired++;

      final payload = await service.get<Map<String, dynamic>>(
        '/secure',
        parse: _asMap,
      );

      expect(payload['ok'], isTrue);
      expect(refreshCalls, 1);
      expect(retriedBearer, 'Bearer $_newAccess');
      expect(storage.tokens?.accessToken, _newAccess);
      expect(storage.tokens?.refreshToken, _oldRefresh);
      expect(storage.clears, 0);
      expect(expired, 0);
    },
  );

  test('a nested camelCase refresh response is accepted', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    String? retriedBearer;

    final service = _service(
      storage: storage,
      main: (options, _) async {
        final bearer = _bearer(options);
        if (bearer == 'Bearer $_oldAccess') {
          return _json(401, <String, dynamic>{'message': 'expired'});
        }
        retriedBearer = bearer;
        return _json(200, <String, dynamic>{'ok': true});
      },
      refresh: (_, _) async {
        return _json(200, <String, dynamic>{
          'result': <String, dynamic>{
            'accessToken': _newAccess,
            'refreshToken': _newRefresh,
          },
        });
      },
    );

    final payload = await service.get<Map<String, dynamic>>(
      '/secure',
      parse: _asMap,
    );

    expect(payload['ok'], isTrue);
    expect(retriedBearer, 'Bearer $_newAccess');
    expect(storage.tokens?.accessToken, _newAccess);
    expect(storage.tokens?.refreshToken, _newRefresh);
  });

  test(
    'a retried request that gets 401 again is not refreshed twice',
    () async {
      final storage = _MemoryTokenStorage(_oldTokens());
      var mainCalls = 0;
      var refreshCalls = 0;
      var expired = 0;

      final service = _service(
        storage: storage,
        main: (_, _) async {
          mainCalls++;
          return _json(401, <String, dynamic>{'message': 'expired'});
        },
        refresh: (_, _) async {
          refreshCalls++;
          return _json(200, <String, dynamic>{
            'access_token': _newAccess,
            'refresh_token': _newRefresh,
          });
        },
      )..onSessionExpired = () => expired++;

      Object? error;
      try {
        await service.get<Map<String, dynamic>>('/secure', parse: _asMap);
      } catch (caught) {
        error = caught;
      }

      expect(error, isA<ApiException>());
      expect((error! as ApiException).isUnauthorized, isTrue);
      expect(mainCalls, 2);
      expect(refreshCalls, 1);
      expect(expired, 0);
    },
  );

  test('an invalid refresh token clears the session', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    var refreshCalls = 0;
    var expired = 0;

    final service = _service(
      storage: storage,
      main: (_, _) async {
        return _json(401, <String, dynamic>{'message': 'expired'});
      },
      refresh: (_, _) async {
        refreshCalls++;
        return _json(401, <String, dynamic>{'message': 'invalid refresh'});
      },
    )..onSessionExpired = () => expired++;

    Object? error;
    try {
      await service.get<Map<String, dynamic>>('/secure', parse: _asMap);
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<ApiException>());
    expect((error! as ApiException).isUnauthorized, isTrue);
    expect(refreshCalls, 1);
    expect(storage.tokens, isNull);
    expect(storage.clears, greaterThanOrEqualTo(1));
    expect(expired, 1);
  });

  test('simultaneous 401s share one refresh and all requests retry', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    final bothOriginalSent = Completer<void>();
    final refreshStarted = Completer<void>();
    final allowRefresh = Completer<void>();
    var originalSent = 0;
    var retried = 0;
    var refreshCalls = 0;

    final service = _service(
      storage: storage,
      main: (options, _) async {
        final bearer = _bearer(options);
        if (bearer == 'Bearer $_oldAccess') {
          originalSent++;
          if (originalSent == 2 && !bothOriginalSent.isCompleted) {
            bothOriginalSent.complete();
          }
          return _json(401, <String, dynamic>{'message': 'expired'});
        }
        if (bearer == 'Bearer $_newAccess') {
          retried++;
          return _json(200, <String, dynamic>{'path': options.path});
        }
        return _json(500, <String, dynamic>{'error': 'unexpected bearer'});
      },
      refresh: (_, _) async {
        refreshCalls++;
        if (!refreshStarted.isCompleted) {
          refreshStarted.complete();
        }
        await bothOriginalSent.future;
        await allowRefresh.future;
        return _json(200, <String, dynamic>{
          'access_token': _newAccess,
          'refresh_token': _newRefresh,
        });
      },
    );

    final results = <Map<String, dynamic>>[];
    final futures = <Future<void>>[
      service
          .get<Map<String, dynamic>>('/first', parse: _asMap)
          .then(results.add),
      service
          .get<Map<String, dynamic>>('/second', parse: _asMap)
          .then(results.add),
    ];

    await bothOriginalSent.future;
    await refreshStarted.future;
    expect(refreshCalls, 1);

    allowRefresh.complete();
    await Future.wait(futures);

    expect(refreshCalls, 1);
    expect(originalSent, 2);
    expect(retried, 2);
    expect(
      results.map((result) => result['path']),
      containsAll(['/first', '/second']),
    );
    expect(storage.tokens?.accessToken, _newAccess);
    expect(storage.tokens?.refreshToken, _newRefresh);
  });

  test(
    'a 5xx refresh response keeps the session and surfaces a server error',
    () async {
      final storage = _MemoryTokenStorage(_oldTokens());
      var expired = 0;

      final service = _service(
        storage: storage,
        main: (_, _) async {
          return _json(401, <String, dynamic>{'message': 'expired'});
        },
        refresh: (_, _) async {
          return _json(500, <String, dynamic>{'message': 'backend down'});
        },
      )..onSessionExpired = () => expired++;

      Object? error;
      try {
        await service.get<Map<String, dynamic>>('/secure', parse: _asMap);
      } catch (caught) {
        error = caught;
      }

      expect(error, isA<ApiException>());
      final apiError = error! as ApiException;
      expect(apiError.kind, ApiFailureKind.server);
      expect(apiError.statusCode, 500);
      expect(apiError.isUnauthorized, isFalse);
      expect(storage.tokens?.accessToken, _oldAccess);
      expect(storage.tokens?.refreshToken, _oldRefresh);
      expect(storage.clears, 0);
      expect(expired, 0);
    },
  );

  test('a network failure during refresh keeps the session', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    var expired = 0;

    final service = _service(
      storage: storage,
      main: (_, _) async {
        return _json(401, <String, dynamic>{'message': 'expired'});
      },
      refresh: (options, _) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'offline',
        );
      },
    )..onSessionExpired = () => expired++;

    Object? error;
    try {
      await service.get<Map<String, dynamic>>('/secure', parse: _asMap);
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<ApiException>());
    final apiError = error! as ApiException;
    expect(apiError.kind, ApiFailureKind.network);
    expect(apiError.isRetryable, isTrue);
    expect(apiError.isUnauthorized, isFalse);
    expect(storage.tokens?.accessToken, _oldAccess);
    expect(storage.tokens?.refreshToken, _oldRefresh);
    expect(storage.clears, 0);
    expect(expired, 0);
  });

  test('unauthenticated requests do not trigger a refresh', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    var refreshCalls = 0;

    final service = _service(
      storage: storage,
      main: (options, _) async {
        expect(_bearer(options), isNull);
        return _json(401, <String, dynamic>{'message': 'wrong credentials'});
      },
      refresh: (_, _) async {
        refreshCalls++;
        return _json(200, <String, dynamic>{
          'access_token': _newAccess,
          'refresh_token': _newRefresh,
        });
      },
    );

    Object? error;
    try {
      await service.post<Map<String, dynamic>>(
        ApiEndPoints.login,
        data: <String, dynamic>{'username': 'resident', 'password': 'secret'},
        options: service.withoutAuth(),
        parse: _asMap,
      );
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<ApiException>());
    expect((error! as ApiException).isUnauthorized, isTrue);
    expect(refreshCalls, 0);
    expect(storage.tokens?.accessToken, _oldAccess);
  });

  test('POST method, query, headers and JSON body survive the retry', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    var retried = false;
    String? method;
    Map<String, dynamic>? body;
    Map<String, dynamic>? query;
    String? customHeader;
    String? bearer;

    final service = _service(
      storage: storage,
      main: (options, _) async {
        final currentBearer = _bearer(options);
        if (currentBearer == 'Bearer $_oldAccess') {
          return _json(401, <String, dynamic>{'message': 'expired'});
        }
        retried = true;
        method = options.method;
        body = Map<String, dynamic>.from(options.data as Map);
        query = Map<String, dynamic>.from(options.queryParameters);
        customHeader = _header(options, 'X-Test');
        bearer = currentBearer;
        return _json(200, <String, dynamic>{'ok': true});
      },
      refresh: (_, _) async {
        return _json(200, <String, dynamic>{
          'access_token': _newAccess,
          'refresh_token': _newRefresh,
        });
      },
    );

    final payload = await service.post<Map<String, dynamic>>(
      '/payments',
      data: <String, dynamic>{'amount': 10, 'note': 'rent'},
      query: <String, dynamic>{'q': '1'},
      options: Options(headers: <String, dynamic>{'X-Test': 'preserved'}),
      parse: _asMap,
    );

    expect(payload['ok'], isTrue);
    expect(retried, isTrue);
    expect(method, 'POST');
    expect(body, <String, dynamic>{'amount': 10, 'note': 'rent'});
    expect(query, <String, dynamic>{'q': '1'});
    expect(customHeader, 'preserved');
    expect(bearer, 'Bearer $_newAccess');
  });

  test('multipart body can be replayed after a 401 refresh', () async {
    final storage = _MemoryTokenStorage(_oldTokens());
    var mainCalls = 0;
    List<String>? retriedFields;
    List<String?>? retriedFiles;

    final service = _service(
      storage: storage,
      main: (options, requestStream) async {
        mainCalls++;
        await _drain(requestStream);
        final currentBearer = _bearer(options);
        if (currentBearer == 'Bearer $_oldAccess') {
          return _json(401, <String, dynamic>{'message': 'expired'});
        }
        final data = options.data;
        expect(data, isA<FormData>());
        final form = data! as FormData;
        retriedFields = form.fields
            .map((entry) => '${entry.key}=${entry.value}')
            .toList();
        retriedFiles = form.files.map((entry) => entry.value.filename).toList();
        return _json(200, <String, dynamic>{'ok': true});
      },
      refresh: (_, _) async {
        return _json(200, <String, dynamic>{
          'access_token': _newAccess,
          'refresh_token': _newRefresh,
        });
      },
    );

    final payload = await service.uploadMultipart<Map<String, dynamic>>(
      '/photos',
      fields: <String, dynamic>{'note': 'hello'},
      files: <String, MultipartFile>{
        'photo': MultipartFile.fromBytes(<int>[1, 2, 3], filename: 'photo.jpg'),
      },
      parse: _asMap,
    );

    expect(payload['ok'], isTrue);
    expect(mainCalls, 2);
    expect(retriedFields, contains('note=hello'));
    expect(retriedFiles, contains('photo.jpg'));
    expect(storage.tokens?.accessToken, _newAccess);
    expect(storage.tokens?.refreshToken, _newRefresh);
  });
}
