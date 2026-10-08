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
  });

  /// The account that was used to sign in.
  final String username;

  /// The name to greet the resident by on the dashboard.
  final String displayName;

  /// Whether the resident asked to stay signed in, which decides if the
  /// session is restored on the next launch.
  final bool rememberMe;
}