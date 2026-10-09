import 'package:dio/dio.dart';

import '../api_config.dart';
import '../token_storage.dart';

/// Attaches the session token to outgoing requests.
///
/// This interceptor does nothing on the way back. A 401 is a normal part of a
/// session's life now that access tokens expire, and
/// [TokenRefreshInterceptor] is what recovers from it: clearing the stored
/// tokens here would destroy the refresh token before the refresh could read it,
/// so an ordinary expiry would sign the resident out.
class ApiAuthInterceptor extends Interceptor {
  ApiAuthInterceptor(this._storage);

  final TokenStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[unauthenticatedExtra] != true) {
      final tokens = await _storage.readTokens();
      final token = tokens?.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers[ApiConfig.authorizationHeader] =
            '${ApiConfig.authScheme} $token';
      }
    }
    handler.next(options);
  }

  /// Key set in `Options.extra` to skip the header.
  ///
  /// A string constant rather than a bare string so a typo is a compile error
  /// instead of a silently unauthenticated request.
  static const String unauthenticatedExtra = 'skipAuthorization';
}