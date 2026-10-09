/// The two tokens the backend issues, kept together.
///
/// They are always written and cleared as a pair so a half-updated session is
/// impossible: an access token without its refresh token would sign the
/// resident out the first time the access token expired.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  /// Short lived, sent as the bearer on every authenticated request.
  final String accessToken;

  /// Longer lived, only ever sent to the refresh endpoint to mint a new pair.
  final String refreshToken;

  /// Never logs the values. A `toString` that included them would put a live
  /// credential into every crash report and debug print that touched a token.
  @override
  String toString() => 'AuthTokens(accessToken: ***, refreshToken: ***)';
}

/// Holds the session tokens between launches.
///
/// An interface rather than a concrete class so the network layer can be pointed
/// at a different store (in-memory for tests, a keychain, an in-house vault)
/// without changing the interceptor that depends on it.
abstract interface class TokenStorage {
  /// The stored tokens, or null when the resident is signed out.
  ///
  /// Async because the backing store may have to be opened first.
  Future<AuthTokens?> readTokens();

  /// Stores [tokens], replacing anything already held.
  ///
  /// Returns whether the write stuck, so a caller that cannot persist a session
  /// can tell the resident instead of pretending it was saved.
  Future<bool> writeTokens(AuthTokens tokens);

  /// Forgets both tokens.
  Future<void> clearTokens();
}