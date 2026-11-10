import '../../domain/entities/condo_service.dart';
import '../../domain/repositories/condo_service_repository.dart';
import '../datasources/condo_service_local_data_source.dart';
import '../datasources/condo_service_remote_data_source.dart';

class CondoServiceRepositoryImpl implements CondoServiceRepository {
  const CondoServiceRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final CondoServiceRemoteDataSource remoteDataSource;
  final CondoServiceLocalDataSource localDataSource;

  @override
  Future<List<CondoService>> getServices() async {
    final services = await remoteDataSource.getServices();
    await localDataSource.saveServices(services);
    return services;
  }

  @override
  Future<List<CondoService>?> getCachedServices() {
    return localDataSource.readServices();
  }

  @override
  Future<CondoService> getService(int id) {
    return remoteDataSource.getService(id);
  }

  @override
  Future<ServiceRequestPageResult> getRequests({
    required String status,
    int page = 1,
  }) async {
    final requests = await remoteDataSource.getRequests(
      status: status,
      page: page,
    );
    await localDataSource.saveRequests(status, requests);
    return requests;
  }

  @override
  Future<ServiceRequestPageResult?> getCachedRequests({
    required String status,
  }) {
    return localDataSource.readRequests(status);
  }

  @override
  Future<ServiceRequest> createRequest(ServiceRequest request) async {
    final created = await remoteDataSource.createRequest(request);
    await localDataSource.addRequest(created);
    return created;
  }

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
