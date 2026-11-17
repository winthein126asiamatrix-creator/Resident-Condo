import 'package:get/get.dart';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../data/datasources/maintenance_local_data_source.dart';
import '../../data/datasources/maintenance_remote_data_source.dart';
import '../../data/repositories/maintenance_repository_impl.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/usecases/maintenance_usecases.dart';
import '../controllers/maintenance_controller.dart';

class MaintenanceBinding extends Bindings {
  @override
  void dependencies() {
    if (Get.isRegistered<MaintenanceController>()) return;

    if (!Get.isRegistered<MaintenanceLocalDataSource>()) {
      Get.put<MaintenanceLocalDataSource>(
        MaintenanceLocalDataSource(Get.find<ApiCacheStore>()),
        permanent: true,
      );
    }

    if (!Get.isRegistered<MaintenanceRemoteDataSource>()) {
      Get.put<MaintenanceRemoteDataSource>(
        MaintenanceRemoteDataSource(Get.find<DioApiService>()),
        permanent: true,
      );
    }

    if (!Get.isRegistered<MaintenanceRepository>()) {
      Get.put<MaintenanceRepository>(
        MaintenanceRepositoryImpl(
          Get.find<MaintenanceRemoteDataSource>(),
          Get.find<MaintenanceLocalDataSource>(),
        ),
        permanent: true,
      );
    }

    if (!Get.isRegistered<MaintenanceUseCases>()) {
      Get.put<MaintenanceUseCases>(
        MaintenanceUseCases(Get.find<MaintenanceRepository>()),
        permanent: true,
      );
    }

    Get.put<MaintenanceController>(
      MaintenanceController(Get.find<MaintenanceUseCases>()),
      permanent: true,
    );
  }
}
