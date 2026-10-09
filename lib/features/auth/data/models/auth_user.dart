/// The signed-in resident, as the backend describes them.
///
/// Hand written like the rest of the project's models rather than generated:
/// the shape is small, and the parsing lives in one place either way.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.image,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? gender;
  final String? image;

  /// The name to greet the resident by.
  ///
  /// Falls back through the parts before settling on the username, so a record
  /// missing a name still greets the account it belongs to rather than showing a
  /// blank dashboard.
  String get displayName {
    final joined = <String>[firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    return joined.isNotEmpty ? joined : username;
  }

  String get initials {
    final parts = <String>[firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .toList();
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
      gender: json['gender'] is String ? json['gender'] as String : null,
      image: json['image'] is String ? json['image'] as String : null,
    );
  }

  /// Builds a user from a decoded backend record.
  ///
  /// Tolerant of a missing or wrongly typed field rather than throwing: an
  /// incomplete profile should still let the resident in, and the only required
  /// pieces are the id and the username the session is keyed on.
  ///
  /// Takes [Object?] rather than a map so it matches the client's parser
  /// signature and can be handed straight to a request.
  static AuthUser parse(Object? json) {
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
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  static String _asString(Object? value) =>
      value is String ? value : (value?.toString() ?? '');

  @override
  String toString() => 'AuthUser(id: $id, username: $username)';
}