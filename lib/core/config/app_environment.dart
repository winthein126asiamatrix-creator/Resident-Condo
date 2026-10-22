
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment {
  dev(name: 'dev', isProduction: false),
  prod(name: 'prod', isProduction: true);

  const AppEnvironment({
    required this.name,
    required this.isProduction,
  });

  /// The Flutter flavor name this environment is built from.
  final String name;

  final bool isProduction;

  bool get isDev => this == AppEnvironment.dev;

  /// Optional one-off override:
  /// --dart-define=API_BASE_URL=https://example.com
  static const String _overrideBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// The environment of this build.
  ///
  /// Throws when the flavor is missing or unknown.
  static AppEnvironment get current => _fromFlavor(appFlavor);

  static AppEnvironment _fromFlavor(String? flavor) => switch (flavor) {
        'dev' => AppEnvironment.dev,
        'prod' => AppEnvironment.prod,
        _ => throw StateError(
            'Unknown app flavor: '
            '${flavor == null ? 'none' : '"$flavor"'}. '
            'Run with --flavor dev or --flavor prod.',
          ),
      };

  /// Reads API_BASE_URL from --dart-define first,
  /// then from the flavor-specific .env file.
  String get apiBaseUrl {
    final override = _overrideBaseUrl.trim();

    if (override.isNotEmpty) {
      return _normalize(override);
    }

    final baseUrl = dotenv.env['API_BASE_URL']?.trim() ?? '';

    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is missing from the environment configuration '
        'for "$name". Check the corresponding .env file.',
      );
    }

    return _normalize(baseUrl);
  }

  bool get enableVerboseLogging => isDev && kDebugMode;

  /// Removes a trailing slash to avoid double slashes in API paths.
  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
