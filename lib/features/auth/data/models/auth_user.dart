import 'package:test/core/utils/super_print.dart';

/// The signed-in resident, as the backend describes them.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.image,
    this.themeColor,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? gender;
  final String? image;
  final String? themeColor;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'username': username,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'image': image,
    'theme_color': themeColor,
  };

  /// The name to greet the resident by.
  String get displayName {
    final joined = <String>[
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();

    return joined.isNotEmpty ? joined : username;
  }

  String get initials {
    final parts = <String>[
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return username.isEmpty ? '?' : username[0].toUpperCase();
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _asInt(json['id']),
      username: _asString(json['username']),
      email: _asString(json['email']),
      firstName: _asString(json['firstName']),
      lastName: _asString(json['lastName']),
      gender: _asNullableString(json['gender']),
      image: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSbZ0WFrgDfCi0quSSO2usQ032wzQ1AjvHpBJE3m4e15g&s=10",
      // json['image'] is String ? json['image'] as String : null,,
      themeColor: 
      //"#EF4444",
      _asThemeColor(json['theme_color']),
    );
  }

  static AuthUser parse(Object? json) {
    superPrint(json, title: "Auth User Response");

    if (json is! Map) {
      return const AuthUser(
        id: 0,
        username: '',
        email: '',
        firstName: '',
        lastName: '',
      );
    }
    return AuthUser.fromJson(Map<String, dynamic>.from(json));
  }

  static int _asInt(Object? value) { 
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _asString(Object? value) =>
      value is String ? value : (value?.toString() ?? '');

  static String? _asNullableString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String? _asThemeColor(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')
        .firstMatch(value.trim());
    if (match == null) return null;
    return '#${match.group(1)!.toUpperCase()}';
  }

  @override
  String toString() =>
      'AuthUser(id: $id, username: $username, themeColor: $themeColor)';
}
