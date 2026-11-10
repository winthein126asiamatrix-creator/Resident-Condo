import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/core/network/token_parser.dart';

void main() {
  group('TokenParser.tokensFrom', () {
    test('reads a snake_case REST response', () {
      final tokens = TokenParser.tokensFrom(<String, Object?>{
        'access_token': 'access',
        'refresh_token': 'refresh',
      });

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'refresh');
    });

    test('reads a camelCase response', () {
      final tokens = TokenParser.tokensFrom(<String, Object?>{
        'accessToken': 'access',
        'refreshToken': 'refresh',
      });

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'refresh');
    });

    test('unwraps a result envelope', () {
      final tokens = TokenParser.tokensFrom(<String, Object?>{
        'jsonrpc': '2.0',
        'result': <String, Object?>{
          'access_token': 'access',
          'refresh_token': 'refresh',
        },
      });

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'refresh');
    });

    test('unwraps a data envelope', () {
      final tokens = TokenParser.tokensFrom(<String, Object?>{
        'data': <String, Object?>{
          'access_token': 'access',
          'refresh_token': 'refresh',
        },
      });

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'refresh');
    });

    test('keeps the supplied refresh token when only access is returned', () {
      final tokens = TokenParser.tokensFrom(<String, Object?>{
        'access_token': 'access',
      }, fallbackRefreshToken: 'stored-refresh');

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'stored-refresh');
    });

    test('rejects an access-only response without a fallback', () {
      expect(
        () => TokenParser.tokensFrom(<String, Object?>{'access_token': 'a'}),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects a response with no access token', () {
      expect(
        () => TokenParser.tokensFrom(<String, Object?>{
          'refresh_token': 'refresh',
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects a non-map body', () {
      expect(
        () => TokenParser.tokensFrom('not json'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
