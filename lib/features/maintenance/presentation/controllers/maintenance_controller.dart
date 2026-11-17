import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/network/refresh_registry.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../domain/entities/maintenance_request.dart';
import '../../domain/usecases/maintenance_usecases.dart';

class MaintenanceController extends GetxController {
  MaintenanceController(this.useCases);

  static const String screen = 'maintenance';
  static const String detailScreen = 'maintenance:detail';
  static const int pageSize = 20;

  final MaintenanceUseCases useCases;

  final requests = <MaintenanceRequest>[].obs;
  final categories = <MaintenanceCategoryOption>[].obs;
  final summary = Rxn<MaintenanceSummary>();
  final selectedRequest = Rxn<MaintenanceRequest>();

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final isLoadingDetail = false.obs;
  final isSubmitting = false.obs;
  final isCancelling = false.obs;
  final errorMessage = RxnString();
  final detailError = RxnString();
  final isShowingCachedData = false.obs;
  final lastUpdatedAt = Rxn<DateTime>();

  final page = 1.obs;
  final limit = pageSize.obs;
  final total = 0.obs;

  Worker? _sessionWorker;
  int? _loadedForUserId;
  bool _hasUsableData = false;
  Future<void>? _loadInFlight;
  int _requestSeq = 0;
  int _detailSeq = 0;
  Future<void>? _detailInFlight;

  SessionController? get _session => Get.isRegistered<SessionController>()
      ? Get.find<SessionController>()
      : null;

  RefreshRegistry? get _registry =>
      Get.isRegistered<RefreshRegistry>() ? Get.find<RefreshRegistry>() : null;

  ConnectivityService? get _connectivity =>
      Get.isRegistered<ConnectivityService>()
      ? Get.find<ConnectivityService>()
      : null;

  int? get _currentUserId {
    final userId = _session?.currentUser?.id;
    return userId != null && userId > 0 ? userId : null;
  }

  String? get _accountKey => _currentUserId?.toString();

  String get currentUnitId =>
      _session?.currentUser?.unit?.id.toString() ?? '';

  bool get hasMore => page.value * limit.value < total.value;

  int get submittedCount =>
      summary.value?.submittedCount ??
      requests
          .where((item) => item.status == MaintenanceStatus.submitted)
          .length;

  int get assignedCount =>
      summary.value?.assignedCount ??
      requests
          .where((item) => item.status == MaintenanceStatus.assigned)
          .length;

  int get inProgressCount =>
      summary.value?.inProgressCount ??
      requests
          .where((item) => item.status == MaintenanceStatus.inProgress)
          .length;

  int get completedCount =>
      summary.value?.completedCount ??
      requests
          .where((item) => item.status == MaintenanceStatus.completed)
          .length;

  int get totalCount => summary.value?.totalRequests ?? total.value;

  List<MaintenanceCategoryOption> get categoryOptions {
    if (categories.isNotEmpty) return categories;
    return MaintenanceCategory.values
        .map(
          (category) => MaintenanceCategoryOption(
            code: category.defaultCode,
            label: category.label,
          ),
        )
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    _registry?.register(screen, loadRequests);
    _registry?.register(detailScreen, loadSelectedRequestDetail);
    final session = _session;
    if (session == null) {
      loadRequests();
      return;
    }
    _sessionWorker = ever(session.session, (resident) {
      final userId = resident?.user.id;
      if (userId == null) {
        _loadedForUserId = null;
        _resetForAccount();
        return;
      }
      if (_loadedForUserId == userId) return;
      final switchingAccount =
          _loadedForUserId != null && _loadedForUserId != userId;
      _loadedForUserId = userId;
      if (switchingAccount) _resetForAccount();
      loadRequests();
    });
    final userId = session.currentUser?.id;
    if (userId != null) {
      _loadedForUserId = userId;
      loadRequests();
    }
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    _registry?.unregister(screen);
    _registry?.unregister(detailScreen);
    super.onClose();
  }

  Future<void> loadRequests() => _loadAll(forceRefresh: false);

  Future<void> refreshRequests() => _loadAll(forceRefresh: true);

  Future<void> _loadAll({required bool forceRefresh}) {
    final existing = _loadInFlight;
    if (existing != null) return existing;
    final future = _loadAllInternal(forceRefresh: forceRefresh);
    _loadInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) _loadInFlight = null;
    });
  }

  Future<void> _loadAllInternal({required bool forceRefresh}) async {
    final accountKey = _accountKey;
    if (accountKey == null) return;

    isLoading.value = true;
    errorMessage.value = null;

    if (!_hasUsableData && !forceRefresh) {
      await _hydrateFromCache(accountKey);
    }

    if (_connectivity?.isOnline.value == false && _hasUsableData) {
      isShowingCachedData.value = true;
      _registry?.markStale(screen);
      isLoading.value = false;
      return;
    }

    final seq = ++_requestSeq;
    try {
      final result = await useCases.getRequests(
        accountKey: accountKey,
        page: 1,
        limit: limit.value,
        forceRefresh: true,
      );
      if (seq != _requestSeq || accountKey != _accountKey) return;
      requests.assignAll(result.items);
      page.value = result.page;
      limit.value = result.limit;
      total.value = result.total;
      _hasUsableData = true;
      isShowingCachedData.value = false;
      lastUpdatedAt.value = DateTime.now();
      _registry?.markFresh(screen);
      _refreshSelection();
    } on AppException catch (error) {
      _handleLoadFailure(error);
    } catch (_) {
      _handleLoadFailure(null);
    } finally {
      if (seq == _requestSeq) isLoading.value = false;
    }

    if (accountKey != _accountKey) return;
    await _loadCategories(accountKey, forceRefresh: true);
    await _loadSummary(accountKey, forceRefresh: true);
  }

  Future<void> _loadCategories(
    String accountKey, {
    required bool forceRefresh,
  }) async {
    try {
      final loaded = await useCases.getCategories(forceRefresh: forceRefresh);
      if (accountKey != _accountKey) return;
      if (loaded.isNotEmpty) categories.assignAll(loaded);
    } catch (_) {
      if (categories.isEmpty) {
        final cached = await useCases.getCachedCategories();
        if (cached != null) categories.assignAll(cached);
      }
    }
  }

  Future<void> _loadSummary(
    String accountKey, {
    required bool forceRefresh,
  }) async {
    try {
      final loaded = await useCases.getSummary(
        accountKey,
        forceRefresh: forceRefresh,
      );
      if (accountKey != _accountKey) return;
      summary.value = loaded;
    } catch (_) {
      if (summary.value == null) {
        summary.value = await useCases.getCachedSummary(accountKey);
      }
    }
  }

  Future<void> loadMore() async {
    final accountKey = _accountKey;
    if (accountKey == null ||
        isLoading.value ||
        isLoadingMore.value ||
        !hasMore) {
      return;
    }
    if (_connectivity?.isOnline.value == false) {
      isShowingCachedData.value = true;
      _registry?.markStale(screen);
      return;
    }

    isLoadingMore.value = true;
    final seq = _requestSeq;
    try {
      final result = await useCases.getRequests(
        accountKey: accountKey,
        page: page.value + 1,
        limit: limit.value,
        forceRefresh: true,
      );
      if (seq != _requestSeq || accountKey != _accountKey) return;
      final knownIds = requests.map((item) => item.id).toSet();
      requests.addAll(
        result.items.where((item) => !knownIds.contains(item.id)),
      );
      page.value = result.page;
      limit.value = result.limit;
      total.value = result.total;
      _hasUsableData = true;
      isShowingCachedData.value = false;
      _registry?.markFresh(screen);
    } on AppException catch (error) {
      final fallback = error.message;
      if (_hasUsableData) {
        isShowingCachedData.value = true;
      } else {
        errorMessage.value = fallback;
      }
    } catch (_) {
      errorMessage.value = 'Unable to load more requests.';
    } finally {
      isLoadingMore.value = false;
    }
  }

  void selectRequest(MaintenanceRequest request) {
    selectedRequest.value = request;
    detailError.value = null;
  }

  Future<void> loadSelectedRequestDetail({bool forceRefresh = false}) async {
    final request = selectedRequest.value;
    final accountKey = _accountKey;
    if (request == null || accountKey == null) return;
    final existing = _detailInFlight;
    if (existing != null && !forceRefresh) return existing;

    final future = _loadDetail(request, accountKey, forceRefresh);
    _detailInFlight = future;
    return future.whenComplete(() {
      if (identical(_detailInFlight, future)) _detailInFlight = null;
    });
  }

  Future<void> _loadDetail(
    MaintenanceRequest request,
    String accountKey,
    bool forceRefresh,
  ) async {
    isLoadingDetail.value = true;
    detailError.value = null;
    final seq = ++_detailSeq;
    try {
      final loaded = await useCases.getRequest(
        accountKey,
        request.id,
        forceRefresh: forceRefresh,
      );
      if (seq != _detailSeq || accountKey != _accountKey) return;
      selectedRequest.value = loaded;
      _replace(loaded);
    } on AppException catch (error) {
      detailError.value = error.message;
    } catch (_) {
      detailError.value = 'Unable to load request details.';
    } finally {
      if (seq == _detailSeq) isLoadingDetail.value = false;
    }
  }

  Future<MaintenanceRequest?> createRequest({
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
    final accountKey = _accountKey;
    if (accountKey == null) {
      errorMessage.value = 'Sign in again to submit a request.';
      return null;
    }

    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final created = await useCases.createRequest(
        accountKey: accountKey,
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
      requests.insert(0, created);
      total.value = total.value + 1;
      final currentSummary = summary.value;
      if (currentSummary != null) {
        summary.value = MaintenanceSummary(
          totalRequests: currentSummary.totalRequests + 1,
          submittedCount: currentSummary.submittedCount + 1,
          assignedCount: currentSummary.assignedCount,
          inProgressCount: currentSummary.inProgressCount,
          completedCount: currentSummary.completedCount,
        );
      }
      lastUpdatedAt.value = DateTime.now();
      _hasUsableData = true;
      return created;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to submit the request.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> cancelRequest(MaintenanceRequest request, String reason) async {
    final accountKey = _accountKey;
    if (accountKey == null) {
      errorMessage.value = 'Sign in again to cancel this request.';
      return false;
    }

    isCancelling.value = true;
    errorMessage.value = null;
    try {
      final cancellation = await useCases.cancelRequest(
        accountKey: accountKey,
        id: request.id,
        reason: reason,
      );
      final cancelledAt =
          cancellation.cancelledAt ?? DateTime.now().toUtc().toIso8601String();
      final updated = request.copyWith(
        status: MaintenanceStatus.cancelled,
        cancelledAt: cancelledAt,
        progressHistory: <MaintenanceProgressEntry>[
          ...request.progressHistory,
          MaintenanceProgressEntry(
            status: MaintenanceStatus.cancelled,
            note: reason,
            createdAt: cancelledAt,
          ),
        ],
      );
      _replace(updated);
      if (selectedRequest.value?.id == request.id) {
        selectedRequest.value = updated;
      }
      final currentSummary = summary.value;
      if (currentSummary != null) {
        final wasSubmitted = request.status == MaintenanceStatus.submitted;
        final wasAssigned = request.status == MaintenanceStatus.assigned;
        summary.value = MaintenanceSummary(
          totalRequests: currentSummary.totalRequests,
          submittedCount: wasSubmitted && currentSummary.submittedCount > 0
              ? currentSummary.submittedCount - 1
              : currentSummary.submittedCount,
          assignedCount: wasAssigned && currentSummary.assignedCount > 0
              ? currentSummary.assignedCount - 1
              : currentSummary.assignedCount,
          inProgressCount: currentSummary.inProgressCount,
          completedCount: currentSummary.completedCount,
        );
      }
      lastUpdatedAt.value = DateTime.now();
      return true;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Unable to cancel the request.';
      return false;
    } finally {
      isCancelling.value = false;
    }
  }

  Future<void> _hydrateFromCache(String accountKey) async {
    try {
      final cachedCategories = await useCases.getCachedCategories();
      final cachedRequests = await useCases.getCachedRequests(accountKey);
      final cachedSummary = await useCases.getCachedSummary(accountKey);

      if (cachedCategories != null && cachedCategories.isNotEmpty) {
        categories.assignAll(cachedCategories);
      }
      if (cachedRequests != null) {
        requests.assignAll(cachedRequests.items);
        page.value = cachedRequests.page;
        limit.value = cachedRequests.limit;
        total.value = cachedRequests.total;
        _hasUsableData = true;
      }
      if (cachedSummary != null) {
        summary.value = cachedSummary;
      }
      if (_hasUsableData) {
        isShowingCachedData.value = true;
        _refreshSelection();
      }
    } catch (_) {}
  }

  void _handleLoadFailure(AppException? error) {
    if (_hasUsableData) {
      isShowingCachedData.value = true;
    } else {
      errorMessage.value =
          error?.message ?? 'Unable to load maintenance requests.';
    }
    if (error is ApiException && error.isRetryable) {
      _registry?.markStale(screen);
    }
  }

  void _replace(MaintenanceRequest updated) {
    final index = requests.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      requests[index] = updated;
    } else if (_hasUsableData) {
      requests.insert(0, updated);
    }
  }

  void _refreshSelection() {
    final request = selectedRequest.value;
    if (request == null) return;
    final index = requests.indexWhere((item) => item.id == request.id);
    if (index != -1) selectedRequest.value = requests[index];
  }

  void _resetForAccount() {
    requests.clear();
    categories.clear();
    summary.value = null;
    selectedRequest.value = null;
    page.value = 1;
    limit.value = pageSize;
    total.value = 0;
    _hasUsableData = false;
    isShowingCachedData.value = false;
    errorMessage.value = null;
    detailError.value = null;
    lastUpdatedAt.value = null;
    _requestSeq++;
    _detailSeq++;
    _loadInFlight = null;
    _detailInFlight = null;
  }
}
