import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Why a request failed, in terms the UI can act on.
///
/// The existing controllers already catch [AppException] and surface
/// `error.message`, so mapping network failures onto a subclass of it means no
/// controller had to change to handle a dropped connection or a 500.
enum ApiFailureKind {
  /// No usable connection, DNS failure, or the host refused the socket.
  network,

  /// The request was sent but the answer never arrived in time.
  timeout,

  /// The backend answered with a non-success status.
  server,

  /// The session is missing or expired and the resident has to sign in again.
  unauthorized,

  /// Signed in, but not allowed to do this.
  forbidden,

  /// The addressed record does not exist.
  notFound,

  /// The backend rejected the payload.
  validation,

  /// Anything that does not fit the categories above.
  unknown,
}

/// A failure the backend described inside a JSON-RPC envelope.
///
/// Carries the decoded envelope so [ApiException.from] can read the backend's
/// own message out of it, instead of the generic "something went wrong".
class OdooEnvelopeError implements Exception {
  const OdooEnvelopeError(this.envelope);

  final Map<Object?, Object?> envelope;

  /// The backend's message, preferring the nested `error.data.message` that
  /// Odoo puts there over the generic `error.message` header.
  String get message {
    final error = envelope['error'];
    if (error is Map) {
      final details = error['data'];
      if (details is Map) {
        final nested = details['message'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
      final header = error['message'];
      if (header is String && header.trim().isNotEmpty) {
        return header.trim();
      }
    }
    return 'The server rejected the request.';
  }

  /// The Odoo exception name, useful for diagnostics.
  String? get name {
    final error = envelope['error'];
    if (error is Map) {
      final details = error['data'];
      if (details is Map) {
        final value = details['name'];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  @override
  String toString() => message;
}

/// A failed backend call.
///
/// Extends [AppException] rather than replacing it, so the feature controllers'
/// existing `on AppException catch (error)` handlers keep working and the UI
/// never sees a raw [DioException].
class ApiException extends AppException {
  const ApiException(
    super.message, {
    this.kind = ApiFailureKind.unknown,
    this.statusCode,
    this.code,
  });

  final ApiFailureKind kind;

  /// HTTP status, when the backend answered at all.
  final int? statusCode;

  /// Backend specific error code, e.g. the Odoo exception name.
  final String? code;

  /// True when the failure is worth retrying rather than reporting.
  bool get isRetryable =>
      kind == ApiFailureKind.network || kind == ApiFailureKind.timeout;

  /// True when the app should send the resident back to the login screen.
  bool get isUnauthorized => kind == ApiFailureKind.unauthorized;

  /// Translates a transport level failure into something readable.
  ///
  /// Never returns null: a failure always becomes an [ApiException] so a
  /// dropped request can never be mistaken for a successful one.
  static ApiException from(Object error, {int? statusCode}) {
    if (error is ApiException) {
      return error;
    }
    if (error is OdooEnvelopeError) {
      // A 200 that still carried an error envelope: the backend's own words
      // win over anything generic.
      return ApiException(
        error.message,
        kind: _kindFor(statusCode) == ApiFailureKind.unknown
            ? ApiFailureKind.server
            : _kindFor(statusCode),
        statusCode: statusCode,
        code: error.name,
      );
    }
    if (error is DioException) {
      return _fromDio(error);
    }
    if (error is SocketException) {
      return const ApiException(
        'No connection. Check your network and try again.',
        kind: ApiFailureKind.network,
      );
    }
    return ApiException(
      'Something went wrong. Please try again.',
      kind: ApiFailureKind.unknown,
      statusCode: statusCode,
    );
  }

  static ApiException _fromDio(DioException error) {
    final status = error.response?.statusCode;
    // A JSON-RPC call can answer 200 and still carry an error object, so the
    // envelope is inspected before the status is trusted.
    final rpcError = _rpcErrorOf(error.response?.data);
    if (rpcError != null) {
      return ApiException(
        rpcError,
        kind: _kindFor(status),
        statusCode: status,
        code: 'odoo',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'The server took too long to respond. Please try again.',
          kind: ApiFailureKind.timeout,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const ApiException(
          'No connection. Check your network and try again.',
          kind: ApiFailureKind.network,
        );
      case DioExceptionType.cancel:
        return const ApiException(
          'Request cancelled.',
          kind: ApiFailureKind.unknown,
        );
      case DioExceptionType.badResponse:
        return ApiException(
          _messageForStatus(status),
          kind: _kindFor(status),
          statusCode: status,
        );
      case DioExceptionType.unknown:
      // Newer Dio versions add transport outcomes; treating an unfamiliar one
      // as unknown keeps this compiling and the failure visible.
      default:
        return ApiException(
          'Something went wrong. Please try again.',
          kind: ApiFailureKind.unknown,
          statusCode: status,
        );
    }
  }

  /// The backend's own message, when it sent one inside an error envelope.
  static String? _rpcErrorOf(Object? data) {
    if (data is! Map) {
      return null;
    }
    final error = data['error'];
    if (error is! Map) {
      return null;
    }
    // Odoo nests the useful text under `error.data.message` and repeats it at
    // `error.message`; either is better than a generic failure.
    final details = error['data'];
    if (details is Map) {
      final message = details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return null;
  }

  static ApiFailureKind _kindFor(int? status) => switch (status) {
    401 => ApiFailureKind.unauthorized,
    403 => ApiFailureKind.forbidden,
    404 => ApiFailureKind.notFound,
    422 => ApiFailureKind.validation,
    final int s when s >= 500 => ApiFailureKind.server,
    _ => ApiFailureKind.unknown,
  };

  static String _messageForStatus(int? status) => switch (status) {
    400 => 'That request was not valid.',
    401 => 'Your session has expired. Please sign in again.',
    403 => 'You do not have access to this.',
    404 => 'That information is no longer available.',
    409 => 'That has already changed. Please refresh and try again.',
    422 => 'Please check the details and try again.',
    final int s when s >= 500 =>
      'The server had a problem. Please try again shortly.',
    _ => 'Something went wrong. Please try again.',
  };
}
