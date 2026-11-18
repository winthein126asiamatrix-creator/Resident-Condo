enum CondoFeature {
  dashboard('dashboard', 'Dashboard'),
  payments('payments', 'Payments'),
  maintenance('maintenance', 'Maintenance'),
  condoServices('condo_services', 'Condo services'),
  facilities('facilities', 'Facilities'),
  complaints('complaints', 'Complaints'),
  visitors('visitors', 'Visitors'),
  parking('parking', 'Parking'),
  rulesViolations('rules_violations', 'Rules & violations'),
  violationAppeals('violation_appeals', 'Violation appeals'),
  partialPayment('partial_payment', 'Partial payment'),
  lease('lease', 'Rental & lease'),
  convenienceStore('convenience_store', 'Convenience Store');

  const CondoFeature(this.wire, this.label);

  final String wire;
  final String label;
}

class CondoConfig {
  const CondoConfig({
    this.condo,
    this.plan,
    this.features = const FeatureConfig(<CondoFeature, bool>{}),
    this.booking,
    this.lease,
    this.payments,
    this.support,
  });

  final CondoInfo? condo;
  final PlanConfig? plan;
  final FeatureConfig features;
  final BookingConfig? booking;
  final LeaseConfig? lease;
  final PaymentConfig? payments;
  final SupportConfig? support;

  bool isFeatureEnabled(CondoFeature feature) => features.isEnabled(feature);

  factory CondoConfig.fromJson(Map<String, dynamic> json) {
    final condoJson = json['condo'];
    final planJson = json['plan'];
    final featuresJson = json['features'];
    final bookingJson = json['booking'];
    final leaseJson = json['lease'];
    final paymentsJson = json['payments'];
    final supportJson = json['support'];
    return CondoConfig(
      condo: condoJson is Map
          ? CondoInfo.fromJson(Map<String, dynamic>.from(condoJson))
          : null,
      plan: planJson is Map
          ? PlanConfig.fromJson(Map<String, dynamic>.from(planJson))
          : null,
      features: featuresJson is Map
          ? FeatureConfig.fromJson(Map<String, dynamic>.from(featuresJson))
          : const FeatureConfig(<CondoFeature, bool>{}),
      booking: bookingJson is Map
          ? BookingConfig.fromJson(Map<String, dynamic>.from(bookingJson))
          : null,
      lease: leaseJson is Map
          ? LeaseConfig.fromJson(Map<String, dynamic>.from(leaseJson))
          : null,
      payments: paymentsJson is Map
          ? PaymentConfig.fromJson(Map<String, dynamic>.from(paymentsJson))
          : null,
      support: supportJson is Map
          ? SupportConfig.fromJson(Map<String, dynamic>.from(supportJson))
          : null,
    );
  }

  static CondoConfig parse(Object? json) {
    if (json is! Map) {
      throw const FormatException('Unexpected condo config response.');
    }
    final map = Map<String, dynamic>.from(json);
    if (map['features'] is! Map) {
      throw const FormatException('Condo config is missing features.');
    }
    return CondoConfig.fromJson(map);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'condo': condo?.toJson(),
    'plan': plan?.toJson(),
    'features': features.toJson(),
    'booking': booking?.toJson(),
    'lease': lease?.toJson(),
    'payments': payments?.toJson(),
    'support': support?.toJson(),
  };
}

class FeatureConfig {
  const FeatureConfig(this._flags);

  final Map<CondoFeature, bool> _flags;

  bool isEnabled(CondoFeature feature) => _flags[feature] ?? false;

  factory FeatureConfig.fromJson(Map<String, dynamic> json) {
    return FeatureConfig(<CondoFeature, bool>{
      for (final feature in CondoFeature.values)
        // feature: feature == CondoFeature.condoServices
        //   ? false
        //   : _bool(json[feature.wire]),
        feature: _bool(json[feature.wire]),
    });
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    for (final entry in _flags.entries) entry.key.wire: entry.value,
  };
}

class CondoInfo {
  const CondoInfo({
    required this.id,
    required this.name,
    this.logoUrl,
    this.themeColor,
  });

  final int id;
  final String name;
  final String? logoUrl;
  final String? themeColor;

  factory CondoInfo.fromJson(Map<String, dynamic> json) {
    return CondoInfo(
      id: _int(json['id']) ?? 0,
      name: _string(json['name']),
      logoUrl: _stringOrNull(json['logo_url']),
      themeColor: _stringOrNull(json['theme_color']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'logo_url': logoUrl,
    'theme_color': themeColor,
  };
}

class PlanConfig {
  const PlanConfig({required this.tier, this.addons = const <String>[]});

  final String tier;
  final List<String> addons;

  factory PlanConfig.fromJson(Map<String, dynamic> json) {
    return PlanConfig(
      tier: _string(json['tier']),
      addons: _stringList(json['addons']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tier': tier,
    'addons': addons,
  };
}

class BookingConfig {
  const BookingConfig({this.condoServices, this.maintenance, this.facilities});

  final CondoServicesBookingConfig? condoServices;
  final MaintenanceBookingConfig? maintenance;
  final FacilitiesBookingConfig? facilities;

  factory BookingConfig.fromJson(Map<String, dynamic> json) {
    final servicesJson = json['condo_services'];
    final maintenanceJson = json['maintenance'];
    final facilitiesJson = json['facilities'];
    return BookingConfig(
      condoServices: servicesJson is Map
          ? CondoServicesBookingConfig.fromJson(
              Map<String, dynamic>.from(servicesJson),
            )
          : null,
      maintenance: maintenanceJson is Map
          ? MaintenanceBookingConfig.fromJson(
              Map<String, dynamic>.from(maintenanceJson),
            )
          : null,
      facilities: facilitiesJson is Map
          ? FacilitiesBookingConfig.fromJson(
              Map<String, dynamic>.from(facilitiesJson),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'condo_services': condoServices?.toJson(),
    'maintenance': maintenance?.toJson(),
    'facilities': facilities?.toJson(),
  };
}

class CondoServicesBookingConfig {
  const CondoServicesBookingConfig({
    this.maxAdvanceDays,
    this.minAdvanceHours,
    this.cancelBeforeHours,
  });

  final int? maxAdvanceDays;
  final int? minAdvanceHours;
  final int? cancelBeforeHours;

  factory CondoServicesBookingConfig.fromJson(Map<String, dynamic> json) {
    return CondoServicesBookingConfig(
      maxAdvanceDays: _int(json['max_advance_days']),
      minAdvanceHours: _int(json['min_advance_hours']),
      cancelBeforeHours: _int(json['cancel_before_hours']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'max_advance_days': maxAdvanceDays,
    'min_advance_hours': minAdvanceHours,
    'cancel_before_hours': cancelBeforeHours,
  };
}

class MaintenanceBookingConfig {
  const MaintenanceBookingConfig({
    this.maxAdvanceDays,
    this.minAdvanceHours,
    this.cancelBeforeHours,
  });

  final int? maxAdvanceDays;
  final int? minAdvanceHours;
  final int? cancelBeforeHours;

  factory MaintenanceBookingConfig.fromJson(Map<String, dynamic> json) {
    return MaintenanceBookingConfig(
      maxAdvanceDays: _int(json['max_advance_days']),
      minAdvanceHours: _int(json['min_advance_hours']),
      cancelBeforeHours: _int(json['cancel_before_hours']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'max_advance_days': maxAdvanceDays,
    'min_advance_hours': minAdvanceHours,
    'cancel_before_hours': cancelBeforeHours,
  };

  static DateTime? parseAppointment(String? date, String? time) {
    if (date == null || time == null) return null;
    final dateParts = date.split('-');
    final timeParts = time.split(':');
    if (dateParts.length != 3 || timeParts.length < 2) return null;
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    final value = DateTime(year, month, day, hour, minute);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  DateTime? latestSelectableDate(DateTime now) {
    final days = maxAdvanceDays;
    if (days == null || days < 0) return null;
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }

  DateTime? earliestAppointment(DateTime now) {
    final hours = minAdvanceHours;
    if (hours == null || hours < 0) return null;
    return now.add(Duration(hours: hours));
  }

  String? validateAppointment(DateTime now, DateTime appointment) {
    final latestDate = latestSelectableDate(now);
    if (latestDate != null) {
      final appointmentDay = DateTime(
        appointment.year,
        appointment.month,
        appointment.day,
      );
      if (appointmentDay.isAfter(latestDate)) {
        return 'Choose a date no more than $maxAdvanceDays days from today.';
      }
    }
    final earliest = earliestAppointment(now);
    if (earliest != null && appointment.isBefore(earliest)) {
      return 'Choose a time at least $minAdvanceHours hours from now.';
    }
    return null;
  }

  bool canCancelAppointment(DateTime now, DateTime appointment) {
    final hours = cancelBeforeHours;
    if (hours == null || hours < 0) return true;
    if (!appointment.isAfter(now)) return false;
    return !appointment.isBefore(now.add(Duration(hours: hours)));
  }
}

class FacilitiesBookingConfig {
  const FacilitiesBookingConfig({
    this.maxAdvanceDays,
    this.minAdvanceHours,
    this.cancelBeforeHours,
    this.maxActivePerUnit,
  });

  final int? maxAdvanceDays;
  final int? minAdvanceHours;
  final int? cancelBeforeHours;
  final int? maxActivePerUnit;

  factory FacilitiesBookingConfig.fromJson(Map<String, dynamic> json) {
    return FacilitiesBookingConfig(
      maxAdvanceDays: _int(json['max_advance_days']),
      minAdvanceHours: _int(json['min_advance_hours']),
      cancelBeforeHours: _int(json['cancel_before_hours']),
      maxActivePerUnit: _int(json['max_active_per_unit']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'max_advance_days': maxAdvanceDays,
    'min_advance_hours': minAdvanceHours,
    'cancel_before_hours': cancelBeforeHours,
    'max_active_per_unit': maxActivePerUnit,
  };
}

class LeaseConfig {
  const LeaseConfig({
    this.tenantRegistrationEnabled = false,
    this.maxTenantsPerUnit,
    this.minLeaseMonths,
    this.maxLeaseMonths,
    this.requiredDocuments = const <LeaseDocumentRequirement>[],
    this.allowedFileTypes = const <String>[],
    this.maxUploadMb,
    this.approvalRequired = false,
  });

  final bool tenantRegistrationEnabled;
  final int? maxTenantsPerUnit;
  final int? minLeaseMonths;
  final int? maxLeaseMonths;
  final List<LeaseDocumentRequirement> requiredDocuments;
  final List<String> allowedFileTypes;
  final int? maxUploadMb;
  final bool approvalRequired;

  factory LeaseConfig.fromJson(Map<String, dynamic> json) {
    final documentsJson = json['required_documents'];
    return LeaseConfig(
      tenantRegistrationEnabled: _bool(json['tenant_registration_enabled']),
      maxTenantsPerUnit: _int(json['max_tenants_per_unit']),
      minLeaseMonths: _int(json['min_lease_months']),
      maxLeaseMonths: _int(json['max_lease_months']),
      requiredDocuments: documentsJson is List
          ? documentsJson
                .whereType<Map>()
                .map(
                  (item) => LeaseDocumentRequirement.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <LeaseDocumentRequirement>[],
      allowedFileTypes: _stringList(json['allowed_file_types']),
      maxUploadMb: _int(json['max_upload_mb']),
      approvalRequired: _bool(json['approval_required']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tenant_registration_enabled': tenantRegistrationEnabled,
    'max_tenants_per_unit': maxTenantsPerUnit,
    'min_lease_months': minLeaseMonths,
    'max_lease_months': maxLeaseMonths,
    'required_documents': requiredDocuments
        .map((document) => document.toJson())
        .toList(),
    'allowed_file_types': allowedFileTypes,
    'max_upload_mb': maxUploadMb,
    'approval_required': approvalRequired,
  };
}

class LeaseDocumentRequirement {
  const LeaseDocumentRequirement({
    required this.key,
    required this.label,
    this.required = false,
  });

  final String key;
  final String label;
  final bool required;

  factory LeaseDocumentRequirement.fromJson(Map<String, dynamic> json) {
    return LeaseDocumentRequirement(
      key: _string(json['key']),
      label: _string(json['label']),
      required: _bool(json['required']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
    'required': required,
  };
}

class PaymentConfig {
  const PaymentConfig({
    this.partialPaymentMinAmount,
    this.gateways = const <PaymentGatewayConfig>[],
  });

  final double? partialPaymentMinAmount;
  final List<PaymentGatewayConfig> gateways;

  factory PaymentConfig.fromJson(Map<String, dynamic> json) {
    final gatewaysJson = json['gateways'];
    return PaymentConfig(
      partialPaymentMinAmount: _double(json['partial_payment_min_amount']),
      gateways: gatewaysJson is List
          ? gatewaysJson
                .whereType<Map>()
                .map(
                  (item) => PaymentGatewayConfig.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <PaymentGatewayConfig>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'partial_payment_min_amount': partialPaymentMinAmount,
    'gateways': gateways.map((gateway) => gateway.toJson()).toList(),
  };
}

class PaymentGatewayConfig {
  const PaymentGatewayConfig({
    required this.id,
    required this.name,
    this.enabled = false,
  });

  final String id;
  final String name;
  final bool enabled;

  factory PaymentGatewayConfig.fromJson(Map<String, dynamic> json) {
    return PaymentGatewayConfig(
      id: _string(json['id']),
      name: _string(json['name']),
      enabled: _bool(json['enabled']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'enabled': enabled,
  };
}

class SupportConfig {
  const SupportConfig({this.phone, this.email, this.hours});

  final String? phone;
  final String? email;
  final String? hours;

  factory SupportConfig.fromJson(Map<String, dynamic> json) {
    return SupportConfig(
      phone: _stringOrNull(json['phone']),
      email: _stringOrNull(json['email']),
      hours: _stringOrNull(json['hours']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'phone': phone,
    'email': email,
    'hours': hours,
  };
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1';
}

String _string(Object? value) {
  if (value is String) return value.trim();
  if (value == null || value == false) return '';
  return value.toString();
}

String? _stringOrNull(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => _string(item))
      .where((item) => item.isNotEmpty)
      .toList();
}
