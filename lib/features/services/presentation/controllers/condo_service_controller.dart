import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/condo_service.dart';
import '../../domain/usecases/condo_service_usecases.dart';

enum ServicesTab { catalogue, requests }

extension ServicesTabIndex on ServicesTab {
  /// Position in the tab strip, used to drive the highlighted segment.
  int get index => ServicesTab.values.indexOf(this);
}

class CondoServiceController extends GetxController {
  CondoServiceController(this.useCases);

  final CondoServiceUseCases useCases;
  final services = <CondoService>[].obs;
  final requests = <ServiceRequest>[].obs;
  final selectedService = Rxn<CondoService>();
  final selectedRequest = Rxn<ServiceRequest>();
  final tab = ServicesTab.catalogue.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  int get openRequestCount => requests
      .where(
        (request) =>
            request.status != ServiceRequestStatus.completed &&
            request.status != ServiceRequestStatus.cancelled,
      )
      .length;

  List<ServiceRequest> get activeRequests => requests
      .where(
        (request) =>
            request.status != ServiceRequestStatus.completed &&
            request.status != ServiceRequestStatus.cancelled,
      )
      .toList();

  List<ServiceRequest> get pastRequests => requests
      .where(
        (request) =>
            request.status == ServiceRequestStatus.completed ||
            request.status == ServiceRequestStatus.cancelled,
      )
      .toList();

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

  void selectRequest(ServiceRequest request) {
    selectedRequest.value = request;
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loadedServices = await useCases.getServices();
      final loadedRequests = await useCases.getRequests();
      services.assignAll(loadedServices);
      requests.assignAll(loadedRequests);
      final service = selectedService.value;
      if (service != null) {
        selectedService.value = _findService(service.id) ?? service;
      }
      final request = selectedRequest.value;
      if (request != null) {
        selectedRequest.value = _findRequest(request.id) ?? request;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load condo services.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<ServiceRequest?> bookService({
    required CondoService service,
    required String date,
    required String slot,
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
        ),
      );
      requests.insert(0, request);
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
      final index = requests.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        requests[index] = updated;
      }
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

  CondoService? _findService(String id) {
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
