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
  factory ServiceRequestModel.fromEntity(ServiceRequest request) {
    return ServiceRequestModel(
      id: request.id,
      serviceId: request.serviceId,
      serviceName: request.serviceName,
      category: request.category,
      scheduledDate: request.scheduledDate,
      scheduledSlot: request.scheduledSlot,
      status: request.status,
      price: request.price,
      requestedOn: request.requestedOn,
      provider: request.provider,
      code: request.code,
      currency: request.currency,
      statusLabel: request.statusLabel,
      qty: request.qty,
      notes: request.notes,
      feedback: request.feedback,
      rating: request.rating,
      slotId: request.slotId,
      bookingDetails: request.bookingDetails,
    );
  }

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
    super.code,
    super.currency,
    super.statusLabel,
    super.qty,
    super.notes,
    super.feedback,
    super.rating,
    super.slotId,
    super.bookingDetails,
  });
}
