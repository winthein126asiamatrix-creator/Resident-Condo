import '../../domain/entities/condo_service.dart';
import '../../domain/repositories/condo_service_repository.dart';
import '../datasources/condo_service_local_data_source.dart';

class CondoServiceRepositoryImpl implements CondoServiceRepository {
  const CondoServiceRepositoryImpl(this.localDataSource);

  final CondoServiceLocalDataSource localDataSource;

  @override
  Future<List<CondoService>> getServices() async {
    final services = await localDataSource.getServices();
    return List<CondoService>.of(services);
  }

  @override
  Future<List<ServiceRequest>> getRequests() async {
    final requests = await localDataSource.getRequests();
    return List<ServiceRequest>.of(requests);
  }

  @override
  Future<ServiceRequest> createRequest(ServiceRequest request) =>
      localDataSource.createRequest(request);

  @override
  Future<ServiceRequest> updateStatus(
    ServiceRequest request,
    ServiceRequestStatus status,
  ) => localDataSource.updateStatus(request, status);

  @override
  Future<ServiceRequest> cancelRequest(ServiceRequest request) =>
      localDataSource.cancelRequest(request);

  @override
  Future<ServiceRequest> rateRequest(
    ServiceRequest request,
    int rating,
    String feedback,
  ) => localDataSource.rateRequest(request, rating, feedback);
}
