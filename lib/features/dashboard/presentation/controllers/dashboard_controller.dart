import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/dashboard.dart';
import '../../domain/usecases/dashboard_usecases.dart';

class DashboardController extends GetxController {
  DashboardController(this.useCases);

  final DashboardUseCases useCases;
  final dashboard = Rxn<DashboardData>();
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final selectedTab = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      dashboard.value = await useCases.getDashboard();
    } on AppException catch (error) {
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
