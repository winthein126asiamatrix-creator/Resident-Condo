import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/auth_session.dart';

/// Verifies credentials and stores the remembered session.
///
/// This is the demo credential store, matching the rest of the app's mock data
/// sources: one account, checked in memory, with the "Remember me" choice
/// written to `SharedPreferences` so the behaviour is real even though the
/// backend is not. A production build swaps [verifyCredentials] for an API call
/// and nothing else changes.
class AuthLocalDataSource {
  AuthLocalDataSource([SharedPreferences? preferences])
      : _preferences = preferences;

  static const _usernameKey = 'auth.username';
  static const _displayNameKey = 'auth.display_name';

  /// The account this build ships with. Deliberately visible so the demo is
  /// usable; a real build would never hold a password here.
  static const demoUsername = 'alex';
  static const demoPassword = 'resident123';

  final SharedPreferences? _preferences;

  SharedPreferences? _resolved;

  /// Resolved on first use rather than in the constructor, because
  /// `SharedPreferences.getInstance` is async and the project's dependency
  /// injection is synchronous.
  Future<SharedPreferences> get _store async =>
      _resolved ??= _preferences ?? await SharedPreferences.getInstance();

  Future<AuthSession> signIn(SignInRequest request) async {
    if (!_credentialsMatch(request)) {
      throw const AppException(
        'That username and password combination was not recognised.',
      );
    }
    return AuthSession(
      username: request.username,
      displayName: displayNameFor(request.username),
      // The caller decides this; the data source does not second guess it.
      rememberMe: false,
    );
  }

  bool _credentialsMatch(SignInRequest request) {
    final username = request.username.trim().toLowerCase();
    return username == demoUsername && request.password == demoPassword;
  }

  /// The name shown on the dashboard once signed in.
  String displayNameFor(String username) => switch (username.trim().toLowerCase()) {
        'alex' => 'Alex Johnson',
        _ => username,
      };

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