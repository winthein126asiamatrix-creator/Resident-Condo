enum ServiceCategory {
  cleaning,
  laundry,
  pestControl,
  waste,
  aircon,
  catering,
  moving,
  other;

  static ServiceCategory fromApiCategory(Map<String, dynamic> json) {
    final code = json['code'];
    final label = json['label'] ?? json['name'];
    return fromApiName(code is String ? code : label?.toString());
  }

  static ServiceCategory fromApiName(String? name) {
    final normalized = (name ?? '').trim().toLowerCase();
    return switch (normalized) {
      'cleaning' => ServiceCategory.cleaning,
      'laundry' || 'laundary' => ServiceCategory.laundry,
      'pest control' ||
      'pest_control' ||
      'pestcontrol' => ServiceCategory.pestControl,
      'waste' || 'waste & bulky items' => ServiceCategory.waste,
      'aircon' ||
      'aircon servicing' ||
      'air conditioning' => ServiceCategory.aircon,
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
  cancelled;

  static ServiceRequestStatus fromApi(String? value) {
    return switch ((value ?? '').trim().toLowerCase().replaceAll('-', '_')) {
      'submitted' || 'requested' => ServiceRequestStatus.requested,
      'scheduled' ||
      'confirmed' ||
      'approved' => ServiceRequestStatus.scheduled,
      'in_progress' ||
      'ongoing' ||
      'started' => ServiceRequestStatus.inProgress,
      'completed' || 'done' => ServiceRequestStatus.completed,
      'cancelled' || 'canceled' || 'rejected' => ServiceRequestStatus.cancelled,
      _ => ServiceRequestStatus.requested,
    };
  }
}

extension ServiceRequestStatusGroup on ServiceRequestStatus {
  bool get isActive =>
      this == ServiceRequestStatus.requested ||
      this == ServiceRequestStatus.scheduled ||
      this == ServiceRequestStatus.inProgress;

  bool get isHistory =>
      this == ServiceRequestStatus.completed ||
      this == ServiceRequestStatus.cancelled;
}

extension ServiceRequestStatusWire on ServiceRequestStatus {
  /// The backend spelling, used when this status is written to the cache and
  /// read back through [ServiceRequestStatus.fromApi].
  String get apiValue {
    switch (this) {
      case ServiceRequestStatus.requested:
        return 'requested';
      case ServiceRequestStatus.scheduled:
        return 'scheduled';
      case ServiceRequestStatus.inProgress:
        return 'in_progress';
      case ServiceRequestStatus.completed:
        return 'completed';
      case ServiceRequestStatus.cancelled:
        return 'cancelled';
    }
  }
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
    final unit = json['unit'] ?? json['unit_label'];
    final price = json['price'] ?? json['amount'];
    return ServicePricing(
      type: ServicePricingType.fromApi(json['type']?.toString()),
      price: price is num ? price : null,
      unit: unit is String && unit.trim().isNotEmpty && unit != 'false'
          ? unit
          : null,
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
    this.defaultValue,
  });

  final String key;
  final String label;
  final ServiceBookingFieldType type;
  final bool required;
  final num? min;
  final num? max;
  final List<String> options;
  final Object? defaultValue;

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
      defaultValue: json['default'],
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
    'default': defaultValue,
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
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
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
                .map(
                  (e) => ServiceTimeSlot.fromJson(Map<String, dynamic>.from(e)),
                )
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
    this.providerName = '',
    this.description = '',
    this.pricing = const ServicePricing(type: ServicePricingType.fixed),
    this.estimatedDurationMinutes,
    this.bookingFields = const <ServiceBookingField>[],
    this.availableDates = const <ServiceAvailableDate>[],
    this.isActive = true,
    this.categoryId,
    this.categoryCode,
    this.categoryLabel,
    this.icon,
    this.noticeDays,
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
  final int? categoryId;
  final String? categoryCode;
  final String? categoryLabel;
  final Object? icon;
  final int? noticeDays;

  String get provider => providerName;
  double get price => (pricing.price ?? 0).toDouble();
  String get unit => pricing.unit ?? pricing.type.apiValue;
  int get leadTimeDays => estimatedDurationMinutes == null
      ? 1
      : (estimatedDurationMinutes! / 1440).ceil().clamp(1, 365);

  static CondoService parse(Object? json) {
    if (json is! Map) {
      return const CondoService(
        id: 0,
        category: ServiceCategory.other,
        name: '',
      );
    }
    return CondoService.fromJson(Map<String, dynamic>.from(json));
  }

  factory CondoService.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    Map<String, dynamic>? categoryMap;
    if (categoryJson is Map) {
      categoryMap = Map<String, dynamic>.from(categoryJson);
    }
    final categoryId = categoryMap == null
        ? null
        : (categoryMap['id'] is int
              ? categoryMap['id'] as int
              : int.tryParse('${categoryMap['id']}'));
    final categoryCode = categoryMap == null
        ? null
        : (categoryMap['code'] is String
              ? categoryMap['code'] as String
              : null);
    final categoryLabel = categoryMap == null
        ? null
        : (categoryMap['label'] is String
              ? categoryMap['label'] as String
              : (categoryMap['name'] is String
                    ? categoryMap['name'] as String
                    : null));

    final pricingJson = json['pricing'];
    ServicePricing pricing;
    if (pricingJson is Map) {
      pricing = ServicePricing.fromJson(Map<String, dynamic>.from(pricingJson));
    } else {
      final priceJson = json['price'];
      final amount = priceJson is Map && priceJson['amount'] is num
          ? (priceJson['amount'] as num)
          : (priceJson is num ? priceJson : null);
      final currency = priceJson is Map
          ? priceJson['currency']?.toString()
          : null;
      final pricingUnitJson = json['pricing_unit'];
      String? unit;
      if (pricingUnitJson is Map) {
        unit = pricingUnitJson['label'] is String
            ? pricingUnitJson['label'] as String
            : (pricingUnitJson['text'] is String
                  ? pricingUnitJson['text'] as String
                  : null);
      }
      pricing = ServicePricing(
        type: ServicePricingType.fixed,
        price: amount,
        unit: unit,
        currency: currency,
      );
    }

    final bookingFieldsJson = json['booking_fields'];
    final availabilityJson = json['availability'];
    final availableDatesJson =
        json['available_dates'] ??
        (availabilityJson is Map ? availabilityJson['dates'] : null);
    final description = json['description'];
    final provider = json['provider_name'] ?? json['provider'];
    String providerName = '';
    if (provider is String) {
      providerName = provider == 'false' ? '' : provider;
    } else if (provider is Map) {
      final name = provider['name'];
      providerName = name is String ? name : '';
    }
    final icon = json['icon'];
    final noticeDays = json['notice_days'];

    //final availabilityJson = json['availability'];
    // List<dynamic>? availableDatesJson = json['available_dates'] as List?;
    // if (availableDatesJson == null && availabilityJson is Map) {
    //   availableDatesJson = availabilityJson['dates'] as List?;
    // }

    return CondoService(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      category: categoryMap != null
          ? ServiceCategory.fromApiCategory(categoryMap)
          : ServiceCategory.fromApiName(json['category']?.toString()),
      name: json['name']?.toString() ?? '',
      providerName: providerName,
      description: description is String ? description : '',
      pricing: pricing,
      estimatedDurationMinutes: json['estimated_duration_minutes'] is num
          ? (json['estimated_duration_minutes'] as num).toInt()
          : null,
      bookingFields: bookingFieldsJson is List
          ? bookingFieldsJson
                .whereType<Map>()
                .map(
                  (e) => ServiceBookingField.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const <ServiceBookingField>[],
      availableDates: availableDatesJson is List
          ? availableDatesJson
                .whereType<Map>()
                .map(
                  (e) => ServiceAvailableDate.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const <ServiceAvailableDate>[],
      isActive: json['is_active'] != false,
      categoryId: categoryId,
      categoryCode: categoryCode,
      categoryLabel: categoryLabel,
      icon: icon == false ? null : icon,
      noticeDays: noticeDays is num ? noticeDays.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': <String, dynamic>{
      'id': categoryId,
      'code': categoryCode,
      'name': categoryLabel ?? category.label,
      'label': categoryLabel ?? category.label,
    },
    'name': name,
    'provider_name': providerName,
    'description': description,
    'pricing': pricing.toJson(),
    'estimated_duration_minutes': estimatedDurationMinutes,
    'booking_fields': bookingFields.map((f) => f.toJson()).toList(),
    'available_dates': availableDates.map((d) => d.toJson()).toList(),
    'is_active': isActive,
    'icon': icon,
    'notice_days': noticeDays,
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
    this.code = '',
    this.currency = 'MMK',
    this.statusLabel,
    this.qty = 1,
    this.notes = '',
    this.feedback,
    this.rating,
    this.slotId,
    this.bookingDetails = const <String, dynamic>{},
  });

  final String id;
  final String code;
  final int serviceId;
  final String serviceName;
  final ServiceCategory category;
  final String scheduledDate;
  final String scheduledSlot;
  final ServiceRequestStatus status;
  final String? statusLabel;
  final double price;
  final String currency;
  final int qty;
  final String requestedOn;
  final String provider;
  final String notes;
  final String? feedback;
  final int? rating;
  final int? slotId;
  final Map<String, dynamic> bookingDetails;

  String get displayStatus => statusLabel ?? status.label;

  bool get canCancel =>
      status == ServiceRequestStatus.requested ||
      status == ServiceRequestStatus.scheduled;

  bool get canRate =>
      status == ServiceRequestStatus.completed && rating == null;

  factory ServiceRequest.fromJson(Object? json, {ServiceRequest? fallback}) {
    if (json is! Map) {
      return fallback ??
          (throw const FormatException('Invalid service request response'));
    }
    final map = Map<String, dynamic>.from(json);
    final serviceJson = map['service'] is Map
        ? Map<String, dynamic>.from(map['service'] as Map)
        : null;

    String? asString(Object? value) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
      return null;
    }

    int? asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    double? asDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value');
    }

    String providerOf(Object? value) {
      if (value is String) {
        return value == 'false' ? '' : value;
      }
      if (value is Map) {
        return asString(value['name']) ?? '';
      }
      return '';
    }

    final categoryJson = map['category'] ?? serviceJson?['category'];
    var category = fallback?.category ?? ServiceCategory.other;
    if (categoryJson is Map) {
      category = ServiceCategory.fromApiCategory(
        Map<String, dynamic>.from(categoryJson),
      );
    } else if (categoryJson is String) {
      category = ServiceCategory.fromApiName(categoryJson);
    }

    final amountJson = map['amount'];
    final priceJson = map['price'] ?? map['total_price'];
    final servicePricingJson = serviceJson?['pricing'];
    double? price;
    String? currency;
    if (amountJson is num) {
      price = amountJson.toDouble();
    } else if (amountJson is Map) {
      price = asDouble(amountJson['amount'] ?? amountJson['price']);
      currency = asString(amountJson['currency']);
    } else if (priceJson is num) {
      price = priceJson.toDouble();
    } else if (priceJson is Map) {
      price = asDouble(priceJson['amount'] ?? priceJson['price']);
      currency = asString(priceJson['currency']);
    } else if (servicePricingJson is Map) {
      price = asDouble(
        servicePricingJson['amount'] ?? servicePricingJson['price'],
      );
      currency = asString(servicePricingJson['currency']);
    } else if (serviceJson?['price'] is num) {
      price = (serviceJson!['price'] as num).toDouble();
    }
    price ??= fallback?.price ?? 0;
    currency ??= fallback?.currency ?? 'MMK';

    final start = asString(map['start_time']);
    final end = asString(map['end_time']);
    final scheduledSlot = start != null
        ? (end != null ? '$start - $end' : start)
        : asString(map['scheduled_slot'] ?? map['slot']) ??
              fallback?.scheduledSlot ??
              '';

    final rawStatus = asString(map['status']);
    final status = rawStatus == null
        ? (fallback?.status ?? ServiceRequestStatus.requested)
        : ServiceRequestStatus.fromApi(rawStatus);

    final providerValue =
        map['provider'] ?? map['provider_name'] ?? serviceJson?['provider'];
    final providerName = providerOf(providerValue);
    final provider = providerName.isNotEmpty
        ? providerName
        : fallback?.provider ?? '';

    final bookingDetails = map['booking_details'] is Map
        ? Map<String, dynamic>.from(map['booking_details'] as Map)
        : fallback?.bookingDetails ?? const <String, dynamic>{};

    return ServiceRequest(
      id: asString(map['id'] ?? map['reference']) ?? fallback?.id ?? '',
      code: asString(map['code']) ?? fallback?.code ?? '',
      serviceId:
          asInt(map['service_id'] ?? serviceJson?['id']) ??
          fallback?.serviceId ??
          0,
      serviceName:
          asString(map['service_name'] ?? serviceJson?['name']) ??
          fallback?.serviceName ??
          '',
      category: category,
      scheduledDate:
          asString(map['date'] ?? map['scheduled_date']) ??
          fallback?.scheduledDate ??
          '',
      scheduledSlot: scheduledSlot,
      status: status,
      statusLabel: asString(map['status_label']) ?? fallback?.statusLabel,
      price: price,
      currency: currency,
      qty: asInt(map['qty'] ?? map['quantity']) ?? fallback?.qty ?? 1,
      requestedOn:
          asString(map['requested_on'] ?? map['created_at']) ??
          fallback?.requestedOn ??
          '',
      provider: provider,
      notes: asString(map['note'] ?? map['notes']) ?? fallback?.notes ?? '',
      feedback: asString(map['feedback']) ?? fallback?.feedback,
      rating: asInt(map['rating']) ?? fallback?.rating,
      slotId: asInt(map['slot_id']) ?? fallback?.slotId,
      bookingDetails: bookingDetails,
    );
  }

  /// The shape written to the device cache.
  ///
  /// Uses the same keys [ServiceRequest.fromJson] reads, so a cached request is
  /// rebuilt with every field the detail screen relies on.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (code.isNotEmpty) 'code': code,
    'service_id': serviceId,
    'service_name': serviceName,
    'category': <String, dynamic>{'name': category.label},
    'date': scheduledDate,
    'scheduled_slot': scheduledSlot,
    'status': status.apiValue,
    if (statusLabel != null) 'status_label': statusLabel,
    'amount': <String, dynamic>{'amount': price, 'currency': currency},
    'qty': qty,
    'requested_on': requestedOn,
    'provider': provider,
    if (notes.isNotEmpty) 'note': notes,
    if (feedback != null) 'feedback': feedback,
    if (rating != null) 'rating': rating,
    if (slotId != null) 'slot_id': slotId,
    'booking_details': bookingDetails,
  };

  ServiceRequest copyWith({
    ServiceRequestStatus? status,
    String? statusLabel,
    String? feedback,
    int? rating,
  }) {
    return ServiceRequest(
      id: id,
      code: code,
      serviceId: serviceId,
      serviceName: serviceName,
      category: category,
      scheduledDate: scheduledDate,
      scheduledSlot: scheduledSlot,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      price: price,
      currency: currency,
      qty: qty,
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

class ServiceRequestPageResult {
  const ServiceRequestPageResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<ServiceRequest> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;

  static const ServiceRequestPageResult empty = ServiceRequestPageResult(
    items: <ServiceRequest>[],
    page: 1,
    limit: 20,
    total: 0,
  );
}
