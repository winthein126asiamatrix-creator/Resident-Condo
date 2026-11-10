import '../entities/condo_service.dart';

abstract interface class CondoServiceRepository {
  Future<List<CondoService>> getServices();

  /// The catalogue kept on this device, or null when there is no snapshot yet.
  Future<List<CondoService>?> getCachedServices();

  Future<CondoService> getService(int id);

  Future<ServiceRequestPageResult> getRequests({
    required String status,
    int page = 1,
  });

  /// The cached requests for [status], or null when none belong to the resident.
  Future<ServiceRequestPageResult?> getCachedRequests({required String status});

  Future<ServiceRequest> createRequest(ServiceRequest request);

  Future<ServiceRequest> updateStatus(
    ServiceRequest request,
    ServiceRequestStatus status,
  );

  Future<ServiceRequest> cancelRequest(ServiceRequest request);

  Future<ServiceRequest> rateRequest(
    ServiceRequest request,
    int rating,
    String feedback,
  );
}
