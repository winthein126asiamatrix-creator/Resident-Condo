import '../entities/maintenance_request.dart';

abstract interface class MaintenanceRepository {
  Future<List<MaintenanceCategoryOption>> getCategories({
    bool forceRefresh = false,
  });

  Future<List<MaintenanceCategoryOption>?> getCachedCategories();

  Future<MaintenancePageResult?> getCachedRequests(String accountKey);

  Future<MaintenanceRequest?> getCachedRequest(String accountKey, Object id);

  Future<MaintenanceSummary?> getCachedSummary(String accountKey);

  Future<MaintenancePageResult> getRequests({
    required String accountKey,
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    bool forceRefresh = false,
  });

  Future<MaintenanceRequest> getRequest(
    String accountKey,
    Object id, {
    bool forceRefresh = false,
  });

  Future<MaintenanceSummary> getSummary(
    String accountKey, {
    bool forceRefresh = false,
  });

  Future<MaintenanceRequest> createRequest({
    required String accountKey,
    required String title,
    required String categoryCode,
    required String description,
    required String location,
    required MaintenancePriority priority,
    required String preferredDate,
    required String preferredTime,
    required String unitId,
    List<MaintenancePhotoUpload> photos,
  });

  Future<MaintenanceCancellation> cancelRequest({
    required String accountKey,
    required String id,
    required String reason,
  });
}
