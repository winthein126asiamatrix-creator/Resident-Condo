import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../../../core/network/token_parser.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../models/auth_user.dart';

/// What a sign-in returned: who signed in, and the tokens that prove it.
class AuthResult {
  const AuthResult({required this.user, required this.tokens});

  final AuthUser user;
  final AuthTokens tokens;
}

/// Talks to the backend's session endpoints.
///
/// Uses the app's shared [DioApiService] rather than a client of its own, so
/// base URL, timeouts, error translation and refresh all behave the same here as
/// they do for the rest of the app.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._service);

  final DioApiService _service;

  /// Signs in and returns the resident plus their token pair.
  ///
  /// `withoutAuth` matters here: a stale token from an expired session must not
  /// be sent to the sign-in endpoint, and it also stops a rejected password
  /// (which the backend answers with 401) from triggering a pointless refresh.
  Future<AuthResult> signIn(SignInRequest request) async {
    try {
      final response = await _service.post<Map<String, dynamic>>(
        ApiEndPoints.login,
        data: <String, Object?>{
          'username': request.username,
          'password': request.password,
          // Short lived during development so the refresh path is exercised
          // constantly rather than only in production.
          'expiresInMins': ApiConfig.tokenExpiresInMins,
        },
        options: _service.withoutAuth(),
      );
      return AuthResult(
        user: _userFrom(response),
        tokens: TokenParser.tokensFrom(response),
      );
    } on ApiException catch (error) {
      throw _translate(error);
    }
  }

  /// The resident behind the stored access token.
  ///
  /// A 401 here is not an error: the refresh interceptor transparently renews
  /// the token and replays this request, so the caller sees a user or a genuine
  /// failure, never an expiry.
  Future<AuthUser> currentUser() async {
    try {
      final response = await _service.get<AuthUser>(
        ApiEndPoints.me,
        parse: AuthUser.parse,
      );
      return response;
    } on ApiException catch (error) {
      throw _translate(error);
    }
  }

  /// Exchanges a refresh token for a new pair.
  ///
  /// Not used by the automatic 401 handler, which does its refresh inside the
  /// interceptor so the logic exists once. This is here for the flows that need
  /// to renew deliberately, such as validating a stored session on startup when
  /// no authenticated request is in flight.
  Future<AuthTokens?> refresh(String refreshToken) async {
    try {
      final response = await _service.post<Map<String, dynamic>>(
        ApiEndPoints.refreshToken,
        data: <String, Object?>{
          'refreshToken': refreshToken,
          'expiresInMins': ApiConfig.tokenExpiresInMins,
        },
        options: _service.withoutAuth(),
      );
      return TokenParser.tokensFrom(response);
    } on ApiException {
      return null;
    }
  }

  static AuthUser _userFrom(Map<String, dynamic> response) {
    final raw = response['user'];
    // Some backends nest the profile under `user` and some return it flat;
    // accept either so a change of shape does not break sign-in.
    final record = raw is Map
        ? Map<String, dynamic>.from(raw)
        : response;
    return AuthUser.fromJson(record);
  }

  /// Turns transport failures into something worth showing a resident.
  ///
  /// A wrong password is the one case with a message the backend chose on
  /// purpose; everything else gets app wording, because a raw status code is not
  /// something to put in front of someone trying to get through their front door.
  static AppException _translate(ApiException error) {
    return switch (error.statusCode) {
      400 || 401 || 403 => const AppException(
        'That username and password combination was not recognised.',
      ),
      _ => AppException(error.message),
    };
  }
}