import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/auth_session.dart';

/// Stores the remembered sign-in details.
///
/// Tokens deliberately do not live here: they are credentials, so they go
/// through the keychain (see `SecureTokenStorage`). What is kept here is
/// non-sensitive: who last signed in, so the login form can greet them by name
/// and the "Remember me" choice survives a restart.
///
/// Credentials are never checked here. Verification belongs to the backend, and
/// a copy of a password in source control is a liability even a demo one.
class AuthLocalDataSource {
  AuthLocalDataSource([SharedPreferences? preferences])
    : _preferences = preferences;

  static const _usernameKey = 'auth.username';
  static const _displayNameKey = 'auth.display_name';

  final SharedPreferences? _preferences;

  SharedPreferences? _resolved;

  /// Resolved on first use rather than in the constructor, because
  /// `SharedPreferences.getInstance` is async and the project's dependency
  /// injection is synchronous.
  Future<SharedPreferences> get _store async =>
      _resolved ??= _preferences ?? await SharedPreferences.getInstance();

  Future<void> persistSession(AuthSession session) async {
    final preferences = await _store;
    if (!session.rememberMe) {
      // Explicitly clear: turning the box off must take effect immediately,
      // not only for sessions created after this point.
      await preferences.remove(_usernameKey);
      await preferences.remove(_displayNameKey);
      return;
    }
    await preferences.setString(_usernameKey, session.username);
    await preferences.setString(_displayNameKey, session.displayName);
  }

  Future<AuthSession?> restoreSession() async {
    final preferences = await _store;
    final username = preferences.getString(_usernameKey);
    if (username == null || username.isEmpty) {
      return null;
    }
    return AuthSession(
      username: username,
      displayName: preferences.getString(_displayNameKey) ?? username,
      rememberMe: true,
    );
  }

  Future<void> signOut() async {
    final preferences = await _store;
    await preferences.remove(_usernameKey);
    await preferences.remove(_displayNameKey);
  }
}