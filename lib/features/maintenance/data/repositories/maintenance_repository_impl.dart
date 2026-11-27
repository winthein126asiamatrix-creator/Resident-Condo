import '../../domain/entities/maintenance_request.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../datasources/maintenance_local_data_source.dart';
import '../datasources/maintenance_remote_data_source.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  const MaintenanceRepositoryImpl(this.remoteDataSource, this.localDataSource);

  final MaintenanceRemoteDataSource remoteDataSource;
  final MaintenanceLocalDataSource localDataSource;

  /// How long a cached detail may be served without asking the network.
  ///
  /// List fetches refresh the matching detail entries, so this only matters
  /// when a detail is opened without a recent list load.
  static const Duration _detailCacheTtl = Duration(minutes: 5);

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
        await _syncDetailCache(accountKey, remote.items);
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
    final cached = await localDataSource.readRequestEntry(accountKey, key);
    final cachedRequest = cached?.request;
    final isFresh =
        cached != null &&
        DateTime.now().difference(cached.updatedAt) <= _detailCacheTtl;
    if (!forceRefresh && isFresh) return cachedRequest!;
    try {
      final remote = await remoteDataSource.getRequest(id);
      await localDataSource.saveRequest(accountKey, remote);
      return remote;
    } catch (_) {
      // A failed refresh must never destroy a usable cached detail.
      if (cachedRequest != null) return cachedRequest;
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

  /// Brings already-cached detail entries up to date with a fresh list page.
  ///
  /// The list and detail endpoints share one model, but the list may still omit
  /// detail-only fields (photos, progress history). Entries that are not cached
  /// are left alone so the next Details open fetches the authoritative record
  /// instead of seeding the cache with a possibly partial list item.
  Future<void> _syncDetailCache(
    String accountKey,
    List<MaintenanceRequest> items,
  ) async {
    for (final item in items) {
      final cached = await localDataSource.readRequest(accountKey, item.id);
      if (cached == null) continue;
      await localDataSource.saveRequest(
        accountKey,
        _mergeListIntoDetail(cached, item),
      );
    }
  }

  /// Overlays a list snapshot on a cached detail without erasing detail data.
  MaintenanceRequest _mergeListIntoDetail(
    MaintenanceRequest detail,
    MaintenanceRequest list,
  ) {
    return detail.copyWith(
      // Status and workflow fields are the ones that move between list loads,
      // so the list wins for them.
      status: list.status,
      priority: list.priority,
      technician: list.technician ?? detail.technician,
      assignedAt: list.assignedAt ?? detail.assignedAt,
      inProgressAt: list.inProgressAt ?? detail.inProgressAt,
      completedAt: list.completedAt ?? detail.completedAt,
      cancelledAt: list.cancelledAt ?? detail.cancelledAt,
      // Descriptive fields only win when the list actually carries a value, so
      // a summary response cannot blank what the detail endpoint returned.
      // `description` stays as the detail endpoint wrote it: a list response
      // may hold a truncated excerpt, and the full text is detail-only.
      title: _preferText(list.title, detail.title),
      reference: _preferText(list.reference, detail.reference),
      location: _preferText(list.location, detail.location),
      unit: _preferText(list.unit, detail.unit),
      categoryCode: _preferText(list.categoryCode, detail.categoryCode),
      categoryLabel: _preferText(list.categoryLabel, detail.categoryLabel),
      createdAt: _preferText(list.createdAt, detail.createdAt),
      preferredDate: _preferText(list.preferredDate, detail.preferredDate),
      preferredTime: _preferText(list.preferredTime, detail.preferredTime),
      photoCount: list.photoCount > 0 ? list.photoCount : detail.photoCount,
      photos: list.photos.isEmpty ? detail.photos : list.photos,
      progressHistory: list.progressHistory.isEmpty
          ? detail.progressHistory
          : list.progressHistory,
    );
  }

  String _preferText(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value;
}
