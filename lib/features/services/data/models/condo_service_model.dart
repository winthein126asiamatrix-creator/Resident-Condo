import '../../domain/entities/condo_service.dart';

class CondoServiceModel extends CondoService {
  const CondoServiceModel({
    required super.id,
    required super.name,
    required super.category,
    required super.description,
    required super.price,
    required super.unit,
    required super.leadTimeDays,
    required super.provider,
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
  });
}
