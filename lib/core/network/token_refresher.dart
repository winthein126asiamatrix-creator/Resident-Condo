import 'package:dio/dio.dart';

import '../utils/super_print.dart';
import 'api_config.dart';
import 'api_end_points.dart';
import 'api_exception.dart';
import 'token_parser.dart';
import 'token_storage.dart';

/// A refresh failure that does not prove the stored credentials are invalid.
///
/// Network failures, timeouts and backend 5xx responses can all interrupt a
/// refresh while the refresh token itself is still perfectly usable. The
/// interceptor must keep the session and surface a retryable error for these,
/// rather than signing the resident out.
class TokenRefreshException implements Exception {
  const TokenRefreshException(this.cause);

  final Object cause;

  @override
  String toString() => 'TokenRefreshException($cause)';
}

/// Exchanges a refresh token for a new pair.
///
/// Deliberately takes its [Dio] as a constructor argument rather than building
/// one. The app hands it a bare client with no interceptors installed, which is
/// what makes a recursive refresh impossible; a test can hand it a client wired
/// to a fake transport and assert on the request without a network call.
class TokenRefresher {
  const TokenRefresher(this._dio);

  final Dio _dio;

  /// Mints a new pair, or returns null when the backend refuses.
  ///
  /// A failure is null rather than an exception: every caller wants the same
  /// thing from it, which is to end the session.
  Future<AuthTokens?> refresh(String refreshToken) async {
    try {
      superPrint({
        'path': ApiEndPoints.refreshToken,
      }, title: 'Token Refresh: Request');
      final response = await _dio.post<Object?>(
        ApiEndPoints.refreshToken,
        data: <String, Object?>{
          'refresh_token': refreshToken,
          // 'expiresInMins': ApiConfig.tokenExpiresInMins,
        },
      );
      superPrint({
        'path': ApiEndPoints.refreshToken,
        'status': response.statusCode,
      }, title: 'Token Refresh: Response');
      return TokenParser.tokensFrom(response.data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      superPrint({
        'path': ApiEndPoints.refreshToken,
        'error': 'request failed',
      }, title: 'Token Refresh: Failed');
      // Only a clear rejection of the refresh credential proves the session is
      // over. Anything else (no response, timeout, 5xx) may be temporary and
      // must not destroy a still-valid pair.
      if (_isInvalidCredentialResponse(status)) {
        return null;
      }
      throw TokenRefreshException(error);
    } on ApiException {
      // A 2xx with an unusable body is a malformed refresh response, not proof
      // of a temporary network problem.
      superPrint({
        'path': ApiEndPoints.refreshToken,
        'error': 'request failed',
      }, title: 'Token Refresh: Failed');
      return null;
    } catch (error) {
      superPrint({
        'path': ApiEndPoints.refreshToken,
        'error': 'request failed',
      }, title: 'Token Refresh: Failed');
      throw TokenRefreshException(error);
    }
  }

  static bool _isInvalidCredentialResponse(int? status) =>
      status == 400 || status == 401 || status == 403;

  /// A refresher with a client of its own, carrying no interceptors.
  ///
  /// Used by [DioApiService] in the app, where an interceptor-driven refresh
  /// would otherwise be able to re-enter itself.
  static TokenRefresher bare(
    String baseUrl, {
    List<Interceptor> interceptors = const <Interceptor>[],
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    if (interceptors.isNotEmpty) {
      dio.interceptors.addAll(interceptors);
    }
    return TokenRefresher(dio);
  }
}
