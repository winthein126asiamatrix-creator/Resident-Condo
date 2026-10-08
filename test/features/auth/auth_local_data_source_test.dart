import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:test/features/auth/domain/entities/auth_session.dart';

/// The credential store, exercised against real (mock-backed) SharedPreferences
/// so "Remember me survives a restart" is actually true.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signs in with the correct password', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = AuthLocalDataSource();

    final session = await source.signIn(
      const SignInRequest(username: AuthLocalDataSource.demoUsername, password: AuthLocalDataSource.demoPassword),
    );

    expect(session.username, AuthLocalDataSource.demoUsername);
    expect(session.displayName, isNotEmpty);
  });

  test('rejects a wrong password with a readable message', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = AuthLocalDataSource();

    expect(
      () => source.signIn(
        const SignInRequest(username: AuthLocalDataSource.demoUsername, password: 'not-the-demo-password'),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('rejects an unknown username', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = AuthLocalDataSource();

    expect(
      () => source.signIn(
        const SignInRequest(username: 'nobody', password: AuthLocalDataSource.demoPassword),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('a remembered session survives a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final firstLaunch = AuthLocalDataSource();
    await firstLaunch.signIn(
      const SignInRequest(username: AuthLocalDataSource.demoUsername, password: AuthLocalDataSource.demoPassword),
    );
    await firstLaunch.persistSession(
      const AuthSession(
        username: AuthLocalDataSource.demoUsername,
        displayName: 'Alex Johnson',
        rememberMe: true,
      ),
    );

    // A brand new data source over the same storage, which is a cold app start.
    final afterRestart = AuthLocalDataSource();
    final restored = await afterRestart.restoreSession();

    expect(restored, isNotNull);
    expect(restored!.username, AuthLocalDataSource.demoUsername);
    expect(restored.rememberMe, isTrue);
  });

  test('without remember me nothing is restored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = AuthLocalDataSource();

    await source.signIn(
      const SignInRequest(username: AuthLocalDataSource.demoUsername, password: AuthLocalDataSource.demoPassword),
    );
    await source.persistSession(
      const AuthSession(
        username: AuthLocalDataSource.demoUsername,
        displayName: 'Alex Johnson',
        rememberMe: false,
      ),
    );

    expect(await AuthLocalDataSource().restoreSession(), isNull);
  });

  test('sign out clears the remembered session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = AuthLocalDataSource();
    await source.persistSession(
      const AuthSession(
        username: AuthLocalDataSource.demoUsername,
        displayName: 'Alex Johnson',
        rememberMe: true,
      ),
    );

    await source.signOut();

    expect(await AuthLocalDataSource().restoreSession(), isNull);
  });
}