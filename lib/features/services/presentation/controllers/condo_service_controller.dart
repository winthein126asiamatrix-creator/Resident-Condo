import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
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
  final historyPage = 1.obs;
  final historyLimit = 20.obs;
  final historyTotal = 0.obs;

  Worker? _sessionWorker;
  int? _loadedForUserId;

  List<ServiceRequest> get requests => <ServiceRequest>[
    ...activeRequests,
    ...historyRequests,
  ];

  bool get hasMoreHistory =>
      historyPage.value * historyLimit.value < historyTotal.value;

  SessionController? get _session => Get.isRegistered<SessionController>()
      ? Get.find<SessionController>()
      : null;

  @override
  void onInit() {
    super.onInit();
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
        return;
      }
      if (_loadedForUserId == userId) {
        return;
      }
      _loadedForUserId = userId;
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

  Future<void> loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;
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
      _refreshSelection();
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load condo services.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreHistory() async {
    if (isLoadingMoreHistory.value || !hasMoreHistory) {
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
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load older service requests.';
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
