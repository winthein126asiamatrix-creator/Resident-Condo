import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_end_points.dart';
import 'token_parser.dart';
import 'token_storage.dart';

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
      final response = await _dio.post<Object?>(
        ApiEndPoints.refreshToken,
        data: <String, Object?>{
          'refreshToken': refreshToken,
          'expiresInMins': ApiConfig.tokenExpiresInMins,
        },
      );
      return TokenParser.tokensFrom(response.data);
    } catch (_) {
      return null;
    }
  }

  /// A refresher with a client of its own, carrying no interceptors.
  ///
  /// Used by [DioApiService] in the app, where an interceptor-driven refresh
  /// would otherwise be able to re-enter itself.
  static TokenRefresher bare(String baseUrl) {
    return TokenRefresher(
      Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      ),
    );
  }
}