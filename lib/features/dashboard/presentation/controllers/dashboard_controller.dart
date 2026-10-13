import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/refresh_registry.dart';
import '../../domain/entities/dashboard.dart';
import '../../domain/usecases/dashboard_usecases.dart';

class DashboardController extends GetxController {
  DashboardController(this.useCases);

  /// The registry key this controller re-fetches under.
  static const String screen = 'dashboard';

  final DashboardUseCases useCases;
  final dashboard = Rxn<DashboardData>();
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final selectedTab = 0.obs;

  /// The connectivity layer's registry, when it is registered.
  ///
  /// Nullable so the controller still works in a test that pumps the dashboard
  /// without the full app graph.
  RefreshRegistry? get _registry =>
      Get.isRegistered<RefreshRegistry>() ? Get.find<RefreshRegistry>() : null;

  @override
  void onInit() {
    super.onInit();
    _registry?.register(screen, loadDashboard);
    loadDashboard();
  }

  @override
  void onClose() {
    _registry?.unregister(screen);
    super.onClose();
  }

  Future<void> loadDashboard() async {
    // A refresh triggered by connectivity returning must not stack on a fetch
    // that is already running.
    if (isLoading.value) {
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      dashboard.value = await useCases.getDashboard();
      _registry?.markFresh(screen);
    } on AppException catch (error) {
      // Only a network-level failure means the data on screen is stale. The
      // data itself is kept: replacing it with an error would throw away the
      // last good reading, and the reconnect refresh replaces it anyway.
      if (error is ApiException && error.isRetryable) {
        _registry?.markStale(screen);
      }
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load your dashboard.';
    } finally {
      isLoading.value = false;
    }
  }

  void selectTab(int index) {
    selectedTab.value = index;
  }
}
