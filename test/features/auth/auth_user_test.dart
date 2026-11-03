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
