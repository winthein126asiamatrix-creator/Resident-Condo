import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'interceptors/api_auth_interceptor.dart';
import 'interceptors/api_log_interceptor.dart';
import 'interceptors/token_refresh_interceptor.dart';
import 'token_refresher.dart';
import 'token_storage.dart';

/// Parses a decoded JSON value into a model.
///
/// Kept as a function so a model decides how it is built, the same way the
/// feature models in `data/models` already do.
typedef JsonParser<T> = T Function(Object? json);

/// The app's single HTTP client.
///
/// Every network call goes through here, which is what keeps the base URL,
/// timeouts, headers, logging and error translation in one place instead of
/// being repeated per feature.
///
/// Responses are unwrapped from the Odoo JSON-RPC envelope when the body looks
/// like one, and handed back otherwise, so the same client serves both RPC and
/// plain REST endpoints. Failures always surface as [ApiException], which is an
/// [AppException] the feature controllers already handle.
class DioApiService {
DioApiService({
    required TokenStorage tokenStorage,
    Dio? dio,
    String baseUrl = ApiConfig.baseUrl,
    TokenRefresher? tokenRefresher,
  }) : _dio = dio ?? Dio(),
       _tokenStorage = tokenStorage,
       _authInterceptor = ApiAuthInterceptor(tokenStorage) {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      // Anything outside a 200 is an error, so a 500 never gets treated as a
      // successful payload.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    );
    _refreshInterceptor = TokenRefreshInterceptor(
      tokenStorage,
      _dio,
      tokenRefresher ?? TokenRefresher.bare(baseUrl),
    );
    _dio.interceptors.addAll(<Interceptor>[
      // Order matters: the bearer has to be attached before the log interceptor
      // prints the headers, and the refresh interceptor must see a request the
      // auth interceptor has already finished with.
      _authInterceptor,
      ApiLogInterceptor(),
      _refreshInterceptor,
    ]);
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final ApiAuthInterceptor _authInterceptor;
  late final TokenRefreshInterceptor _refreshInterceptor;

  /// The underlying client, for anything this wrapper does not cover.
  Dio get client => _dio;

  /// Called when the session cannot be recovered by refreshing, so the app can
  /// drop its user state and return to the login screen.
  set onSessionExpired(void Function()? callback) =>
      _refreshInterceptor.onSessionExpired = callback;

  /// The live base URL, for diagnostics.
  String get baseUrl => _dio.options.baseUrl;

  // --- Verbs ---------------------------------------------------------------

  /// GET, with [query] as the query string and the response parsed by [parse].
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    JsonParser<T>? parse,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: options,
      cancelToken: cancelToken,
    ),
    parse: parse,
  );

  /// POST, with [data] serialised as the JSON body.
  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    JsonParser<T>? parse,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: options,
      cancelToken: cancelToken,
    ),
    parse: parse,
  );

  /// PUT, for a full replacement of a record.
  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    JsonParser<T>? parse,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => _dio.put<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: options,
      cancelToken: cancelToken,
    ),
    parse: parse,
  );

  /// PATCH, for a partial update.
  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    JsonParser<T>? parse,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => _dio.patch<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: options,
      cancelToken: cancelToken,
    ),
    parse: parse,
  );

  /// DELETE.
  Future<T> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    JsonParser<T>? parse,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => _dio.delete<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: options,
      cancelToken: cancelToken,
    ),
    parse: parse,
  );

  /// Uploads files as multipart/form-data.
  ///
  /// [fields] carries the non-file form values and [files] the documents keyed
  /// by the form field each one belongs to, so an upload with two photos and a
  /// description is unambiguous.
  Future<T> uploadMultipart<T>(
    String path, {
    Map<String, dynamic> fields = const <String, dynamic>{},
    Map<String, MultipartFile> files = const <String, MultipartFile>{},
    JsonParser<T>? parse,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) {
    final form = FormData.fromMap(<String, dynamic>{...fields, ...files});
    return _send<T>(
      () => _dio.post<dynamic>(
        path,
        data: form,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(contentType: Headers.multipartFormDataContentType),
      ),
      parse: parse,
    );
  }

  /// A file on disk, ready for [uploadMultipart].
  ///
  /// Used with the key it is stored under in the `files` map:
  ///
  /// ```dart
  /// await service.uploadMultipart<void>(
  ///   ApiEndPoints.maintenancePhotos(id),
  ///   files: {
  ///     'photo': DioApiService.filePart(filePath: photo.path),
  ///   },
  /// );
  /// ```
  static MultipartFile filePart({
    required String filePath,
    String? filename,
    DioMediaType? contentType,
  }) {
    return MultipartFile.fromFileSync(
      filePath,
      filename: filename,
      contentType: contentType,
    );
  }

  /// Marks the next call as not needing the session token.
  ///
  /// Used by sign in and sign out, where attaching a stale token would be wrong.
  Options withoutAuth() => Options(
    extra: <String, dynamic>{ApiAuthInterceptor.unauthenticatedExtra: true},
  );

  // --- Internals -----------------------------------------------------------

  /// Runs a request and turns it into `T`, or throws [ApiException].
  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request, {
    JsonParser<T>? parse,
  }) async {
    try {
      final response = await request();
      final payload = _unwrap(response.data, response.statusCode);
      // A void call over a body-less response is a success, not a type error.
      if (payload == null && parse == null && _isVoid<T>()) {
        return null as T;
      }
      return _decode<T>(payload, parse);
    } on ApiException {
      rethrow;
    } catch (error) {
      // Anything Dio did not recognise still becomes an ApiException, so a
      // failure can never be mistaken for a successful empty response.
      throw ApiException.from(error);
    }
  }

  /// True when the caller asked for no value, as `delete<void>` does.
  ///
  /// `null` is a legal value for any nullable type, so this also holds for
  /// `delete<String?>()`; the alternative, rejecting an empty body outright,
  /// would break the many endpoints that legitimately answer 204.
  static bool _isVoid<T>() => null is T;

  /// Unwraps the JSON-RPC envelope when present.
  ///
  /// Odoo answers `{"jsonrpc":"2.0","id":1,"result":{...}}` on success and
  /// `{"jsonrpc":"2.0","id":1,"error":{...}}` on failure. A plain REST body has
  /// neither key and is returned untouched, so one client serves both shapes
  /// without the caller having to care.
  ///
  /// The `jsonrpc` marker is what decides, not merely the presence of `error`:
  /// an ordinary record may legitimately have an `error` field of its own, and
  /// treating that as a transport failure would reject valid data.
  ///
  /// A 200 that still carries an error object is a failure, and is handed to
  /// [ApiException.from] so the backend's own message survives.
  static Object? _unwrap(Object? data, int? status) {
    if (data is Map && data['jsonrpc'] != null) {
      if (data.containsKey('error')) {
        throw ApiException.from(OdooEnvelopeError(data), statusCode: status);
      }
      if (data.containsKey('result')) {
        return data['result'];
      }
    }
    return data;
  }

  T _decode<T>(Object? json, JsonParser<T>? parse) {
    if (parse != null) {
      return parse(json);
    }
    if (json is T) {
      return json;
    }
    // Nothing to parse into and the body is not already the right type: say so
    // rather than handing back a wrong-typed success.
    throw ApiException(
      'The server returned an unexpected response.',
      kind: ApiFailureKind.unknown,
    );
  }

  /// The tokens currently held, for diagnostics and session checks.
  ///
  /// Returns the pair rather than the access token alone, because "is the
  /// resident signed in" is only meaningful when both are present.
  Future<AuthTokens?> get currentTokens => _tokenStorage.readTokens();
}
