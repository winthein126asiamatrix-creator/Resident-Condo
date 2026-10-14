import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'condo.auth.access_token';
  static const _refreshTokenKey = 'condo.auth.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> readTokens() async {
    try {
      final access = await _storage.read(key: _accessTokenKey);
      final refresh = await _storage.read(key: _refreshTokenKey);
      if (access == null ||
          access.isEmpty ||
          refresh == null ||
          refresh.isEmpty) {
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
