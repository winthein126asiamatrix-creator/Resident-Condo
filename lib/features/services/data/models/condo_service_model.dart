import '../../domain/entities/condo_service.dart';

class CondoServiceModel extends CondoService {
  const CondoServiceModel({
    required super.id,
    required super.category,
    required super.name,
    required super.providerName,
    required super.description,
    required super.pricing,
    super.estimatedDurationMinutes,
    super.bookingFields,
    super.availableDates,
    super.isActive,
  });
}

class ServiceRequestModel extends ServiceRequest {
  const ServiceRequestModel({
    required super.id,
    required super.serviceId,
    required super.serviceName,
    required super.category,
    required super.scheduledDate,
    required super.scheduledSlot,
    required super.status,
    required super.price,
    required super.requestedOn,
    required super.provider,
    super.notes,
    super.feedback,
    super.rating,
    super.slotId,
    super.bookingDetails,
  });
}
