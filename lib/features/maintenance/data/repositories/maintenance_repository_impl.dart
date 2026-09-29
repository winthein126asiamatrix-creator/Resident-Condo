import '../../domain/entities/maintenance_request.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../datasources/maintenance_local_data_source.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  const MaintenanceRepositoryImpl(this.localDataSource);

  final MaintenanceLocalDataSource localDataSource;

  @override
  Future<List<MaintenanceRequest>> getRequests() async {
    final requests = await localDataSource.getRequests();
    return List<MaintenanceRequest>.of(requests);
  }

  @override
  Future<MaintenanceRequest> createRequest(MaintenanceRequest request) {
    return localDataSource.createRequest(request);
  }

  @override
  Future<MaintenanceRequest> updateStatus(String id, MaintenanceStatus status) {
    return localDataSource.updateStatus(id, status);
  }
}
