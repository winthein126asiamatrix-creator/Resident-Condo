import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../../../core/network/token_parser.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../models/auth_user.dart';

/// What a sign-in returned: the tokens that prove the credentials.
class AuthResult {
  const AuthResult({required this.tokens});

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

  /// Signs in and returns the token pair.
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
        },
        options: _service.withoutAuth(),
      );
      return AuthResult(tokens: TokenParser.tokensFrom(response));
    } on ApiException catch (error) {
      throw _translate(error);
    }
  }

  /// The resident behind the stored access token.
  ///
  /// A 401 here is not an error: the refresh interceptor transparently renews
  /// the token and replays this request, so the caller sees a user or a genuine
  /// failure, never an expiry.
  Future<AuthUser> updateMe() async {
    try {
      final response = await _service.get<AuthUser>(
        ApiEndPoints.me,
        parse: AuthUser.parse,
      );
      return response;
    } on ApiException {
      // Unlike sign-in, a rejected profile request is not a credential problem.
      // Re-throw it unchanged so the caller keeps the retryable / unauthorized
      // distinction the network layer already made.
      rethrow;
    }
  }

  /// Updates the signed-in resident's editable profile fields.
  ///
  /// Only fields present in [changes] are sent. The endpoint has been observed
  /// returning either the updated resident or a success message, so the response
  /// is merged into [currentUser] rather than replacing it. Unrelated fields such
  /// as the avatar and unit are therefore preserved when the body is partial.
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    required Map<String, Object?> changes,
  }) async {
    final response = await _service.patch<Object?>(
      ApiEndPoints.me,
      data: changes,
    );
    return AuthUser.mergeProfile(
      response,
      currentUser: currentUser,
      submitted: changes,
    );
  }

  /// Changes the signed-in resident's password.
  ///
  /// The request is authenticated like every other call, so the shared
  /// interceptor adds the bearer token and renews it if needed. The success
  /// body is deliberately not parsed: the endpoint is known to accept the
  /// request, but its success shape has not been confirmed, and a 2xx is
  /// enough to know the password changed.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _service.post<dynamic>(
      ApiEndPoints.changePassword,
      data: <String, Object?>{
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }

  /// Replaces the signed-in resident's avatar.
  ///
  /// The success body is deliberately ignored: the endpoint's response shape has
  /// not been confirmed. A 2xx is enough to know the upload was accepted, and
  /// the caller refreshes `/me` for the canonical profile.
  Future<void> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) async {
    await _service.uploadMultipart<dynamic>(
      ApiEndPoints.avatar,
      files: <String, MultipartFile>{
        'avatar': DioApiService.filePart(
          filePath: filePath,
          filename: filename,
          contentType: _mediaType(mimeType),
        ),
      },
    );
  }

  static DioMediaType? _mediaType(String? mimeType) {
    final value = mimeType?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return DioMediaType.parse(value == 'image/jpg' ? 'image/jpeg' : value);
    } on Object {
      return null;
    }
  }

  /// Revokes the session's refresh token on the backend.
  ///
  /// The call is deliberately unauthenticated: the refresh token is the
  /// credential being revoked, and an expired access token must not trigger a
  /// refresh while the resident is signing out.
  Future<void> logout({
    required String refreshToken,
    required String deviceId,
  }) async {
    await _service.post<dynamic>(
      ApiEndPoints.logout,
      data: <String, Object?>{
        'refresh_token': refreshToken,
        'device_id': deviceId,
      },
      options: _service.withoutAuth(),
    );
  }

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

  /// Turns transport failures into something worth showing a resident.
  ///
  /// A wrong password is the one case with a message the backend chose on
  /// purpose; everything else gets app wording, because a raw status code is not
  /// something to put in front of someone trying to get through their front door.
  /// Turns transport failures into something worth showing a resident.
  ///
  /// A wrong password is the one case with a message the backend chose on
  /// purpose, so it gets the app's own wording. Everything else keeps the
  /// [ApiException] it already is: the message is unchanged, but the caller can
  /// still tell a network failure â€” where the server never answered â€” from a
  /// rejected credential. Unwrapping it into a bare [AppException] would lose
  /// that distinction and make every failure look like a sign-out.
  static AppException _translate(ApiException error) {
    return switch (error.statusCode) {
      400 || 401 || 403 => const AppException(
        'That username and password combination was not recognised.',
      ),
      _ => error,
    };
  }
}
