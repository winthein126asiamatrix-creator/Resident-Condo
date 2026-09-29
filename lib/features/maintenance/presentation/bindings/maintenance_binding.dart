import 'package:get/get.dart';

import '../../data/datasources/maintenance_local_data_source.dart';
import '../../data/repositories/maintenance_repository_impl.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/usecases/maintenance_usecases.dart';
import '../controllers/maintenance_controller.dart';

class MaintenanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<MaintenanceRepository>(
      MaintenanceRepositoryImpl(MaintenanceLocalDataSource()),
      permanent: true,
    );
    Get.put<MaintenanceUseCases>(
      MaintenanceUseCases(Get.find<MaintenanceRepository>()),
      permanent: true,
    );
    Get.put<MaintenanceController>(
      MaintenanceController(Get.find<MaintenanceUseCases>()),
      permanent: true,
    );
  }
}
