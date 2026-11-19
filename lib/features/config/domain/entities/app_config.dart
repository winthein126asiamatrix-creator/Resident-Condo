class AppConfig {
  const AppConfig({this.version, this.maintenance});

  final AppVersionConfig? version;
  final AppMaintenanceConfig? maintenance;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final versionJson = json['app_version'];
    final maintenanceJson = json['maintenance'];
    return AppConfig(
      version: versionJson is Map
          ? AppVersionConfig.fromJson(Map<String, dynamic>.from(versionJson))
          : null,
      maintenance: maintenanceJson is Map
          ? AppMaintenanceConfig.fromJson(
              Map<String, dynamic>.from(maintenanceJson),
            )
          : null,
    );
  }

  static AppConfig parse(Object? json) {
    if (json is! Map) {
      throw const FormatException('Unexpected app config response.');
    }
    return AppConfig.fromJson(Map<String, dynamic>.from(json));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'app_version': version?.toJson(),
    'maintenance': maintenance?.toJson(),
  };
}

class AppVersionConfig {
  const AppVersionConfig({this.minSupported, this.latest, this.updateUrl});

  final String? minSupported;
  final String? latest;
  final String? updateUrl;

  bool get hasUpdateTarget => (updateUrl ?? '').trim().isNotEmpty;

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) {
    return AppVersionConfig(
     minSupported: _stringOrNull(json['min_supported']),
     latest:_stringOrNull(json['latest']),
    //  minSupported: '1.2.0',
    //  latest: '1.3.0',
      updateUrl: _stringOrNull(json['update_url']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'min_supported': minSupported,
    'latest': latest,
    'update_url': updateUrl,
  };
}

class AppMaintenanceConfig {
  const AppMaintenanceConfig({this.enabled = false, this.message, this.endsAt});

  final bool enabled;
  final String? message;
  final DateTime? endsAt;

  factory AppMaintenanceConfig.fromJson(Map<String, dynamic> json) {
    return AppMaintenanceConfig(
      enabled: _bool(json['enabled']),
      message: _stringOrNull(json['message']),
      endsAt: _dateOrNull(json['ends_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'message': message,
    'ends_at': endsAt?.toIso8601String(),
  };
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1';
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _dateOrNull(Object? value) {
  final text = _stringOrNull(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}
