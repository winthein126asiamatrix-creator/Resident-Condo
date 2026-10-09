/// A resident's sign-in credentials.
///
/// Deliberately holds no password: the value is passed straight to the
/// repository and never stored, logged or kept on the controller, so it cannot
/// leak into a widget tree dump or an error report.
class SignInRequest {
  const SignInRequest({required this.username, required this.password});

  final String username;
  final String password;

  @override
  String toString() => 'SignInRequest(username: $username)';
}

/// The result of a successful sign-in.
class AuthSession {
  const AuthSession({
    required this.username,
    required this.displayName,
    required this.rememberMe,
    this.user,
  });

  /// The account that was used to sign in.
  final String username;

  /// The name to greet the resident by on the dashboard.
  final String displayName;

  /// Whether the resident asked to stay signed in, which decides if the
  /// session is restored on the next launch.
  final bool rememberMe;

  /// The backend's record for the resident, when one came with the session.
  ///
  /// Nullable because the domain layer stays free of the data layer's model; a
  /// session restored from storage carries the name and nothing else.
  final Object? user;

  AuthSession copyWith({
    String? username,
    String? displayName,
    bool? rememberMe,
    Object? user,
  }) {
    return AuthSession(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      rememberMe: rememberMe ?? this.rememberMe,
      user: user ?? this.user,
    );
  }
}