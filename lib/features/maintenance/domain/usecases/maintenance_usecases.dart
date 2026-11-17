import '../entities/maintenance_request.dart';
import '../repositories/maintenance_repository.dart';

class MaintenanceUseCases {
  const MaintenanceUseCases(this.repository);

  final MaintenanceRepository repository;

  Future<List<MaintenanceCategoryOption>> getCategories({
    bool forceRefresh = false,
  }) {
    return repository.getCategories(forceRefresh: forceRefresh);
  }

  Future<List<MaintenanceCategoryOption>?> getCachedCategories() =>
      repository.getCachedCategories();

  Future<MaintenancePageResult?> getCachedRequests(String accountKey) =>
      repository.getCachedRequests(accountKey);

  Future<MaintenanceRequest?> getCachedRequest(String accountKey, Object id) =>
      repository.getCachedRequest(accountKey, id);

  Future<MaintenanceSummary?> getCachedSummary(String accountKey) =>
      repository.getCachedSummary(accountKey);

  Future<MaintenancePageResult> getRequests({
    required String accountKey,
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    bool forceRefresh = false,
  }) {
    return repository.getRequests(
      accountKey: accountKey,
      page: page,
      limit: limit,
      status: status,
      category: category,
      forceRefresh: forceRefresh,
    );
  }

  Future<MaintenanceRequest> getRequest(
    String accountKey,
    Object id, {
    bool forceRefresh = false,
  }) {
    return repository.getRequest(accountKey, id, forceRefresh: forceRefresh);
  }

  Future<MaintenanceSummary> getSummary(
    String accountKey, {
    bool forceRefresh = false,
  }) {
    return repository.getSummary(accountKey, forceRefresh: forceRefresh);
  }

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
    List<MaintenancePhotoUpload> photos = const <MaintenancePhotoUpload>[],
  }) {
    return repository.createRequest(
      accountKey: accountKey,
      title: title,
      categoryCode: categoryCode,
      description: description,
      location: location,
      priority: priority,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      photos: photos,
      unitId: unitId
    );
  }

  Future<MaintenanceCancellation> cancelRequest({
    required String accountKey,
    required String id,
    required String reason,
  }) {
    return repository.cancelRequest(
      accountKey: accountKey,
      id: id,
      reason: reason,
    );
  }
}
