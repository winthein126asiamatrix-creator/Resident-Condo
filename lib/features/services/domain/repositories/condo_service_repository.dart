import '../entities/condo_service.dart';

abstract interface class CondoServiceRepository {
  Future<List<CondoService>> getServices();

  Future<List<ServiceRequest>> getRequests();

  Future<ServiceRequest> createRequest(ServiceRequest request);

  Future<ServiceRequest> updateStatus(ServiceRequest request, ServiceRequestStatus status);

  Future<ServiceRequest> cancelRequest(ServiceRequest request);

  Future<ServiceRequest> rateRequest(ServiceRequest request, int rating, String feedback);
}
