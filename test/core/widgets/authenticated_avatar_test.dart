import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/api_end_points.dart';
import 'package:test/core/network/dio_api_service.dart';
import 'package:test/core/network/token_refresher.dart';
import 'package:test/core/network/token_storage.dart';
import 'package:test/core/widgets/authenticated_avatar.dart';

const _avatarPath = '/users/6/avatar';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

final _svg = Uint8List.fromList(
  utf8.encode(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180">'
    '<rect width="180" height="180" fill="#6D2387"/>'
    '<text x="90" y="90" fill="#fff">O</text></svg>',
  ),
);

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

ResponseBody _bytes(
  List<int> body, {
  int status = 200,
  String contentType = 'image/png',
}) {
  return ResponseBody.fromBytes(
    body,
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[contentType],
    },
  );
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

DioApiService _service(
  Future<ResponseBody> Function(RequestOptions options) handler, {
  TokenStorage? storage,
  TokenRefresher? refresher,
}) {
  final dio = Dio()..httpClientAdapter = _FakeAdapter(handler);
  return DioApiService(
    tokenStorage:
        storage ??
        _MemoryTokenStorage(
          const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
        ),
    dio: dio,
    tokenRefresher: refresher,
    baseUrl: 'https://api.example.com',
  );
}

void main() {
  group('AuthenticatedAvatarLoader', () {
    test('fetches with the shared bearer token', () async {
      String? bearer;
      final service = _service((options) async {
        bearer = options.headers['Authorization'] as String?;
        return _bytes(_png);
      });
      final loader = AuthenticatedAvatarLoader(service);

      final data = await loader.load(_avatarPath);

      expect(bearer, 'Bearer access');
      expect(data?.format, AuthenticatedAvatarFormat.raster);
      expect(data?.bytes, _png);
    });

    test('detects SVG responses', () async {
      final service = _service(
        (_) async => _bytes(_svg, contentType: 'image/svg+xml'),
      );
      final loader = AuthenticatedAvatarLoader(service);

      final data = await loader.load(_avatarPath);

      expect(data?.format, AuthenticatedAvatarFormat.svg);
    });

    test('refreshes and retries a 401 before returning the avatar', () async {
      final storage = _MemoryTokenStorage(
        const AuthTokens(accessToken: 'old', refreshToken: 'refresh-old'),
      );
      var avatarCalls = 0;
      var refreshCalls = 0;

      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = _FakeAdapter((options) async {
          if (options.path == ApiEndPoints.refreshToken) {
            refreshCalls++;
            return _json(200, <String, dynamic>{
              'access_token': 'new',
              'refresh_token': 'refresh-new',
            });
          }
          return _json(404, <String, dynamic>{'error': 'unexpected'});
        });

      final service = _service(
        (options) async {
          if (options.path != _avatarPath) {
            return _json(404, <String, dynamic>{'error': 'unexpected'});
          }
          avatarCalls++;
          final bearer = options.headers['Authorization'];
          if (bearer == 'Bearer old') {
            return _json(401, <String, dynamic>{'message': 'expired'});
          }
          if (bearer == 'Bearer new') {
            return _bytes(_png);
          }
          return _json(401, <String, dynamic>{'message': 'missing token'});
        },
        storage: storage,
        refresher: TokenRefresher(refreshDio),
      );
      final loader = AuthenticatedAvatarLoader(service);

      final data = await loader.load(_avatarPath);

      expect(data?.format, AuthenticatedAvatarFormat.raster);
      expect(avatarCalls, 2);
      expect(refreshCalls, 1);
      expect(storage.tokens?.accessToken, 'new');
    });

    test('returns null for 403 and 404', () async {
      for (final status in <int>[403, 404]) {
        final service = _service(
          (_) async => _json(status, <String, dynamic>{'error': 'denied'}),
        );
        final loader = AuthenticatedAvatarLoader(service);

        expect(await loader.load(_avatarPath), isNull);
      }
    });

    test('returns null for a JSON body served with 200', () async {
      final service = _service(
        (_) async => _json(200, <String, dynamic>{'avatar_url': _avatarPath}),
      );
      final loader = AuthenticatedAvatarLoader(service);

      expect(await loader.load(_avatarPath), isNull);
    });

    test('returns null for corrupt bytes', () async {
      final service = _service(
        (_) async => _bytes(<int>[0x01, 0x02, 0x03], contentType: 'image/png'),
      );
      final loader = AuthenticatedAvatarLoader(service);

      expect(await loader.load(_avatarPath), isNull);
    });

    test('returns null on a network failure', () async {
      final service = _service((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final loader = AuthenticatedAvatarLoader(service);

      expect(await loader.load(_avatarPath), isNull);
    });

    test('caches by URL and deduplicates concurrent loads', () async {
      final gate = Completer<void>();
      var calls = 0;
      final service = _service((_) async {
        calls++;
        await gate.future;
        return _bytes(_png);
      });
      final loader = AuthenticatedAvatarLoader(service);

      final first = loader.load(_avatarPath);
      final second = loader.load(_avatarPath);
      gate.complete();

      final results = await Future.wait(<Future<AuthenticatedAvatarData?>>[
        first,
        second,
      ]);
      expect(calls, 1);
      expect(results[0]?.format, AuthenticatedAvatarFormat.raster);
      expect(results[1]?.format, AuthenticatedAvatarFormat.raster);

      await loader.load(_avatarPath);
      expect(calls, 1);
    });
  });

  group('AuthenticatedAvatar', () {
    testWidgets('shows the fallback when the URL is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthenticatedAvatar(url: null, fallback: Text('AB')),
        ),
      );

      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('renders a valid SVG avatar inside a CircleAvatar', (
      tester,
    ) async {
      final service = _service(
        (_) async => _bytes(_svg, contentType: 'image/svg+xml'),
      );
      final loader = AuthenticatedAvatarLoader(service);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircleAvatar(
                radius: 31,
                child: AuthenticatedAvatar(
                  url: _avatarPath,
                  loader: loader,
                  fallback: const Text('AB'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.text('AB'), findsNothing);
    });

    testWidgets('renders a raster avatar and shares one request', (
      tester,
    ) async {
      var calls = 0;
      final service = _service((_) async {
        calls++;
        return _bytes(_png);
      });
      final loader = AuthenticatedAvatarLoader(service);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                AuthenticatedAvatar(
                  url: _avatarPath,
                  loader: loader,
                  fallback: const Text('AB'),
                ),
                AuthenticatedAvatar(
                  url: _avatarPath,
                  loader: loader,
                  fallback: const Text('AB'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.byType(ClipOval), findsNWidgets(2));
      expect(find.text('AB'), findsNothing);
    });

    testWidgets('loads again when the avatar URL changes', (tester) async {
      var calls = 0;
      final service = _service((_) async {
        calls++;
        return _bytes(_png);
      });
      final loader = AuthenticatedAvatarLoader(service);

      Widget build(String url) {
        return MaterialApp(
          home: Scaffold(
            body: AuthenticatedAvatar(
              url: url,
              loader: loader,
              fallback: const Text('AB'),
            ),
          ),
        );
      }

      await tester.pumpWidget(build('/users/6/avatar'));
      await tester.pumpAndSettle();
      expect(calls, 1);

      await tester.pumpWidget(build('/users/7/avatar'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('falls back when the response is not an image', (tester) async {
      final service = _service(
        (_) async => _json(200, <String, dynamic>{'ok': true}),
      );
      final loader = AuthenticatedAvatarLoader(service);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthenticatedAvatar(
              url: _avatarPath,
              loader: loader,
              fallback: const Text('AB'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AB'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
    });
  });
}
