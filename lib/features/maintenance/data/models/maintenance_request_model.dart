import '../../domain/entities/maintenance_request.dart';

class MaintenanceRequestModel extends MaintenanceRequest {
  const MaintenanceRequestModel({
    required super.id,
    required super.title,
    required super.category,
    required super.description,
    required super.location,
    required super.priority,
    required super.status,
    required super.createdAt,
    required super.preferredDate,
    required super.preferredTime,
    required super.photoNames,
    super.technician,
  });
}
