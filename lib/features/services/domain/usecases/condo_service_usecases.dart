import '../entities/condo_service.dart';
import '../repositories/condo_service_repository.dart';

class CondoServiceUseCases {
  const CondoServiceUseCases(this.repository);

  final CondoServiceRepository repository;

  Future<List<CondoService>> getServices() => repository.getServices();

  Future<List<ServiceRequest>> getRequests() => repository.getRequests();

  Future<ServiceRequest> createRequest(ServiceRequest request) =>
      repository.createRequest(request);

  Future<ServiceRequest> updateStatus(ServiceRequest request, ServiceRequestStatus status) =>
      repository.updateStatus(request, status);

  Future<ServiceRequest> cancelRequest(ServiceRequest request) =>
      repository.cancelRequest(request);

  Future<ServiceRequest> rateRequest(ServiceRequest request, int rating, String feedback) =>
      repository.rateRequest(request, rating, feedback);
}
