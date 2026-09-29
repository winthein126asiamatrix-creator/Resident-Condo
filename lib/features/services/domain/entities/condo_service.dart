enum ServiceCategory { cleaning, laundry, pestControl, waste, aircon, catering, moving, other }

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

enum ServiceRequestStatus { requested, scheduled, inProgress, completed, cancelled }

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

/// Bookable condo service. Service fees are billed on their own invoice line
/// and never merged with the monthly condo fee.
class CondoService {
  const CondoService({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.unit,
    required this.leadTimeDays,
    required this.provider,
  });

  final String id;
  final String name;
  final ServiceCategory category;
  final String description;
  final double price;
  final String unit;
  final int leadTimeDays;
  final String provider;
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
  });

  final String id;
  final String serviceId;
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

  bool get canCancel =>
      status == ServiceRequestStatus.requested || status == ServiceRequestStatus.scheduled;

  bool get canRate => status == ServiceRequestStatus.completed && rating == null;

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
    );
  }
}
