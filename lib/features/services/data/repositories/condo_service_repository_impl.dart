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
    return remoteDataSource.getServices();
  }

  @override
  Future<CondoService> getService(int id) async {
    return remoteDataSource.getService(id);
  }

  @override
  Future<ServiceRequestPageResult> getRequests({
    required String status,
    int page = 1,
  }) => remoteDataSource.getRequests(status: status, page: page);

  @override
  Future<ServiceRequest> createRequest(ServiceRequest request) =>
      remoteDataSource.createRequest(request);

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
