import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/network/refresh_registry.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../domain/entities/condo_service.dart';
import '../../domain/usecases/condo_service_usecases.dart';

enum ServicesTab { catalogue, requests }

extension ServicesTabIndex on ServicesTab {
  /// Position in the tab strip, used to drive the highlighted segment.
  int get index => ServicesTab.values.indexOf(this);
}

class CondoServiceController extends GetxController {
  CondoServiceController(this.useCases);

  static const _activeStatus = 'active';
  static const _historyStatus = 'history';

  /// The registry key this controller re-fetches under.
  static const String screen = 'services';

  final CondoServiceUseCases useCases;
  final services = <CondoService>[].obs;
  final activeRequests = <ServiceRequest>[].obs;
  final historyRequests = <ServiceRequest>[].obs;
  final selectedService = Rxn<CondoService>();
  final selectedRequest = Rxn<ServiceRequest>();
  final tab = ServicesTab.catalogue.obs;
  final isLoading = false.obs;
  final isLoadingDetail = false.obs;
  final isLoadingMoreHistory = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// True while what is on screen came from the device rather than the API.
  final isShowingCachedData = false.obs;

  final historyPage = 1.obs;
  final historyLimit = 20.obs;
  final historyTotal = 0.obs;

  Worker? _sessionWorker;
  int? _loadedForUserId;

  /// Whether a cache snapshot or a server response exists for this account,
  /// even when that snapshot happens to be empty.
  bool _hasUsableData = false;

  Future<void>? _loadAllInFlight;

  List<ServiceRequest> get requests => <ServiceRequest>[
    ...activeRequests,
    ...historyRequests,
  ];

  bool get hasMoreHistory =>
      historyPage.value * historyLimit.value < historyTotal.value;

  SessionController? get _session => Get.isRegistered<SessionController>()
      ? Get.find<SessionController>()
      : null;

  /// The connectivity layer's registry, when it is registered.
  ///
  /// Nullable so the controller still works in a test that pumps services
  /// without the full app graph.
  RefreshRegistry? get _registry =>
      Get.isRegistered<RefreshRegistry>() ? Get.find<RefreshRegistry>() : null;

  ConnectivityService? get _connectivity =>
      Get.isRegistered<ConnectivityService>()
      ? Get.find<ConnectivityService>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _registry?.register(screen, loadAll);
    final session = _session;
    if (session == null) {
      // No session graph (e.g. a unit test): keep the previous eager behaviour.
      loadAll();
      return;
    }
    // Wait for `/me` to publish the authenticated user before calling the
    // services API. Loading from this controller's onInit would run at app
    // start, before the session is restored, and the request would be rejected
    // with a 401.
    _sessionWorker = ever(session.session, (resident) {
      final userId = resident?.user.id;
      if (userId == null) {
        _loadedForUserId = null;
        _resetForAccount();
        return;
      }
      if (_loadedForUserId == userId) {
        return;
      }
      final switchingAccount =
          _loadedForUserId != null && _loadedForUserId != userId;
      _loadedForUserId = userId;
      if (switchingAccount) {
        _resetForAccount();
      }
      loadAll();
    });
    final userId = session.currentUser?.id;
    if (userId != null) {
      _loadedForUserId = userId;
      loadAll();
    }
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    _registry?.unregister(screen);
    super.onClose();
  }

  int get openRequestCount => activeRequests.length;

  List<ServiceRequest> get pastRequests => historyRequests;

  double get pendingServiceFees => requests
      .where((request) => request.status != ServiceRequestStatus.cancelled)
      .fold(0, (total, request) => total + request.price);

  void selectTab(ServicesTab value) {
    tab.value = value;
  }

  void selectService(CondoService service) {
    selectedService.value = service;
    errorMessage.value = null;
  }

  Future<void> loadServiceDetail(int id) async {
    isLoadingDetail.value = true;
    errorMessage.value = null;
    try {
      selectedService.value = await useCases.getService(id);
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load service details.';
    } finally {
      isLoadingDetail.value = false;
    }
  }

  void selectRequest(ServiceRequest request) {
    selectedRequest.value = request;
  }

  /// Loads both lists, cache first, then the API.
  ///
  /// Concurrent callers share the request already in flight so a reconnect and
  /// a pull-to-refresh cannot issue the same three GETs twice.
  Future<void> loadAll() {
    final existing = _loadAllInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadAll();
    _loadAllInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadAllInFlight, future)) {
        _loadAllInFlight = null;
      }
    });
  }

  Future<void> _loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;

    if (!_hasUsableData) {
      await _hydrateFromCache();
    }

    // The radio can already say the device is offline. With a cached snapshot
    // there is nothing useful to ask the API, so keep what is on screen and
    // let the reconnect worker refresh it later.
    if (_connectivity?.isOnline.value == false && _hasUsableData) {
      isShowingCachedData.value = true;
      _registry?.markStale(screen);
      isLoading.value = false;
      return;
    }

    try {
      final results = await Future.wait<Object>([
        useCases.getServices(),
        useCases.getRequests(status: _activeStatus),
        useCases.getRequests(status: _historyStatus),
      ]);
      final loadedServices = results[0] as List<CondoService>;
      final active = results[1] as ServiceRequestPageResult;
      final history = results[2] as ServiceRequestPageResult;

      services.assignAll(loadedServices);
      activeRequests.assignAll(_sortedActive(active.items));
      historyRequests.assignAll(_sortedHistory(history.items));
      historyPage.value = history.page;
      historyLimit.value = history.limit;
      historyTotal.value = history.total;
      _hasUsableData = true;
      isShowingCachedData.value = false;
      _registry?.markFresh(screen);
      _refreshSelection();
    } on AppException catch (error) {
      _handleLoadFailure(error);
    } catch (_) {
      _handleLoadFailure(null, fallback: 'Unable to load condo services.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreHistory() async {
    if (isLoading.value || isLoadingMoreHistory.value || !hasMoreHistory) {
      return;
    }

    if (_connectivity?.isOnline.value == false && _hasUsableData) {
      isShowingCachedData.value = true;
      _registry?.markStale(screen);
      return;
    }

    isLoadingMoreHistory.value = true;
    errorMessage.value = null;
    try {
      final nextPage = historyPage.value + 1;
      final history = await useCases.getRequests(
        status: _historyStatus,
        page: nextPage,
      );
      final knownIds = historyRequests.map((request) => request.id).toSet();
      historyRequests.addAll(
        history.items.where((request) => !knownIds.contains(request.id)),
      );
      historyRequests.assignAll(_sortedHistory(historyRequests));
      historyPage.value = history.page;
      historyLimit.value = history.limit;
      historyTotal.value = history.total;
      _hasUsableData = true;
      isShowingCachedData.value = false;
      _registry?.markFresh(screen);
    } on AppException catch (error) {
      _handleLoadFailure(
        error,
        fallback: 'Unable to load older service requests.',
      );
    } catch (_) {
      _handleLoadFailure(
        null,
        fallback: 'Unable to load older service requests.',
      );
    } finally {
      isLoadingMoreHistory.value = false;
    }
  }

  Future<ServiceRequest?> bookService({
    required CondoService service,
    required String date,
    required String slot,
    int? slotId,
    Map<String, dynamic> bookingDetails = const <String, dynamic>{},
    String notes = '',
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final request = await useCases.createRequest(
        ServiceRequest(
          id: 'local-service-request',
          serviceId: service.id,
          serviceName: service.name,
          category: service.category,
          scheduledDate: date,
          scheduledSlot: slot,
          status: ServiceRequestStatus.requested,
          price: service.price,
          requestedOn: 'Sep 25, 2026',
          provider: service.provider,
          notes: notes,
          slotId: slotId,
          bookingDetails: bookingDetails,
        ),
      );
      _replaceRequest(request);
      selectedRequest.value = request;
      return request;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to book this service.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<ServiceRequest?> advanceRequest(ServiceRequest request) async {
    final next = request.status.next;
    if (next == null) {
      return request;
    }
    return _run(request, () => useCases.updateStatus(request, next));
  }

  Future<ServiceRequest?> cancelRequest(ServiceRequest request) {
    return _run(request, () => useCases.cancelRequest(request));
  }

  Future<ServiceRequest?> rateRequest(
    ServiceRequest request,
    int rating,
    String feedback,
  ) {
    return _run(request, () => useCases.rateRequest(request, rating, feedback));
  }

  Future<ServiceRequest?> _run(
    ServiceRequest request,
    Future<ServiceRequest> Function() action,
  ) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await action();
      _replaceRequest(updated);
      selectedRequest.value = updated;
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to update the service request.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Puts the device's copy on screen before the API answers.
  Future<void> _hydrateFromCache() async {
    try {
      final cachedServices = await useCases.getCachedServices();
      final active = await useCases.getCachedRequests(status: _activeStatus);
      final history = await useCases.getCachedRequests(status: _historyStatus);

      if (cachedServices != null) {
        services.assignAll(cachedServices);
        _hasUsableData = true;
      }
      if (active != null) {
        activeRequests.assignAll(_sortedActive(active.items));
        _hasUsableData = true;
      }
      if (history != null) {
        historyRequests.assignAll(_sortedHistory(history.items));
        historyPage.value = history.page;
        historyLimit.value = history.limit;
        historyTotal.value = history.total;
        _hasUsableData = true;
      }
      _refreshSelection();
    } catch (_) {
      // The cache is only a head start; a broken row must not stop the request.
    }
  }

  void _handleLoadFailure(Object? error, {String? fallback}) {
    if (_hasUsableData) {
      // Older data is better than an error screen, and the notice on the page
      // says where it came from.
      isShowingCachedData.value = true;
    } else {
      errorMessage.value = error is AppException
          ? error.message
          : (fallback ?? 'Unable to load condo services.');
    }
    if (error is ApiException && error.isRetryable) {
      _registry?.markStale(screen);
    }
  }

  /// Clears everything that belonged to the previous resident.
  void _resetForAccount() {
    services.clear();
    activeRequests.clear();
    historyRequests.clear();
    selectedService.value = null;
    selectedRequest.value = null;
    historyPage.value = 1;
    historyLimit.value = 20;
    historyTotal.value = 0;
    _hasUsableData = false;
    isShowingCachedData.value = false;
    errorMessage.value = null;
  }

  void _refreshSelection() {
    final service = selectedService.value;
    if (service != null) {
      selectedService.value = _findService(service.id) ?? service;
    }
    final request = selectedRequest.value;
    if (request != null) {
      selectedRequest.value = _findRequest(request.id) ?? request;
    }
  }

  void _replaceRequest(ServiceRequest updated) {
    final wasHistory = historyRequests.any((item) => item.id == updated.id);
    activeRequests.removeWhere((item) => item.id == updated.id);
    historyRequests.removeWhere((item) => item.id == updated.id);

    if (updated.status.isHistory) {
      historyRequests.add(updated);
      historyRequests.assignAll(_sortedHistory(historyRequests));
      if (!wasHistory) {
        historyTotal.value = historyTotal.value + 1;
      }
      return;
    }

    activeRequests.add(updated);
    activeRequests.assignAll(_sortedActive(activeRequests));
    if (wasHistory && historyTotal.value > 0) {
      historyTotal.value = historyTotal.value - 1;
    }
  }

  List<ServiceRequest> _sortedActive(Iterable<ServiceRequest> items) =>
      items.where((request) => request.status.isActive).toList()
        ..sort((a, b) => _startOf(a).compareTo(_startOf(b)));

  List<ServiceRequest> _sortedHistory(Iterable<ServiceRequest> items) =>
      items.where((request) => request.status.isHistory).toList()
        ..sort((a, b) => _startOf(b).compareTo(_startOf(a)));

  DateTime _startOf(ServiceRequest request) {
    final date = AppDates.parse(request.scheduledDate);
    final start = request.scheduledSlot
        .split(RegExp(r'\s*[-–]\s*'))
        .first
        .trim();
    final parts = start.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts.first) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  CondoService? _findService(int id) {
    for (final service in services) {
      if (service.id == id) {
        return service;
      }
    }
    return null;
  }

  ServiceRequest? _findRequest(String id) {
    for (final request in requests) {
      if (request.id == id) {
        return request;
      }
    }
    return null;
  }
}
