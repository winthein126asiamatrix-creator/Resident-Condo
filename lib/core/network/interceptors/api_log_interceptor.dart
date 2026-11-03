import 'package:dio/dio.dart';

import '../../utils/super_print.dart';
import '../api_config.dart';
import '../api_log_store.dart';
import 'api_log_redactor.dart';

/// Captures every request that passes through the app's Dio client.
///
/// The interceptor is deliberately a passive observer: it never mutates
/// headers, bodies, status codes or errors. A failure inside the logger is
/// swallowed so it can never turn a working API call into a failed one.
///
/// A request is stored as a pending entry and replaced by id when its response
/// or error arrives. That is what keeps concurrent calls paired even when their
/// responses come back out of order, and it keeps a token-refresh replay from
/// appearing as a second unrelated request.
class ApiLogInterceptor extends Interceptor {
  ApiLogInterceptor({bool? enabled, this.store, this.logger, this.label})
    : enabled = enabled ?? ApiConfig.enableApiLogger;

  /// Whether collection is active. False in production builds.
  final bool enabled;

  /// The shared store the viewer reads. Null means nothing is retained.
  final ApiLogStore? store;

  /// Optional legacy sink, for contexts that do not have the store.
  final void Function(String)? logger;

  /// Distinguishes a refresh token call from an ordinary API request.
  final String? label;

  /// Extra key that carries the log id across an auth replay.
  ///
  /// It lives only on [RequestOptions.extra], which is never sent over the
  /// wire, so adding it cannot change the request.
  static const String logIdExtra = 'api_log_id';

  static const String refreshLabel = 'AUTH / REFRESH';

  static int _sequence = 0;

  final _inFlight = <String, _RequestTrace>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      try {
        _captureRequest(options);
      } catch (_) {
        // Logging must never break the request it is observing.
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      try {
        _captureResponse(response);
      } catch (_) {
        // Ignore logging failures.
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      try {
        _captureError(err);
      } catch (_) {
        // Ignore logging failures.
      }
    }
    handler.next(err);
  }

  void _captureRequest(RequestOptions options) {
    if (store == null && logger == null) {
      return;
    }
    final existingId = options.extra[logIdExtra];
    final id = existingId is String && existingId.isNotEmpty
        ? existingId
        : _nextId();
    options.extra[logIdExtra] = id;

    var trace = _inFlight[id];
    if (trace == null) {
      trace = _RequestTrace(id, DateTime.now());
      _inFlight[id] = trace;
    }

    // A replay caused by a token refresh is the same logical call. Reusing the
    // id keeps one entry instead of logging the original and the retry twice.
    if (existingId == id && store?.contains(id) == true) {
      return;
    }

    final entry = _entryFromOptions(options, trace);
    store?.add(entry);
    if (store == null) {
      _emit('→ ${entry.method} ${entry.url}', title: 'API Request');
    }
  }

  void _captureResponse(Response<dynamic> response) {
    final options = response.requestOptions;
    final id = options.extra[logIdExtra];
    if (id is! String || id.isEmpty) {
      return;
    }
    final trace = _inFlight.remove(id);
    final existing = store?.findById(id);
    if (store == null && logger == null) {
      return;
    }

    final status = response.statusCode;
    final success = status != null && status >= 200 && status < 300;
    final completed =
        (existing ??
                _entryFromOptions(
                  options,
                  trace ?? _RequestTrace(id, DateTime.now()),
                ))
            .copyWith(
              statusCode: status,
              responseHeaders: ApiLogRedactor.redactHeaders(
                response.headers.map,
              ),
              responseBody: ApiLogRedactor.value(response.data),
              responseTimestamp: DateTime.now(),
              durationMs: trace?.durationMs,
              responseSize: _responseSize(response),
              outcome: success ? ApiLogOutcome.success : ApiLogOutcome.failed,
              errorMessage: success ? null : 'HTTP ${status ?? 'unknown'}',
            );

    store?.finish(completed);
    if (store == null) {
      _emit(
        '← ${completed.statusCode} ${completed.method} ${completed.url}'
        ' (${completed.durationMs ?? 0}ms)',
        title: 'API Response',
      );
    }
  }

  void _captureError(DioException error) {
    final options = error.requestOptions;
    final id = options.extra[logIdExtra];
    if (id is! String || id.isEmpty) {
      return;
    }
    final trace = _inFlight.remove(id);
    final existing = store?.findById(id);
    if (store == null && logger == null) {
      return;
    }

    final response = error.response;
    final completed =
        (existing ??
                _entryFromOptions(
                  options,
                  trace ?? _RequestTrace(id, DateTime.now()),
                ))
            .copyWith(
              statusCode: response?.statusCode,
              responseHeaders: ApiLogRedactor.redactHeaders(
                response?.headers.map,
              ),
              responseBody: ApiLogRedactor.value(response?.data),
              responseTimestamp: response == null ? null : DateTime.now(),
              durationMs: trace?.durationMs,
              responseSize: response == null ? null : _responseSize(response),
              dioExceptionType: error.type.name,
              errorMessage: ApiLogRedactor.truncateText(
                error.message ?? error.toString(),
              ),
              stackTrace: ApiLogRedactor.truncateText(
                error.stackTrace.toString(),
              ),
              outcome: ApiLogOutcome.failed,
            );

    store?.finish(completed);
    if (store == null) {
      _emit(
        '✗ ${completed.statusCode ?? completed.dioExceptionType} '
        '${completed.method} ${completed.url} '
        '(${completed.durationMs ?? 0}ms)',
        title: 'API Error',
      );
    }
  }

  ApiLogEntry _entryFromOptions(RequestOptions options, _RequestTrace trace) {
    final uri = options.uri;
    final query = <String, dynamic>{};
    uri.queryParametersAll.forEach((key, values) {
      query[key] = values.length == 1 ? values.first : values;
    });
    final safeQuery = ApiLogRedactor.redactQuery(query);
    final contentType =
        options.contentType ?? options.headers[Headers.contentTypeHeader];

    return ApiLogEntry(
      id: trace.id,
      method: options.method.toUpperCase(),
      url: _redactedUrl(uri, safeQuery),
      endpoint: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: safeQuery,
      requestHeaders: ApiLogRedactor.redactHeaders(options.headers),
      requestBody: ApiLogRedactor.value(options.data),
      requestTimestamp: trace.requestTimestamp,
      requestContentType: contentType?.toString(),
      requestSize: ApiLogRedactor.sizeOf(options.data),
      label: label,
    );
  }

  String _redactedUrl(Uri uri, Map<String, Object?> query) {
    if (query.isEmpty) {
      return uri.removeFragment().toString();
    }
    final pairs = <String>[];
    query.forEach((key, value) {
      if (value is Iterable && value is! String) {
        for (final item in value) {
          pairs.add(
            '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent('$item')}',
          );
        }
      } else {
        pairs.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent('$value')}',
        );
      }
    });
    return uri.replace(query: pairs.join('&')).removeFragment().toString();
  }

  int? _responseSize(Response<dynamic> response) {
    final header = response.headers.value(Headers.contentLengthHeader);
    final fromHeader = header == null ? null : int.tryParse(header);
    return fromHeader ?? ApiLogRedactor.sizeOf(response.data);
  }

  String _nextId() {
    _sequence++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  void _emit(String message, {required String title}) {
    try {
      final sink = logger;
      if (sink != null) {
        sink(message);
      } else {
        superPrint(message, title: title);
      }
    } catch (_) {
      // A failing sink is not allowed to affect the request.
    }
  }
}

class _RequestTrace {
  _RequestTrace(this.id, this.requestTimestamp)
    : _stopwatch = Stopwatch()..start();

  final String id;
  final DateTime requestTimestamp;
  final Stopwatch _stopwatch;

  int get durationMs => _stopwatch.elapsedMilliseconds;
}
