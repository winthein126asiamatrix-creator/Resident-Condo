import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

/// [TokenStorage] backed by the platform keychain: the iOS keychain and
/// EncryptedSharedPreferences on Android.
///
/// Chosen over `SharedPreferences` because these are live credentials. Plain
/// preferences are readable from a backup or a rooted device, so a token in
/// there would outlive the session it belongs to.
///
/// Every method swallows a storage failure. A keychain that will not open, or a
/// platform channel missing in a unit test, must not take the network layer down
/// with it; the worst case is that the resident signs in again.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  /// Namespaced so a future key in the same keychain cannot collide.
  static const _accessTokenKey = 'condo.auth.access_token';
  static const _refreshTokenKey = 'condo.auth.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> readTokens() async {
    try {
      final access = await _storage.read(key: _accessTokenKey);
      final refresh = await _storage.read(key: _refreshTokenKey);
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
        // Half a pair is as good as none: it would fail on first refresh.
        return null;
      }
      return AuthTokens(accessToken: access, refreshToken: refresh);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> writeTokens(AuthTokens tokens) async {
    try {
      await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
      await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {
      // The tokens are unusable either way once the session has ended.
    }
  }
}