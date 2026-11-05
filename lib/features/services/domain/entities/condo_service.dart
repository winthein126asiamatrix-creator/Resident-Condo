enum ServiceCategory {
  cleaning,
  laundry,
  pestControl,
  waste,
  aircon,
  catering,
  moving,
  other;

  static ServiceCategory fromApiName(String? name) {
    final normalized = (name ?? '').trim().toLowerCase();
    return switch (normalized) {
      'cleaning' => ServiceCategory.cleaning,
      'laundry' => ServiceCategory.laundry,
      'pest control' || 'pest_control' || 'pestcontrol' =>
        ServiceCategory.pestControl,
      'waste' || 'waste & bulky items' => ServiceCategory.waste,
      'aircon' || 'aircon servicing' || 'air conditioning' =>
        ServiceCategory.aircon,
      'catering' => ServiceCategory.catering,
      'moving' || 'moving help' => ServiceCategory.moving,
      _ => ServiceCategory.other,
    };
  }
}

extension ServiceCategoryLabel on ServiceCategory {
  String get label {
    switch (this) {
      case ServiceCategory.cleaning:
        return 'Cleaning';
      case ServiceCategory.laundry:
        return 'Laundry';
      case ServiceCategory.pestControl:
        return 'Pest control';
      case ServiceCategory.waste:
        return 'Waste & bulky items';
      case ServiceCategory.aircon:
        return 'Aircon servicing';
      case ServiceCategory.catering:
        return 'Catering';
      case ServiceCategory.moving:
        return 'Moving help';
      case ServiceCategory.other:
        return 'Other';
    }
  }
}

enum ServiceRequestStatus {
  requested,
  scheduled,
  inProgress,
  completed,
  cancelled,
}

extension ServiceRequestStatusLabel on ServiceRequestStatus {
  String get label {
    switch (this) {
      case ServiceRequestStatus.requested:
        return 'Requested';
      case ServiceRequestStatus.scheduled:
        return 'Scheduled';
      case ServiceRequestStatus.inProgress:
        return 'In progress';
      case ServiceRequestStatus.completed:
        return 'Completed';
      case ServiceRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  ServiceRequestStatus? get next {
    switch (this) {
      case ServiceRequestStatus.requested:
        return ServiceRequestStatus.scheduled;
      case ServiceRequestStatus.scheduled:
        return ServiceRequestStatus.inProgress;
      case ServiceRequestStatus.inProgress:
        return ServiceRequestStatus.completed;
      case ServiceRequestStatus.completed:
      case ServiceRequestStatus.cancelled:
        return null;
    }
  }
}

enum ServicePricingType {
  fixed,
  perUnit,
  perHour,
  quote,
  free;

  static ServicePricingType fromApi(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'per_unit' => ServicePricingType.perUnit,
      'per_hour' => ServicePricingType.perHour,
      'quote' => ServicePricingType.quote,
      'free' => ServicePricingType.free,
      _ => ServicePricingType.fixed,
    };
  }
}

extension ServicePricingTypeLabel on ServicePricingType {
  String get apiValue {
    switch (this) {
      case ServicePricingType.fixed:
        return 'fixed';
      case ServicePricingType.perUnit:
        return 'per_unit';
      case ServicePricingType.perHour:
        return 'per_hour';
      case ServicePricingType.quote:
        return 'quote';
      case ServicePricingType.free:
        return 'free';
    }
  }

}

class ServicePricing {
  const ServicePricing({
    required this.type,
    this.price,
    this.unit,
    this.currency,
  });

  final ServicePricingType type;
  final num? price;
  final String? unit;
  final String? currency;

  factory ServicePricing.fromJson(Map<String, dynamic> json) {
    return ServicePricing(
      type: ServicePricingType.fromApi(json['type']?.toString()),
      price: json['price'] is num ? json['price'] as num : null,
      unit: json['unit']?.toString(),
      currency: json['currency']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.apiValue,
    'price': price,
    'unit': unit,
    'currency': currency,
  };
}

enum ServiceBookingFieldType {
  quantity,
  text,
  singleSelect,
  multiSelect;

  static ServiceBookingFieldType fromApi(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'text' => ServiceBookingFieldType.text,
      'single_select' => ServiceBookingFieldType.singleSelect,
      'multi_select' => ServiceBookingFieldType.multiSelect,
      _ => ServiceBookingFieldType.quantity,
    };
  }
}

extension ServiceBookingFieldTypeLabel on ServiceBookingFieldType {
  String get apiValue {
    switch (this) {
      case ServiceBookingFieldType.quantity:
        return 'quantity';
      case ServiceBookingFieldType.text:
        return 'text';
      case ServiceBookingFieldType.singleSelect:
        return 'single_select';
      case ServiceBookingFieldType.multiSelect:
        return 'multi_select';
    }
  }

}

class ServiceBookingField {
  const ServiceBookingField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.min,
    this.max,
    this.options = const <String>[],
  });

  final String key;
  final String label;
  final ServiceBookingFieldType type;
  final bool required;
  final num? min;
  final num? max;
  final List<String> options;

  factory ServiceBookingField.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'];
    return ServiceBookingField(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: ServiceBookingFieldType.fromApi(json['type']?.toString()),
      required: json['required'] == true,
      min: json['min'] is num ? json['min'] as num : null,
      max: json['max'] is num ? json['max'] as num : null,
      options: optionsJson is List
          ? optionsJson.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
    'type': type.apiValue,
    'required': required,
    'min': min,
    'max': max,
    'options': options,
  };
}

class ServiceTimeSlot {
  const ServiceTimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  final int id;
  final String startTime;
  final String endTime;
  final String status;

  bool get isAvailable => status.toLowerCase() == 'available';

  factory ServiceTimeSlot.fromJson(Map<String, dynamic> json) {
    return ServiceTimeSlot(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'start_time': startTime,
    'end_time': endTime,
    'status': status,
  };
}

class ServiceAvailableDate {
  const ServiceAvailableDate({
    required this.date,
    this.slots = const <ServiceTimeSlot>[],
  });

  final String date;
  final List<ServiceTimeSlot> slots;

  factory ServiceAvailableDate.fromJson(Map<String, dynamic> json) {
    final slotsJson = json['slots'];
    return ServiceAvailableDate(
      date: json['date']?.toString() ?? '',
      slots: slotsJson is List
          ? slotsJson
              .whereType<Map>()
              .map((e) => ServiceTimeSlot.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <ServiceTimeSlot>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': date,
    'slots': slots.map((s) => s.toJson()).toList(),
  };
}

/// Bookable condo service. Service fees are billed on their own invoice line
/// and never merged with the monthly condo fee.
class CondoService {
  const CondoService({
    required this.id,
    required this.category,
    required this.name,
    required this.providerName,
    required this.description,
    required this.pricing,
    this.estimatedDurationMinutes,
    this.bookingFields = const <ServiceBookingField>[],
    this.availableDates = const <ServiceAvailableDate>[],
    this.isActive = true,
  });

  final int id;
  final ServiceCategory category;
  final String name;
  final String providerName;
  final String description;
  final ServicePricing pricing;
  final int? estimatedDurationMinutes;
  final List<ServiceBookingField> bookingFields;
  final List<ServiceAvailableDate> availableDates;
  final bool isActive;

  String get provider => providerName;
  double get price => (pricing.price ?? 0).toDouble();
  String get unit => pricing.unit ?? pricing.type.apiValue;
  int get leadTimeDays =>
      estimatedDurationMinutes == null ? 1 : (estimatedDurationMinutes! / 1440).ceil().clamp(1, 365);

  factory CondoService.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final pricingJson = json['pricing'];
    final bookingFieldsJson = json['booking_fields'];
    final availableDatesJson = json['available_dates'];
    return CondoService(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      category: categoryJson is Map
          ? ServiceCategory.fromApiName(categoryJson['name']?.toString())
          : ServiceCategory.fromApiName(json['category']?.toString()),
      name: json['name']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pricing: pricingJson is Map
          ? ServicePricing.fromJson(Map<String, dynamic>.from(pricingJson))
          : const ServicePricing(type: ServicePricingType.fixed),
      estimatedDurationMinutes: json['estimated_duration_minutes'] is num
          ? (json['estimated_duration_minutes'] as num).toInt()
          : null,
      bookingFields: bookingFieldsJson is List
          ? bookingFieldsJson
              .whereType<Map>()
              .map((e) => ServiceBookingField.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <ServiceBookingField>[],
      availableDates: availableDatesJson is List
          ? availableDatesJson
              .whereType<Map>()
              .map((e) => ServiceAvailableDate.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <ServiceAvailableDate>[],
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': <String, dynamic>{
      'id': null,
      'name': category.label,
    },
    'name': name,
    'provider_name': providerName,
    'description': description,
    'pricing': pricing.toJson(),
    'estimated_duration_minutes': estimatedDurationMinutes,
    'booking_fields': bookingFields.map((f) => f.toJson()).toList(),
    'available_dates': availableDates.map((d) => d.toJson()).toList(),
    'is_active': isActive,
  };
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.category,
    required this.scheduledDate,
    required this.scheduledSlot,
    required this.status,
    required this.price,
    required this.requestedOn,
    required this.provider,
    this.notes = '',
    this.feedback,
    this.rating,
    this.slotId,
    this.bookingDetails = const <String, dynamic>{},
  });

  final String id;
  final int serviceId;
  final String serviceName;
  final ServiceCategory category;
  final String scheduledDate;
  final String scheduledSlot;
  final ServiceRequestStatus status;
  final double price;
  final String requestedOn;
  final String provider;
  final String notes;
  final String? feedback;
  final int? rating;
  final int? slotId;
  final Map<String, dynamic> bookingDetails;

  bool get canCancel =>
      status == ServiceRequestStatus.requested ||
      status == ServiceRequestStatus.scheduled;

  bool get canRate =>
      status == ServiceRequestStatus.completed && rating == null;

  ServiceRequest copyWith({
    ServiceRequestStatus? status,
    String? feedback,
    int? rating,
  }) {
    return ServiceRequest(
      id: id,
      serviceId: serviceId,
      serviceName: serviceName,
      category: category,
      scheduledDate: scheduledDate,
      scheduledSlot: scheduledSlot,
      status: status ?? this.status,
      price: price,
      requestedOn: requestedOn,
      provider: provider,
      notes: notes,
      feedback: feedback ?? this.feedback,
      rating: rating ?? this.rating,
      slotId: slotId,
      bookingDetails: bookingDetails,
    );
  }
}
