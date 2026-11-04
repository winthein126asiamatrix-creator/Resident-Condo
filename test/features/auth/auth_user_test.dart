import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/auth/data/models/auth_user.dart';

void main() {
  test('parses the complete /auth/me profile', () {
    final user = AuthUser.fromJson(<String, dynamic>{
      'id': 6,
      'name': 'Owner One',
      'email': 'owner@example.com',
      'phone': '0811111111',
      'avatar_url': 'web/image/res.users/6/image_1920',
      'unit': <String, dynamic>{
        'id': 1,
        'label': 'Tower A · Unit 1205',
        'tower': 'Tower A',
        'number': '1205',
      },
      'role': 'owner',
      'permissions': <String>['profile.read', 'unit.manage_residents'],
      'unread_notification_count': 3,
      'theme_color': '#3366ff',
      'notifications_enabled': false,
    });

    expect(user.id, 6);
    expect(user.name, 'Owner One');
    expect(user.email, 'owner@example.com');
    expect(user.phone, '0811111111');
    expect(user.avatarUrl, 'web/image/res.users/6/image_1920');
    expect(user.unit?.label, 'Tower A · Unit 1205');
    expect(user.role, 'owner');
    expect(user.permissions, <String>['profile.read', 'unit.manage_residents']);
    expect(user.unreadNotificationCount, 3);
    expect(user.themeColor, '#3366FF');
    expect(user.notificationsEnabled, isFalse);
  });

  test('leaves notifications_enabled null when the backend omits it', () {
    final user = AuthUser.fromJson(<String, dynamic>{
      'id': 6,
      'name': 'Owner One',
      'phone': '0811111111',
      'role': 'owner',
    });

    expect(user.notificationsEnabled, isNull);
  });

  test('merges notifications_enabled without losing other fields', () {
    final current = AuthUser(
      id: 6,
      name: 'Owner One',
      phone: '0811111111',
      role: 'owner',
      themeColor: '#123456',
      notificationsEnabled: true,
    );

    final updated = AuthUser.mergeProfile(
      <String, dynamic>{'notifications_enabled': false},
      currentUser: current,
      submitted: const <String, Object?>{},
    );

    expect(updated.notificationsEnabled, isFalse);
    expect(updated.themeColor, '#123456');
    expect(updated.name, 'Owner One');
  });

  test('merges a success-only profile response without losing fields', () {
    final current = AuthUser(
      id: 6,
      name: 'Owner One',
      phone: '0811111111',
      role: 'owner',
      email: 'owner@example.com',
      avatarUrl: 'https://example.com/avatar.png',
      themeColor: '#123456',
      permissions: const <String>['profile.read'],
      unit: const AuthUnit(
        id: 1,
        label: 'Tower A · Unit 1205',
        tower: 'Tower A',
        number: '1205',
      ),
    );

    final updated = AuthUser.mergeProfile(
      <String, dynamic>{'message': 'Profile updated'},
      currentUser: current,
      submitted: <String, Object?>{
        'name': 'Owner Two',
        'phone': '0999999999',
        'email': 'owner2@example.com',
      },
    );

    expect(updated.name, 'Owner Two');
    expect(updated.phone, '0999999999');
    expect(updated.email, 'owner2@example.com');
    expect(updated.avatarUrl, current.avatarUrl);
    expect(updated.unit?.label, current.unit?.label);
    expect(updated.role, current.role);
    expect(updated.permissions, current.permissions);
    expect(updated.themeColor, current.themeColor);
  });

  test('uses response fields and preserves unrelated fields when partial', () {
    final current = AuthUser(
      id: 6,
      name: 'Owner One',
      phone: '0811111111',
      role: 'owner',
      email: 'owner@example.com',
      avatarUrl: 'https://example.com/avatar.png',
      permissions: const <String>['profile.read'],
      unit: const AuthUnit(
        id: 1,
        label: 'Tower A · Unit 1205',
        tower: 'Tower A',
        number: '1205',
      ),
    );

    final updated = AuthUser.mergeProfile(
      <String, dynamic>{'id': 6, 'name': 'Server Name', 'phone': '0999999999'},
      currentUser: current,
      submitted: <String, Object?>{
        'name': 'Local Name',
        'phone': '0999999999',
        'email': 'owner2@example.com',
      },
    );

    expect(updated.name, 'Server Name');
    expect(updated.phone, '0999999999');
    expect(updated.email, 'owner2@example.com');
    expect(updated.avatarUrl, current.avatarUrl);
    expect(updated.unit?.label, current.unit?.label);
  });

  test('round-trips the profile through JSON', () {
    final original = AuthUser(
      id: 9,
      name: 'Tenant Two',
      phone: '0922222222',
      role: 'tenant',
      email: null,
      themeColor: '#112233',
      unit: const AuthUnit(
        id: 2,
        label: 'Tower B · Unit 0801',
        tower: 'Tower B',
        number: '0801',
      ),
    );

    final restored = AuthUser.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.role, original.role);
    expect(restored.phone, original.phone);
    expect(restored.email, isNull);
    expect(restored.themeColor, '#112233');
    expect(restored.unit?.number, '0801');
  });
}
