import 'package:dio/dio.dart';

import '../api_config.dart';
import '../token_refresher.dart';
import '../token_storage.dart';
import 'api_auth_interceptor.dart';

/// Exchanges an expired access token for a fresh one, on the caller's behalf.
///
/// The refresh call is made on a client that does not carry this interceptor
/// (see `DioApiService._defaultRefresherFor`), which is what makes recursion
/// structurally impossible: a refresh that itself returns 401 cannot re-enter
/// this code and start a second refresh.
class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor(
    this._storage,
    this._dio,
    this._refresher,
  );

  final TokenStorage _storage;

  /// The app's client, used only to replay the request that failed.
  final Dio _dio;

  /// Mints a new pair from a refresh token.
  ///
  /// Injected rather than built here so the HTTP call lives in one place, with
  /// the rest of the client's configuration, instead of in an interceptor that
  /// would need its own `Dio`.
  final TokenRefresher _refresher;

  /// Invoked when the session cannot be recovered, so the app can clear its
  /// user state and send the resident to the login screen.
  void Function()? onSessionExpired;

  /// The in-flight refresh, shared by every request that hits a 401 while it
  /// runs.
  ///
  /// This is the single-flight guarantee: the second 401 to arrive finds a
  /// non-null future and waits on it instead of starting its own refresh, so a
  /// dashboard that fires six requests at once produces one refresh call, not
  /// six.
  Future<AuthTokens?>? _inFlight;

  /// Marks a request that has already been replayed, so a second 401 on the
  /// same request is reported instead of retried forever.
  static const String retriedExtra = 'auth_retry';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    final shouldHandle =
        err.response?.statusCode == 401 &&
        // Never for a request that opted out of auth: a rejected sign-in is a
        // wrong password, not an expired session.
        options.extra[ApiAuthInterceptor.unauthenticatedExtra] != true &&
        // Never for a request already replayed once.
        options.extra[retriedExtra] != true;

    if (!shouldHandle) {
      handler.next(err);
      return;
    }

    final tokens = await _refreshOnce();

    if (tokens == null) {
      // Refresh failed or there was nothing to refresh with. The stored pair is
      // already cleared; the app is told so it can drop user state and route to
      // login.
      onSessionExpired?.call();
      handler.next(err);
      return;
    }

    try {
      // Replay the original request, preserving its method, url, query,
      // headers and body, with the new bearer and a guard against a second
      // attempt.
      options.extra[retriedExtra] = true;
      options.headers[ApiConfig.authorizationHeader] =
          '${ApiConfig.authScheme} ${tokens.accessToken}';
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      // A 401 here means the new token was rejected too; surface it rather
      // than looping.
      handler.next(retryError);
    }
  }

  /// Runs at most one refresh at a time and returns its result to every caller.
  Future<AuthTokens?> _refreshOnce() {
    return _inFlight ??= _refresh().whenComplete(() {
      // Cleared on completion so the next expiry can refresh again. Without
      // this the app would refresh exactly once for the whole session.
      _inFlight = null;
    });
  }

  Future<AuthTokens?> _refresh() async {
    final current = await _storage.readTokens();
    final refreshToken = current?.refreshToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      // Nothing to refresh with, so the session is over.
      await _storage.clearTokens();
      return null;
    }

    try {
      final tokens = await _refresher.refresh(refreshToken);
      if (tokens == null) {
        await _storage.clearTokens();
        return null;
      }
      // Both tokens are replaced together; keeping the old refresh token would
      // guarantee a second failure at the next expiry.
      await _storage.writeTokens(tokens);
      return tokens;
    } catch (_) {
      await _storage.clearTokens();
      return null;
    }
  }

}
