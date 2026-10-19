import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:test/core/utils/super_print.dart';

enum AppEnvironment {
  dev(name: 'dev', isProduction: false),
  prod(name: 'prod', isProduction: true);

  const AppEnvironment({required this.name, required this.isProduction});

  /// The Flutter flavor name this environment is built from.
  final String name;

  final bool isProduction;

  bool get isDev => this == AppEnvironment.dev;

 
  static const String _devBaseUrl = 'https://dummyjson.com';

  static const String _prodBaseUrl = 'https://dummyjsonprod.com';

  /// Escapes both of the above for a one-off build.
  static const String _overrideBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The environment of this build.
  ///
  /// Throws when the flavor is missing or unknown, because a build without one
  /// has no environment to talk to and guessing would hide that.
  static AppEnvironment get current => _fromFlavor(appFlavor);

  static AppEnvironment _fromFlavor(String? flavor) => switch (flavor) {
    'dev' => AppEnvironment.dev,
    'prod' => AppEnvironment.prod,
    _ => throw StateError(
      'Unknown app flavor: ${flavor == null ? 'none' : '"$flavor"'}. '
      'Run with --flavor dev or --flavor prod.',
    ),
  };

 
  String get apiBaseUrl {
    final override = _overrideBaseUrl;
    if (override.isNotEmpty) {
      return _normalize(override);
    }
    superPrint(_prodBaseUrl);
    return switch (this) {
      AppEnvironment.dev => _normalize(_devBaseUrl),
      AppEnvironment.prod when _prodBaseUrl.isEmpty => throw StateError(
        'No production API base URL is configured. Set _prodBaseUrl in '
        'lib/core/config/app_environment.dart, or set API_BASE_URL to '
        'override both environments.',
      ),
      AppEnvironment.prod => _normalize(_prodBaseUrl),
    };
  }

  bool get enableVerboseLogging => isDev && kDebugMode;

  /// Drops a trailing slash, so a configured origin cannot turn every path into
  /// a double slash.
  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
