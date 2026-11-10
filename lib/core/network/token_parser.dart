import 'api_exception.dart';
import 'token_storage.dart';

/// Reads tokens out of a backend response.
///
/// Lives in core because two unrelated callers need it: the refresh
/// interceptor, which parses the refresh response, and the auth feature, which
/// parses the login response. One place means a change to the wire format is a
/// one line change rather than a hunt for duplicated token lookups.
abstract final class TokenParser {
  /// Top-level keys a token pair is returned under.
  static const List<String> _accessKeys = <String>[
    'access_token',
    'accessToken',
  ];
  static const List<String> _refreshKeys = <String>[
    'refresh_token',
    'refreshToken',
  ];

  /// Envelopes a backend may wrap the pair in.
  static const List<String> _envelopeKeys = <String>[
    'result',
    'data',
    'tokens',
    'session',
  ];

  /// The token pair in [json].
  ///
  /// The wire shape is tolerated rather than assumed: a refresh response may
  /// return the pair at the top level, inside a `result`/`data` envelope, or use
  /// either the snake_case or camelCase spelling. A refresh that only mints a
  /// new access token can also supply [fallbackRefreshToken], which is the
  /// token already in storage, so a non-rotating backend does not look like a
  /// failed refresh.
  ///
  /// Throws [ApiException] when the pair is incomplete, because storing half a
  /// pair would sign the resident out at the first expiry instead of failing
  /// here where the backend response is still in hand.
  static AuthTokens tokensFrom(Object? json, {String? fallbackRefreshToken}) {
    final map = _tokenMap(json);
    final access = _firstString(map, _accessKeys);
    final refresh =
        _firstString(map, _refreshKeys) ?? _nonEmpty(fallbackRefreshToken);

    if (access == null || refresh == null) {
      throw const ApiException(
        'The sign-in service returned an incomplete session. Please try again.',
        kind: ApiFailureKind.server,
      );
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  /// The map that actually holds the pair.
  ///
  /// A plain REST response is already the map; an Odoo-style or versioned
  /// envelope is unwrapped one level so both succeed without the caller having
  /// to know which shape it received.
  static Map<Object?, Object?> _tokenMap(Object? json) {
    if (json is! Map) {
      return const <Object?, Object?>{};
    }
    if (_hasToken(json)) {
      return json;
    }
    for (final key in _envelopeKeys) {
      final nested = json[key];
      if (nested is Map && _hasToken(nested)) {
        return nested;
      }
    }
    return json;
  }

  static bool _hasToken(Map<dynamic, dynamic> map) =>
      _firstString(map, _accessKeys) != null ||
      _firstString(map, _refreshKeys) != null;

  static String? _firstString(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = _nonEmpty(map[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static String? _nonEmpty(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }
}
