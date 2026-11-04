import 'package:dio/dio.dart';

import '../../utils/super_print.dart';
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
  TokenRefreshInterceptor(this._storage, this._dio, this._refresher);

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
  Future<_RefreshResult>? _inFlight;

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

    superPrint({
      'path': options.path,
      'status': err.response?.statusCode,
    }, title: 'Token Refresh: 401 Detected');
    superPrint({'path': options.path}, title: 'Token Refresh: Started');

    final result = await _refreshOnce();

    final tokens = result.tokens;
    if (tokens == null) {
      if (result.isTransient) {
        // The refresh could not complete, but nothing proved the session is
        // invalid. Keep the stored pair and let the caller retry later.
        handler.next(_transientError(err, result.cause));
        return;
      }
      // Refresh was rejected or there was nothing to refresh with. The stored
      // pair is already cleared; the app is told so it can drop user state and
      // route to login.
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

      // Dio finalizes a FormData body when it sends it, so the same instance
      // cannot be sent again. Clone it before replaying; otherwise a multipart
      // request that gets a 401 could never be retried.
      final body = options.data;
      if (body is FormData) {
        options.data = body.clone();
      } else if (body is Stream) {
        // A one-shot stream cannot be replayed safely.
        handler.next(
          DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            error: StateError(
              'The request body is a stream and cannot be replayed after a '
              'token refresh.',
            ),
          ),
        );
        return;
      }

      superPrint({
        'method': options.method,
        'path': options.path,
      }, title: 'Token Refresh: Retrying');
      final response = await _dio.fetch<dynamic>(options);
      superPrint({
        'path': options.path,
        'status': response.statusCode,
      }, title: 'Token Refresh: Retry Result');
      handler.resolve(response);
    } on DioException catch (retryError) {
      // A 401 here means the new token was rejected too; surface it rather
      // than looping.
      handler.next(retryError);
    }
  }

  /// Re-expresses a temporary refresh failure against the original request.
  ///
  /// The caller sees a retryable network/server error instead of a 401, so a
  /// dropped connection during refresh cannot be mistaken for an invalid
  /// session.
  DioException _transientError(DioException original, Object? cause) {
    if (cause is DioException) {
      return DioException(
        requestOptions: original.requestOptions,
        response: cause.response,
        type: cause.type,
        error: cause.error,
        message: cause.message,
        stackTrace: cause.stackTrace,
      );
    }
    return DioException(
      requestOptions: original.requestOptions,
      type: DioExceptionType.unknown,
      error: cause,
      message: 'The session could not be refreshed. Please try again.',
    );
  }

  /// Runs at most one refresh at a time and returns its result to every caller.
  Future<_RefreshResult> _refreshOnce() {
    return _inFlight ??= _refresh().whenComplete(() {
      // Cleared on completion so the next expiry can refresh again. Without
      // this the app would refresh exactly once for the whole session.
      _inFlight = null;
    });
  }

  Future<_RefreshResult> _refresh() async {
    final current = await _storage.readTokens();
    final refreshToken = current?.refreshToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      // Nothing to refresh with, so the session is over.
      superPrint({
        'reason': 'no refresh token in storage',
      }, title: 'Token Refresh: Failed');
      await _storage.clearTokens();
      return const _RefreshResult.invalid();
    }

    try {
      final tokens = await _refresher.refresh(refreshToken);
      if (tokens == null) {
        superPrint({
          'reason': 'refresh request returned no tokens',
        }, title: 'Token Refresh: Failed');
        await _storage.clearTokens();
        return const _RefreshResult.invalid();
      }
      // Both tokens are replaced together; keeping the old refresh token would
      // guarantee a second failure at the next expiry.
      final saved = await _storage.writeTokens(tokens);
      if (!saved) {
        // The new pair was minted but could not be persisted. Report a
        // temporary failure rather than pretending the session was renewed.
        superPrint({
          'reason': 'could not save refreshed tokens',
        }, title: 'Token Refresh: Failed');
        return const _RefreshResult.transient(null);
      }
      superPrint({'tokensExist': true}, title: 'Token Refresh: Tokens Saved');
      return _RefreshResult.success(tokens);
    } on TokenRefreshException catch (error) {
      // Network/timeout/5xx: keep the old pair and let the caller retry.
      superPrint({
        'reason': 'temporary refresh failure',
      }, title: 'Token Refresh: Failed');
      return _RefreshResult.transient(error.cause);
    } catch (_) {
      superPrint({
        'reason': 'exception during refresh',
      }, title: 'Token Refresh: Failed');
      await _storage.clearTokens();
      return const _RefreshResult.invalid();
    }
  }
}

/// The outcome of one shared refresh attempt.
class _RefreshResult {
  const _RefreshResult.success(AuthTokens this.tokens)
    : isTransient = false,
      cause = null;

  const _RefreshResult.invalid()
    : tokens = null,
      isTransient = false,
      cause = null;

  const _RefreshResult.transient(this.cause)
    : tokens = null,
      isTransient = true;

  final AuthTokens? tokens;

  /// True when the refresh could not complete for a temporary reason.
  final bool isTransient;

  final Object? cause;
}
