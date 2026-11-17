import '../../domain/entities/maintenance_request.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../datasources/maintenance_local_data_source.dart';
import '../datasources/maintenance_remote_data_source.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  const MaintenanceRepositoryImpl(this.remoteDataSource, this.localDataSource);

  final MaintenanceRemoteDataSource remoteDataSource;
  final MaintenanceLocalDataSource localDataSource;

  @override
  Future<List<MaintenanceCategoryOption>> getCategories({
    bool forceRefresh = false,
  }) async {
    final cached = await localDataSource.readCategories();
    if (!forceRefresh && cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final remote = await remoteDataSource.getCategories();
      if (remote.isNotEmpty) {
        await localDataSource.saveCategories(remote);
        return remote;
      }
      return cached ?? remote;
    } catch (_) {
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  @override
  Future<List<MaintenanceCategoryOption>?> getCachedCategories() =>
      localDataSource.readCategories();

  @override
  Future<MaintenancePageResult?> getCachedRequests(String accountKey) =>
      localDataSource.readRequests(accountKey);

  @override
  Future<MaintenanceRequest?> getCachedRequest(String accountKey, Object id) =>
      localDataSource.readRequest(accountKey, id.toString());

  @override
  Future<MaintenanceSummary?> getCachedSummary(String accountKey) =>
      localDataSource.readSummary(accountKey);

  @override
  Future<MaintenancePageResult> getRequests({
    required String accountKey,
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    bool forceRefresh = false,
  }) async {
    final cached = page == 1
        ? await localDataSource.readRequests(accountKey)
        : null;
    if (!forceRefresh && cached != null && cached.items.isNotEmpty) {
      return cached;
    }
    try {
      final remote = await remoteDataSource.getRequests(
        page: page,
        limit: limit,
        status: status,
        category: category,
      );
      if (page == 1) {
        await localDataSource.saveRequests(accountKey, remote);
      }
      return remote;
    } catch (_) {
      if (cached != null && cached.items.isNotEmpty) return cached;
      rethrow;
    }
  }

  @override
  Future<MaintenanceRequest> getRequest(
    String accountKey,
    Object id, {
    bool forceRefresh = false,
  }) async {
    final key = id.toString();
    final cached = await localDataSource.readRequest(accountKey, key);
    if (!forceRefresh && cached != null) return cached;
    try {
      final remote = await remoteDataSource.getRequest(id);
      await localDataSource.saveRequest(accountKey, remote);
      return remote;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<MaintenanceSummary> getSummary(
    String accountKey, {
    bool forceRefresh = false,
  }) async {
    final cached = await localDataSource.readSummary(accountKey);
    if (!forceRefresh && cached != null) return cached;
    try {
      final remote = await remoteDataSource.getSummary();
      await localDataSource.saveSummary(accountKey, remote);
      return remote;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
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
  }) async {
    final created = await remoteDataSource.createRequest(
      title: title,
      categoryCode: categoryCode,
      description: description,
      location: location,
      priority: priority,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      unitId: unitId,
      photos: photos,
    );
    await localDataSource.saveRequest(accountKey, created);
    await localDataSource.invalidateRequests(accountKey);
    await localDataSource.invalidateSummary(accountKey);
    return created;
  }

  @override
  Future<MaintenanceCancellation> cancelRequest({
    required String accountKey,
    required String id,
    required String reason,
  }) async {
    final cancellation = await remoteDataSource.cancelRequest(
      id: id,
      reason: reason,
    );
    final cached = await localDataSource.readRequest(accountKey, id);
    if (cached != null) {
      await localDataSource.saveRequest(
        accountKey,
        cached.copyWith(
          status: MaintenanceStatus.cancelled,
          cancelledAt:
              cancellation.cancelledAt ??
              DateTime.now().toUtc().toIso8601String(),
        ),
      );
    }
    await localDataSource.invalidateRequests(accountKey);
    await localDataSource.invalidateSummary(accountKey);
    return cancellation;
  }
}
