import 'package:flutter/foundation.dart';

/// Build-time configuration for the backend connection.
///
/// Values come from `--dart-define`, so a release build points at production
/// without editing source:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://condo.example.com
/// flutter build apk --dart-define=API_BASE_URL=https://condo.example.com
/// ```
abstract final class ApiConfig {
  /// Root of the backend.
  ///
  /// Defaults to DummyJSON, the public mock backend the app is developed
  /// against. A release build points at the real Condo Residents backend with:
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=https://condo.example.com
  /// flutter build apk --dart-define=API_BASE_URL=https://condo.example.com
  /// ```
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dummyjson.com',
  );

  /// Lifetime requested for both the access token and the refresh token, in
  /// minutes.
  ///
  /// The short default is deliberate: an access token that dies after a minute
  /// exercises the refresh path continuously during development instead of
  /// leaving it to be discovered in production. Raise it once the backend makes
  /// long-lived tokens, or per build:
  ///
  /// ```
  /// flutter run --dart-define=API_TOKEN_EXPIRY_MINS=30
  /// ```
  static const int tokenExpiresInMins = int.fromEnvironment(
    'API_TOKEN_EXPIRY_MINS',
    defaultValue: 1,
  );

  /// Whether the app is talking to the JSON-RPC interface or to plain REST
  /// routes. Odoo serves both; the JSON-RPC mode exists for endpoints that are
  /// not exposed over REST.
  static const bool useJsonRpcEnvelope = bool.fromEnvironment(
    'API_JSON_RPC',
    defaultValue: false,
  );

  /// JSON-RPC method used for every call, and the Odoo RPC root.
  static const String jsonRpcPath = '/jsonrpc';

  /// Bearer scheme sent with the session token.
  static const String authScheme = 'Bearer';

  /// Header the backend expects the session token in.
  static const String authorizationHeader = 'Authorization';

  /// How long to wait for the connection to be established.
  static const Duration connectTimeout = Duration(seconds: 20);

  /// How long to wait for the request body to be sent.
  static const Duration sendTimeout = Duration(seconds: 20);

  /// How long to wait for the response. Longer than [connectTimeout] because a
  /// report or an export can legitimately take a while to generate.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Uploads carry photos and run over the same client.
  static const Duration uploadTimeout = Duration(minutes: 2);

  /// Whether requests and responses are logged.
  ///
  /// Debug builds only, and the log itself redacts the token and any field that
  /// looks like a credential, so a device log is never a credential leak.
  static bool get enableLogging => kDebugMode;
}
