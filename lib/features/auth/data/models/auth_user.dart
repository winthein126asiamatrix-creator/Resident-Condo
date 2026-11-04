import 'package:test/core/utils/super_print.dart';

import '../../../../core/network/api_config.dart';

/// The signed-in resident, as the backend describes them.
///
/// {
///   "id": 6,
///   "name": "Owner One",
///   "email": false,
///   "phone": "0811111111",
///   "avatar_url": "/web/image/res.users/6/image_1920",
///   "unit": {
///     "id": 1,
///     "label": "Tower A · Unit 1205",
///     "tower": "Tower A",
///     "number": "1205"
///   },
///   "role": "owner",
///   "permissions": ["profile.read", "profile.write", "unit.manage_residents"],
///   "unread_notification_count": 0
/// }
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.avatarUrl,
    this.unit,
    this.permissions = const <String>[],
    this.unreadNotificationCount = 0,
    this.themeColor,
  });

  final int id;
  final String name;
  final String? email; // backend sends `false` when empty
  final String phone;

  /// Absolute URL, e.g. http://host:9200/web/image/res.users/6/image_1920.
  ///
  /// The backend sends a relative path (`web/image/res.users/6/image_1920`);
  /// it is resolved against the backend origin when the user is parsed.
  final String? avatarUrl;
  final AuthUnit? unit;
  final String role;
  final List<String> permissions;
  final int unreadNotificationCount;
  final String? themeColor;

  static const AuthUser empty = AuthUser(id: 0, name: '', phone: '', role: '');

  bool get isOwner => role == 'owner';

  bool hasPermission(String permission) => permissions.contains(permission);

  /// The name to greet the resident by.
  String get displayName => name.trim().isNotEmpty ? name.trim() : phone;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  AuthUser copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    AuthUnit? unit,
    String? role,
    List<String>? permissions,
    int? unreadNotificationCount,
    String? themeColor,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      unit: unit ?? this.unit,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      unreadNotificationCount:
          unreadNotificationCount ?? this.unreadNotificationCount,
      themeColor: themeColor ?? this.themeColor,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'email': email ?? false,
    'phone': phone,
    'avatar_url': avatarUrl,
    'unit': unit?.toJson(),
    'role': role,
    'permissions': permissions,
    'unread_notification_count': unreadNotificationCount,
    'theme_color': themeColor,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final unitJson = json['unit'];
    final permissionsJson = json['permissions'];

    return AuthUser(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      email: _asNullableString(json['email']),
      phone: _asString(json['phone']),
      avatarUrl: _asAvatarUrl(json['avatar_url']),
      unit: unitJson is Map
          ? AuthUnit.fromJson(Map<String, dynamic>.from(unitJson))
          : null,
      role: _asString(json['role']),
      permissions: permissionsJson is List
          ? permissionsJson.map((e) => e.toString()).toList()
          : const <String>[],
      unreadNotificationCount: _asInt(json['unread_notification_count']),
      themeColor: _asThemeColor(json['theme_color']),
    );
  }
  static String? _asThemeColor(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')
        .firstMatch(value.trim());
    if (match == null) return null;
    return '#${match.group(1)!.toUpperCase()}';
  }

  static AuthUser parse(Object? json) {
    superPrint(json, title: "Auth User Response");

    if (json is! Map) return empty;
    return AuthUser.fromJson(Map<String, dynamic>.from(json));
  }

  @override
  String toString() =>
      'AuthUser(id: $id, name: $name, role: $role, unit: ${unit?.label})';
}

class AuthUnit {
  const AuthUnit({
    required this.id,
    required this.label,
    required this.tower,
    required this.number,
  });

  final int id;
  final String label;
  final String tower;
  final String number;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'tower': tower,
    'number': number,
  };

  factory AuthUnit.fromJson(Map<String, dynamic> json) {
    return AuthUnit(
      id: _asInt(json['id']),
      label: _asString(json['label']),
      tower: _asString(json['tower']),
      number: _asString(json['number']),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _asString(Object? value) => value is String
    ? value
    : (value == null || value == false ? '' : value.toString());

/// Returns null for `false`, `null`, and blank strings (Odoo-style empty values).
String? _asNullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

/// Resolves the backend's relative avatar path into a loadable absolute URL.
///
/// The API base URL includes the app prefix (e.g. `/api/v1`), while Odoo serves
/// `/web/image/...` from the server root, so only the origin is used here.
/// Absolute URLs are returned untouched, and an unresolvable base (a unit test
/// without a flavor, for example) falls back to the original path.
String? _asAvatarUrl(Object? value) {
  final raw = _asNullableString(value);
  if (raw == null) return null;

  final parsed = Uri.tryParse(raw);
  if (parsed != null && parsed.hasScheme) return raw;

  try {
    final base = Uri.parse(ApiConfig.baseUrl);
    if (base.scheme.isEmpty || base.host.isEmpty) return raw;
    final origin = Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
    ).toString();
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$origin$path';
  } on Object {
    return raw;
  }
}
