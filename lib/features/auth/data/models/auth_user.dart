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
    this.notificationsEnabled,
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

  /// The backend notification preference, when `/auth/me` includes it.
  ///
  /// Nullable so an older backend that does not return the field does not
  /// reset the resident's local toggle.
  final bool? notificationsEnabled;

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
    bool? notificationsEnabled,
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
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'avatar_url': avatarUrl,
    'unit': unit?.toJson(),
    'role': role,
    'permissions': permissions,
    'unread_notification_count': unreadNotificationCount,
    'theme_color': themeColor,
    'notifications_enabled': notificationsEnabled,
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
      notificationsEnabled: _asNullableBool(json['notifications_enabled']),
    );
  }
  static String? _asThemeColor(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')
        .firstMatch(value.trim());
    if (match == null) return null;
    return '#${match.group(1)!.toUpperCase()}';
  }

  /// Applies a profile update response to [currentUser] without clearing fields
  /// the response did not describe.
  ///
  /// The backend may return a complete user, a partial record, or only a success
  /// message. Recognised fields in [response] win; otherwise the values the
  /// resident submitted are applied; everything else is carried over from
  /// [currentUser].
  static AuthUser mergeProfile(
    Object? response, {
    required AuthUser currentUser,
    required Map<String, Object?> submitted,
  }) {
    final json = _profileResponseMap(response);

    final name = _mergeText(json?['name'], submitted['name'], currentUser.name);
    final phone = _mergeText(
      json?['phone'],
      submitted['phone'],
      currentUser.phone,
    );

    String? email = currentUser.email;
    if (json != null && json.containsKey('email')) {
      email = _asNullableString(json['email']);
    } else if (submitted.containsKey('email')) {
      email = _asNullableString(submitted['email']);
    }

    var id = currentUser.id;
    if (json != null && json.containsKey('id')) {
      final parsedId = _asInt(json['id']);
      if (parsedId > 0) {
        id = parsedId;
      }
    }

    var avatarUrl = currentUser.avatarUrl;
    if (json != null && json.containsKey('avatar_url')) {
      final parsedAvatar = _asAvatarUrl(json['avatar_url']);
      if (parsedAvatar != null && parsedAvatar.isNotEmpty) {
        avatarUrl = parsedAvatar;
      }
    }

    var unit = currentUser.unit;
    final unitJson = json?['unit'];
    if (unitJson is Map) {
      unit = AuthUnit.fromJson(Map<String, dynamic>.from(unitJson));
    }

    final role = _mergeText(json?['role'], null, currentUser.role);

    var permissions = currentUser.permissions;
    final permissionsJson = json?['permissions'];
    if (permissionsJson is List) {
      permissions = permissionsJson.map((e) => e.toString()).toList();
    }

    var unreadNotificationCount = currentUser.unreadNotificationCount;
    final unreadJson = json?['unread_notification_count'];
    if (unreadJson is num) {
      unreadNotificationCount = unreadJson.toInt();
    }

    var themeColor = currentUser.themeColor;
    if (json != null && json.containsKey('theme_color')) {
      themeColor = _asThemeColor(json['theme_color']) ?? themeColor;
    }

    var notificationsEnabled = currentUser.notificationsEnabled;
    if (json != null && json.containsKey('notifications_enabled')) {
      notificationsEnabled =
          _asNullableBool(json['notifications_enabled']) ??
          notificationsEnabled;
    }

    return AuthUser(
      id: id,
      name: name,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      unit: unit,
      role: role,
      permissions: permissions,
      unreadNotificationCount: unreadNotificationCount,
      themeColor: themeColor,
      notificationsEnabled: notificationsEnabled,
    );
  }

  static Map<String, dynamic>? _profileResponseMap(Object? response) {
    if (response is! Map) return null;
    final map = Map<String, dynamic>.from(response);
    final nestedUser = map['user'];
    if (nestedUser is Map) {
      return Map<String, dynamic>.from(nestedUser);
    }
    return map;
  }

  static String _mergeText(
    Object? responseValue,
    Object? submittedValue,
    String currentValue,
  ) {
    final fromResponse = responseValue is String ? responseValue.trim() : '';
    if (fromResponse.isNotEmpty) {
      return fromResponse;
    }
    final fromSubmitted = submittedValue is String ? submittedValue.trim() : '';
    if (fromSubmitted.isNotEmpty) {
      return fromSubmitted;
    }
    return currentValue;
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

/// Parses a backend boolean, accepting the numeric form Odoo sometimes sends.
///
/// Anything unrecognised returns null, so a missing or malformed preference
/// does not overwrite the resident's local toggle.
bool? _asNullableBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
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
