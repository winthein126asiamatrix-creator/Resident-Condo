import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api_config.dart';

/// Logs requests and responses, in debug builds only.
///
/// The log is deliberately unhelpful about secrets: the Authorization header is
/// masked and any body field whose name looks like a credential is replaced, so
/// a device log or a bug report can be pasted around without leaking a session.
class ApiLogInterceptor extends Interceptor {
  ApiLogInterceptor({bool? enabled, this.logger = _print})
    // `ApiConfig.enableLogging` reads kDebugMode, so it cannot be a default
    // value on an optional parameter; it is resolved here instead.
    : enabled = enabled ?? ApiConfig.enableLogging;

  final bool enabled;

  final void Function(String) logger;

  static const _mask = '***';

  /// Header names whose value is never printed.
  static const _secretHeaders = <String>{
    'authorization',
    'cookie',
    'set-cookie',
  };

  /// Body keys whose value is never printed.
  static const _secretFields = <String>{
    'password',
    'new_password',
    'confirm_password',
    'token',
    'access_token',
    'refresh_token',
    'secret',
    'api_key',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      logger(
        '→ ${options.method} ${_uri(options.uri)}'
        ' ${_headers(options.headers)}'
        '${_body(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      logger(
        '← ${response.statusCode} ${_uri(response.requestOptions.uri)}'
        '${_body(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      logger(
        '✗ ${err.response?.statusCode ?? err.type.name} '
        '${_uri(err.requestOptions.uri)}',
      );
    }
    handler.next(err);
  }

  /// Path plus a redacted query.
  ///
  /// Rebuilt from the parts rather than printed from `uri.toString()`, because
  /// Dio merges `queryParameters` into the URI and printing both would repeat
  /// the query and skip the redaction.
  String _uri(Uri uri) {
    final origin = uri.hasScheme
        ? '${uri.scheme}://${uri.host}'
              '${uri.hasPort ? ':${uri.port}' : ''}'
        : '';
    return '$origin${uri.path}${_redactedQuery(uri.query)}';
  }

  String _headers(Map<String, dynamic> headers) {
    if (headers.isEmpty) {
      return '';
    }
    final safe = <String, String>{};
    headers.forEach((key, value) {
      safe[key] = _secretHeaders.contains(key.toLowerCase()) ? _mask : '$value';
    });
    return safe.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  String _body(Object? data) {
    if (data == null) {
      return '';
    }
    if (data is FormData) {
      // Multipart can carry a whole file; log the shape, never the content.
      return ' [multipart: ${data.files.length} file(s), '
          '${data.fields.length} field(s)]';
    }
    if (data is Map) {
      final safe = <String, dynamic>{};
      data.forEach((key, value) {
        safe['$key'] = _secretFields.contains('$key'.toLowerCase())
            ? _mask
            : value;
      });
      return ' $safe';
    }
    return ' [$data]';
  }

  /// Query strings can carry a token too, so keys are masked the same way.
  String _redactedQuery(String query) {
    if (query.isEmpty) {
      return '';
    }
    final pairs = query.split('&').map((pair) {
      final index = pair.indexOf('=');
      if (index == -1) {
        return pair;
      }
      final key = pair.substring(0, index);
      return _secretFields.contains(key.toLowerCase()) ? '$key=$_mask' : pair;
    });
    return '?${pairs.join('&')}';
  }

  static void _print(String message) => debugPrint(message);
}
