import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/models/resident_role.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

AuthUser _user({int id = 6, String name = 'Owner One', String role = 'owner'}) {
  return AuthUser(
    id: id,
    name: name,
    phone: '0811111111',
    role: role,
    email: 'owner$id@example.com',
    avatarUrl: 'http://example.com/web/image/res.users/$id/image_1920',
    unit: const AuthUnit(
      id: 1,
      label: 'Tower A · Unit 1205',
      tower: 'Tower A',
      number: '1205',
    ),
  );
}

void main() {
  test('setSession publishes the complete AuthUser', () {
    final controller = SessionController();
    final user = _user();

    controller.setSession(user);

    expect(controller.isAuthenticated, isTrue);
    expect(controller.currentUser, same(user));
    expect(controller.session.value?.user, same(user));
    expect(controller.currentUser?.email, 'owner6@example.com');
    expect(controller.currentUser?.unit?.number, '1205');
  });

  test('session changes are reactive', () {
    final controller = SessionController();
    var changes = 0;
    final subscription = controller.session.listen((_) => changes++);
    addTearDown(subscription.cancel);

    controller.setSession(_user());
    controller.clearSession();

    expect(changes, 2);
  });

  test('clearSession removes the previous user entirely', () {
    final controller = SessionController();
    controller.setSession(_user());

    controller.clearSession();

    expect(controller.isAuthenticated, isFalse);
    expect(controller.session.value, isNull);
    expect(controller.currentUser, isNull);
    expect(controller.name, isEmpty);
  });

  test('switching accounts never exposes the previous profile', () {
    final controller = SessionController();
    final first = _user(id: 6, name: 'Owner One');
    final second = _user(id: 9, name: 'Tenant Two', role: 'tenant');

    controller.setSession(first);
    controller.setSession(second);

    expect(controller.currentUser, same(second));
    expect(controller.name, 'Tenant Two');
    expect(controller.currentUser?.email, 'owner9@example.com');
    expect(controller.role, ResidentRole.tenant);
  });

  test('ResidentSession maps the AuthUser role and unit', () {
    final session = SessionController()..setSession(_user());

    expect(session.role, ResidentRole.owner);
    expect(session.isOwner, isTrue);
    expect(session.isTenant, isFalse);
    expect(session.unitLabel, 'Tower A · Unit 1205');
    expect(session.current?.image, contains('/image_1920'));
  });
}
