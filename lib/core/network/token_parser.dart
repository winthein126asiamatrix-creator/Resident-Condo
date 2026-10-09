import 'api_exception.dart';
import 'token_storage.dart';

/// Reads tokens out of a backend response.
///
/// Lives in core because two unrelated callers need it: the refresh
/// interceptor, which parses the refresh response, and the auth feature, which
/// parses the login response. One place means a change to the wire format is a
/// one line change rather than a hunt for duplicated `['accessToken']` lookups.
abstract final class TokenParser {
  /// The token pair in [json].
  ///
  /// Throws [ApiException] when the pair is incomplete, because storing half a
  /// pair would sign the resident out at the first expiry instead of failing
  /// here where the backend response is still in hand.
  static AuthTokens tokensFrom(Object? json) {
    final map = json is Map ? json : const <Object?, Object?>{};
    final access = map['accessToken'];
    final refresh = map['refreshToken'];

    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const ApiException(
        'The sign-in service returned an incomplete session. Please try again.',
        kind: ApiFailureKind.server,
      );
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}