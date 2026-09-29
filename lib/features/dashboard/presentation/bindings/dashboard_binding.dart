import 'package:get/get.dart';

import '../../data/datasources/dashboard_local_data_source.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/dashboard_usecases.dart';
import '../controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<DashboardRepository>(
      DashboardRepositoryImpl(DashboardLocalDataSource()),
      permanent: true,
    );
    Get.put<DashboardUseCases>(
      DashboardUseCases(Get.find<DashboardRepository>()),
      permanent: true,
    );
    Get.put<DashboardController>(
      DashboardController(Get.find<DashboardUseCases>()),
      permanent: true,
    );
  }
}
