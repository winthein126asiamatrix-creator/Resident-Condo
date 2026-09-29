class Profile {
  const Profile({
    required this.name,
    required this.email,
    required this.phone,
    required this.unit,
    required this.role,
    required this.initials,
    required this.language,
    required this.notificationsEnabled,
  });

  final String name;
  final String email;
  final String phone;
  final String unit;
  final String role;
  final String initials;
  final String language;
  final bool notificationsEnabled;

  Profile copyWith({
    String? name,
    String? email,
    String? phone,
    String? language,
    bool? notificationsEnabled,
  }) {
    return Profile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      unit: unit,
      role: role,
      initials: initials,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
