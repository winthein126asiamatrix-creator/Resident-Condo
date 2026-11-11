import 'package:get/get.dart';

/// The state of one API call captured by the dev logger.
enum ApiLogOutcome { pending, success, failed }

/// One request and, once it finishes, its response or error.
///
/// The object is immutable and the store replaces it by [id] when the outcome
/// arrives. That keeps a request and its response paired even when several
/// calls are in flight and their responses come back out of order.
class ApiLogEntry {
  const ApiLogEntry({
    required this.id,
    required this.method,
    required this.url,
    required this.endpoint,
    required this.requestTimestamp,
    this.queryParameters = const <String, Object?>{},
    this.requestHeaders = const <String, String>{},
    this.requestBody,
    this.requestContentType,
    this.requestSize,
    this.label,
    this.statusCode,
    this.responseHeaders = const <String, String>{},
    this.responseBody,
    this.responseTimestamp,
    this.durationMs,
    this.responseSize,
    this.dioExceptionType,
    this.errorMessage,
    this.stackTrace,
    this.outcome = ApiLogOutcome.pending,
  });

  final String id;
  final String method;
  final String url;
  final String endpoint;
  final Map<String, Object?> queryParameters;
  final Map<String, String> requestHeaders;
  final Object? requestBody;
  final DateTime requestTimestamp;
  final String? requestContentType;
  final int? requestSize;

  /// Extra origin marker, used for `AUTH / REFRESH` calls.
  final String? label;

  final int? statusCode;
  final Map<String, String> responseHeaders;
  final Object? responseBody;
  final DateTime? responseTimestamp;
  final int? durationMs;
  final int? responseSize;
  final String? dioExceptionType;
  final String? errorMessage;
  final String? stackTrace;
  final ApiLogOutcome outcome;

  bool get isPending => outcome == ApiLogOutcome.pending;
  bool get isSuccess => outcome == ApiLogOutcome.success;
  bool get isFailed => outcome == ApiLogOutcome.failed;

  ApiLogEntry copyWith({
    int? statusCode,
    Map<String, String>? responseHeaders,
    Object? responseBody,
    DateTime? responseTimestamp,
    int? durationMs,
    int? responseSize,
    String? dioExceptionType,
    String? errorMessage,
    String? stackTrace,
    ApiLogOutcome? outcome,
  }) {
    return ApiLogEntry(
      id: id,
      method: method,
      url: url,
      endpoint: endpoint,
      queryParameters: queryParameters,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      requestTimestamp: requestTimestamp,
      requestContentType: requestContentType,
      requestSize: requestSize,
      label: label,
      statusCode: statusCode ?? this.statusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      responseTimestamp: responseTimestamp ?? this.responseTimestamp,
      durationMs: durationMs ?? this.durationMs,
      responseSize: responseSize ?? this.responseSize,
      dioExceptionType: dioExceptionType ?? this.dioExceptionType,
      errorMessage: errorMessage ?? this.errorMessage,
      stackTrace: stackTrace ?? this.stackTrace,
      outcome: outcome ?? this.outcome,
    );
  }
}

/// The one in-memory API log shared by the whole dev session.
///
/// The store only exists when the app is built for the dev flavor. Production
/// never registers it, so nothing is collected or retained there.
class ApiLogStore extends GetxService {
  ApiLogStore({this.maxEntries = 200})
    : assert(maxEntries > 0, 'maxEntries must be positive');

  final int maxEntries;
  final logs = <ApiLogEntry>[].obs;
  final isOverlayVisible = true.obs;

  void showOverlay() => isOverlayVisible.value = true;

  void hideOverlay() => isOverlayVisible.value = false;

  ApiLogEntry? findById(String id) {
    for (final log in logs) {
      if (log.id == id) {
        return log;
      }
    }
    return null;
  }

  bool contains(String id) => findById(id) != null;

  void add(ApiLogEntry entry) {
    logs.add(entry);
    if (logs.length > maxEntries) {
      logs.removeRange(0, logs.length - maxEntries);
    }
  }

  /// Replaces the pending entry with the finished one.
  ///
  /// A request that was already evicted by the limit is left alone rather than
  /// jumping back into the list out of order.
  void finish(ApiLogEntry entry) {
    final index = logs.indexWhere((log) => log.id == entry.id);
    if (index == -1) {
      return;
    }
    logs[index] = entry;
  }

  void clear() => logs.clear();

  int get total => logs.length;
  int get successCount => logs.where((log) => log.isSuccess).length;
  int get failedCount => logs.where((log) => log.isFailed).length;
  int get pendingCount => logs.where((log) => log.isPending).length;

  double? get averageDurationMs {
    var totalMs = 0;
    var count = 0;
    for (final log in logs) {
      final duration = log.durationMs;
      if (duration == null) {
        continue;
      }
      totalMs += duration;
      count++;
    }
    return count == 0 ? null : totalMs / count;
  }
}
