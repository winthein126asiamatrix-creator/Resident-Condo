import '../entities/condo_service.dart';
import '../repositories/condo_service_repository.dart';

class CondoServiceUseCases {
  const CondoServiceUseCases(this.repository);

  final CondoServiceRepository repository;

  Future<List<CondoService>> getServices() => repository.getServices();

  Future<CondoService> getService(int id) => repository.getService(id);

  Future<ServiceRequestPageResult> getRequests({
    required String status,
    int page = 1,
  }) => repository.getRequests(status: status, page: page);

  Future<ServiceRequest> createRequest(ServiceRequest request) =>
      repository.createRequest(request);

  Future<ServiceRequest> updateStatus(
    ServiceRequest request,
    ServiceRequestStatus status,
  ) => repository.updateStatus(request, status);

  Future<ServiceRequest> cancelRequest(ServiceRequest request) =>
      repository.cancelRequest(request);

  Future<ServiceRequest> rateRequest(
    ServiceRequest request,
    int rating,
    String feedback,
  ) => repository.rateRequest(request, rating, feedback);
}
