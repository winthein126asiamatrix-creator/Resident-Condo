import 'token_storage.dart';

/// A [TokenStorage] that keeps the pair in memory only.
///
/// Backs a session signed in without Remember Me. The tokens stay readable for
/// the lifetime of the process — every request still sends the bearer and the
/// refresh interceptor can still renew it — but nothing reaches disk, so a
/// process restart starts with no session to restore.
///
/// Deliberately not a [SecureTokenStorage]: a pair that can be read back after
/// the process dies is exactly what "don't remember me" must avoid.
class InMemoryTokenStorage implements TokenStorage {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> readTokens() async => _tokens;

  @override
  Future<bool> writeTokens(AuthTokens tokens) async {
    _tokens = tokens;
    return true;
  }

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }
}
