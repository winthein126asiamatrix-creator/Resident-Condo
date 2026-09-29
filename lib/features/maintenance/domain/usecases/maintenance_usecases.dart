import '../entities/maintenance_request.dart';
import '../repositories/maintenance_repository.dart';

class MaintenanceUseCases {
  const MaintenanceUseCases(this.repository);

  final MaintenanceRepository repository;

  Future<List<MaintenanceRequest>> getRequests() {
    return repository.getRequests();
  }

  Future<MaintenanceRequest> createRequest(MaintenanceRequest request) {
    return repository.createRequest(request);
  }

  Future<MaintenanceRequest> updateStatus(String id, MaintenanceStatus status) {
    return repository.updateStatus(id, status);
  }
}
