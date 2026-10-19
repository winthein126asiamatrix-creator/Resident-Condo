import '../config/app_environment.dart';

/// Build-time configuration for the backend connection.
///
/// The backend is selected from the active Flutter flavor through
/// [AppEnvironment]; the dev and prod URLs are defined in
/// `lib/core/config/app_environment.dart`.
abstract final class ApiConfig {
  /// Root of the backend for the environment this build was made for.
  ///
  /// `--flavor dev` talks to the development backend and `--flavor prod` to the
  /// production one; see [AppEnvironment] for the values and for the
  /// `--dart-define` overrides.
  ///
  /// Resolved once per build rather than declared as a `const`, because it
  /// depends on the flavor the binary was compiled with.
  static String get baseUrl => AppEnvironment.current.apiBaseUrl;

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
  /// Dev debug builds only. The log itself redacts the token and any field that
  /// looks like a credential, so a device log is never a credential leak.
  ///
  /// Reading the environment is guarded, unlike [baseUrl]: a logging switch must
  /// never be the thing that breaks a context that has no flavor, such as a unit
  /// test that injects its own client. Unresolvable means nothing is logged.
  static bool get enableLogging {
    try {
      return AppEnvironment.current.enableVerboseLogging;
    } on StateError {
      return false;
    }
  }
}
