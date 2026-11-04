import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/profile/presentation/bindings/profile_binding.dart';
import 'package:test/features/profile/presentation/controllers/profile_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

AuthUser _user({
  int id = 6,
  String name = 'Owner One',
  String email = 'owner@example.com',
  String phone = '0811111111',
}) {
  return AuthUser(
    id: id,
    name: name,
    email: email,
    phone: phone,
    role: 'owner',
    avatarUrl: 'https://example.com/avatar.png',
    themeColor: '#123456',
    permissions: const <String>['profile.read'],
    unit: const AuthUnit(
      id: 1,
      label: 'Tower A Unit 1205',
      tower: 'Tower A',
      number: '1205',
    ),
  );
}

void main() {
  test('reads the authenticated user directly from the session', () {
    final session = SessionController();
    final controller = ProfileController(session);
    final user = _user();

    session.setSession(user);

    expect(identical(controller.user, session.currentUser), isTrue);
    expect(controller.user?.name, 'Owner One');
    expect(controller.unitLabel, 'Tower A Unit 1205');

    session.setSession(_user(name: 'Owner Two', id: 7));

    expect(controller.user?.name, 'Owner Two');
    expect(controller.user?.id, 7);
  });

  test('edits write through the session and preserve untouched fields', () {
    final session = SessionController()..setSession(_user());
    final controller = ProfileController(session);

    final updated = controller.updateProfile(
      name: '  Jane Resident  ',
      email: ' jane@example.com ',
      phone: ' 0999999999 ',
    );

    expect(updated, isTrue);
    expect(controller.user?.name, 'Jane Resident');
    expect(controller.user?.email, 'jane@example.com');
    expect(controller.user?.phone, '0999999999');
    expect(controller.user?.role, 'owner');
    expect(controller.user?.avatarUrl, 'https://example.com/avatar.png');
    expect(controller.user?.themeColor, '#123456');
    expect(controller.user?.permissions, <String>['profile.read']);
    expect(controller.user?.unit?.label, 'Tower A Unit 1205');
  });

  test('invalid edits leave the session user untouched', () {
    final session = SessionController()..setSession(_user());
    final controller = ProfileController(session);

    final updated = controller.updateProfile(
      name: '',
      email: 'owner@example.com',
      phone: '0811111111',
    );

    expect(updated, isFalse);
    expect(controller.errorMessage.value, isNotNull);
    expect(session.currentUser?.name, 'Owner One');
  });

  test('clearing the session removes the displayed user', () {
    final session = SessionController()..setSession(_user());
    final controller = ProfileController(session);

    expect(controller.user, isNotNull);

    session.clearSession();

    expect(controller.user, isNull);
  });

  test('the binding reuses the registered session controller', () {
    final session = SessionController();
    Get.put<SessionController>(session, permanent: true);
    addTearDown(Get.reset);

    ProfileBinding().dependencies();

    expect(
      identical(Get.find<ProfileController>().sessionController, session),
      isTrue,
    );
  });
}
