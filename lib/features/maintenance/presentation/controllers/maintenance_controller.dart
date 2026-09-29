import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/maintenance_request.dart';
import '../../domain/usecases/maintenance_usecases.dart';

class MaintenanceController extends GetxController {
  MaintenanceController(this.useCases);

  final MaintenanceUseCases useCases;
  final requests = <MaintenanceRequest>[].obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadRequests();
  }

  int get inProgressCount => requests
      .where((request) => request.status == MaintenanceStatus.inProgress)
      .length;

  int get completedCount => requests
      .where((request) => request.status == MaintenanceStatus.completed)
      .length;

  Future<void> loadRequests() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      requests.assignAll(await useCases.getRequests());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load maintenance requests.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<MaintenanceRequest?> createRequest({
    required String title,
    required MaintenanceCategory category,
    required String description,
    required String location,
    required MaintenancePriority priority,
    required String preferredDate,
    required String preferredTime,
    required List<String> photoNames,
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final request = await useCases.createRequest(
        MaintenanceRequest(
          id: 'local-request',
          title: title,
          category: category,
          description: description,
          location: location,
          priority: priority,
          status: MaintenanceStatus.submitted,
          createdAt: 'Sep 25, 2026',
          preferredDate: preferredDate,
          preferredTime: preferredTime,
          photoNames: List<String>.unmodifiable(photoNames),
        ),
      );
      requests.insert(0, request);
      return request;
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

  Future<MaintenanceRequest?> advanceRequest(MaintenanceRequest request) async {
    final nextStatus = request.status.next;
    if (nextStatus == null) {
      return request;
    }
    errorMessage.value = null;
    try {
      final updated = await useCases.updateStatus(request.id, nextStatus);
      final index = requests.indexWhere((item) => item.id == request.id);
      if (index != -1) {
        requests[index] = updated;
      }
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to update the request.';
      return null;
    }
  }
}
