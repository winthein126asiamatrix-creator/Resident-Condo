import 'package:dio/dio.dart';

import '../../utils/super_print.dart';
import '../api_config.dart';

/// Logs requests and responses, in debug builds only.
///
/// The log is deliberately unhelpful about secrets: the Authorization header is
/// masked and any body field whose name looks like a credential is replaced, so
/// a device log or a bug report can be pasted around without leaking a session.
///
/// Every line goes through [superPrint], which gives it a title, a caller and a
/// timestamp. Redaction happens before that call, so what reaches the log has
/// already been made safe.
class ApiLogInterceptor extends Interceptor {
  ApiLogInterceptor({bool? enabled, this.logger})
    // `ApiConfig.enableLogging` reads kDebugMode, so it cannot be a default
    // value on an optional parameter; it is resolved here instead.
    : enabled = enabled ?? ApiConfig.enableLogging;

  final bool enabled;

  /// Optional override for the log sink.
  ///
  /// Left null to log through [superPrint]. Inject a callback to send the same
  /// redacted line somewhere else.
  final void Function(String)? logger;

  static const _mask = '***';

  /// Header names whose value is never printed.
  static const _secretHeaders = <String>{
    'authorization',
    'cookie',
    'set-cookie',
  };

  /// Body keys whose value is never printed, at any depth.
  ///
  /// Covers the snake_case the app has always used and the camelCase DummyJSON
  /// answers with, so a token in either shape is masked.
  static const _secretFields = <String>{
    'password',
    'new_password',
    'confirm_password',
    'token',
    'access_token',
    'refresh_token',
    'accesstoken',
    'refreshtoken',
    'secret',
    'api_key',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _emit(
        '→ ${options.method} ${_uri(options.uri)}'
        ' ${_headers(options.headers)}${_body(options.data)}',
        title: 'API Request',
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
      _emit(
        '← ${response.statusCode} ${_uri(response.requestOptions.uri)}'
        '${_body(response.data)}',
        title: 'API Response',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      _emit(
        '✗ ${err.response?.statusCode ?? err.type.name} '
        '${_uri(err.requestOptions.uri)}',
        title: 'API Error',
      );
    }
    handler.next(err);
  }

  /// Hands a redacted line to [superPrint], or to an injected [logger].
  void _emit(String message, {required String title}) {
    if (logger != null) {
      logger!(message);
    } else {
      superPrint(message, title: title);
    }
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
      return ' ${_redact(data)}';
    }
    if (data is List) {
      return ' ${_redact(data)}';
    }
    return ' [$data]';
  }

  /// Replaces the value of any secret key, at any depth of [value].
  ///
  /// A token nested inside a body object is as leaky as one at the top, so the
  /// walk does not stop at the first level.
  Object? _redact(Object? value) {
    if (value is Map) {
      final safe = <String, dynamic>{};
      value.forEach((key, child) {
        safe['$key'] = _secretFields.contains('$key'.toLowerCase())
            ? _mask
            : _redact(child);
      });
      return safe;
    }
    if (value is List) {
      return value.map(_redact).toList();
    }
    return value;
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
}