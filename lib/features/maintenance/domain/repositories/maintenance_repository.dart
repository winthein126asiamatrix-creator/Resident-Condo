import '../../domain/entities/maintenance_request.dart';

abstract interface class MaintenanceRepository {
  Future<List<MaintenanceRequest>> getRequests();

  Future<MaintenanceRequest> createRequest(MaintenanceRequest request);

  Future<MaintenanceRequest> updateStatus(String id, MaintenanceStatus status);
}
