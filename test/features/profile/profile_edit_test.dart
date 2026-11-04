import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/auth/domain/entities/auth_session.dart';
import 'package:test/features/auth/domain/repositories/auth_repository.dart';
import 'package:test/features/auth/domain/usecases/auth_usecases.dart';
import 'package:test/features/auth/presentation/controllers/auth_controller.dart';
import 'package:test/features/profile/presentation/controllers/profile_controller.dart';
import 'package:test/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

AuthUser _user() {
  return const AuthUser(
    id: 6,
    name: 'Owner One',
    email: 'owner@example.com',
    phone: '0811111111',
    role: 'owner',
    avatarUrl: 'https://example.com/avatar.png',
  );
}

class _UnusedRepository implements AuthRepository {
  const _UnusedRepository();

  @override
  Future<AuthSession> signIn(SignInRequest request) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> fetchCurrentUser() => throw UnimplementedError();

  @override
  Future<AuthSession> updateMe() => throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    required Map<String, Object?> changes,
  }) => throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> uploadAvatar({
    required String filePath,
    required String filename,
    String? mimeType,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() => throw UnimplementedError();

  @override
  Future<void> persistSession(AuthSession session) =>
      throw UnimplementedError();
}

class _FakeAuthController extends AuthController {
  _FakeAuthController() : super(const AuthUseCases(_UnusedRepository()));

  int updateCalls = 0;
  bool result = true;
  String? failure;

  @override
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    updateCalls++;
    if (!result) {
      profileUpdateError.value = failure ?? 'profileUpdateFailed';
    }
    return result;
  }
}

void main() {
  test('invalid fields are rejected before the API is called', () async {
    final session = SessionController()..setSession(_user());
    final auth = _FakeAuthController();
    final controller = ProfileController(session, authController: auth);

    expect(
      await controller.updateProfile(
        name: '   ',
        email: 'owner@example.com',
        phone: '0811111111',
      ),
      isFalse,
    );
    expect(controller.errorMessage.value, 'profileNameRequired');

    expect(
      await controller.updateProfile(
        name: 'Owner One',
        email: 'not-an-email',
        phone: '0811111111',
      ),
      isFalse,
    );
    expect(controller.errorMessage.value, 'profileEmailInvalid');

    expect(
      await controller.updateProfile(
        name: 'Owner One',
        email: 'owner@example.com',
        phone: 'abc',
      ),
      isFalse,
    );
    expect(controller.errorMessage.value, 'profilePhoneInvalid');
    expect(auth.updateCalls, 0);
    expect(session.currentUser?.name, 'Owner One');
  });

  testWidgets('a failed save keeps the sheet open with the entered values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var shouldFail = true;
    String? submittedName;
    String? submittedEmail;
    String? submittedPhone;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EditProfileSheet(
                      user: _user(),
                      onSubmit: (name, email, phone) async {
                        submittedName = name;
                        submittedEmail = email;
                        submittedPhone = phone;
                        return shouldFail ? 'Could not save profile' : null;
                      },
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Jane Resident',
    );
    await tester.enterText(
      find.byKey(const Key('profile-email-field')),
      'jane@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('profile-phone-field')),
      '0999999999',
    );
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-save')), findsOneWidget);
    expect(find.byKey(const Key('profile-edit-error')), findsOneWidget);
    expect(find.text('Could not save profile'), findsOneWidget);
    expect(submittedName, 'Jane Resident');
    expect(submittedEmail, 'jane@example.com');
    expect(submittedPhone, '0999999999');

    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('profile-name-field')),
    );
    expect(nameField.controller?.text, 'Jane Resident');
    final emailField = tester.widget<TextFormField>(
      find.byKey(const Key('profile-email-field')),
    );
    expect(emailField.controller?.text, 'jane@example.com');
    final phoneField = tester.widget<TextFormField>(
      find.byKey(const Key('profile-phone-field')),
    );
    expect(phoneField.controller?.text, '0999999999');

    shouldFail = false;
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-save')), findsNothing);
  });
}
