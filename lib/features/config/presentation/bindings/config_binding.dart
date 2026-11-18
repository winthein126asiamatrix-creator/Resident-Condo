import 'package:get/get.dart';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../data/datasources/config_local_data_source.dart';
import '../../data/datasources/config_remote_data_source.dart';
import '../../data/repositories/config_repository_impl.dart';
import '../../domain/repositories/config_repository.dart';
import '../../domain/usecases/config_usecases.dart';
import '../controllers/app_config_controller.dart';
import '../controllers/condo_config_controller.dart';

class ConfigBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ConfigRemoteDataSource>()) {
      Get.put<ConfigRemoteDataSource>(
        ConfigRemoteDataSource(Get.find<DioApiService>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ConfigLocalDataSource>()) {
      Get.put<ConfigLocalDataSource>(
        ConfigLocalDataSource(
          cache: Get.isRegistered<ApiCacheStore>()
              ? Get.find<ApiCacheStore>()
              : null,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ConfigRepository>()) {
      Get.put<ConfigRepository>(
        ConfigRepositoryImpl(
          remoteDataSource: Get.find<ConfigRemoteDataSource>(),
          localDataSource: Get.find<ConfigLocalDataSource>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ConfigUseCases>()) {
      Get.put<ConfigUseCases>(
        ConfigUseCases(Get.find<ConfigRepository>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AppConfigController>()) {
      Get.put<AppConfigController>(
        AppConfigController(Get.find<ConfigUseCases>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CondoConfigController>()) {
      Get.put<CondoConfigController>(
        CondoConfigController(Get.find<ConfigUseCases>()),
        permanent: true,
      );
    }
  }
}
