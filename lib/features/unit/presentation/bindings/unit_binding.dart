import 'package:get/get.dart';

import '../../../../core/cache/api_cache_store.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../data/datasources/unit_local_data_source.dart';
import '../../data/datasources/unit_remote_data_source.dart';
import '../../data/repositories/unit_repository_impl.dart';
import '../../domain/repositories/unit_repository.dart';
import '../../domain/usecases/unit_usecases.dart';
import '../controllers/unit_controller.dart';

class UnitBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<UnitRemoteDataSource>()) {
      Get.put<UnitRemoteDataSource>(
        UnitRemoteDataSource(Get.find()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<UnitRepository>()) {
      Get.put<UnitRepository>(
        UnitRepositoryImpl(Get.find<UnitRemoteDataSource>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<UnitUseCases>()) {
      Get.put<UnitUseCases>(
        UnitUseCases(Get.find<UnitRepository>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<UnitLocalDataSource>()) {
      Get.put<UnitLocalDataSource>(
        UnitLocalDataSource(
          cache: Get.isRegistered<ApiCacheStore>()
              ? Get.find<ApiCacheStore>()
              : null,
          accountKey: () => Get.isRegistered<SessionController>()
              ? Get.find<SessionController>().currentUser?.id.toString()
              : null,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<UnitController>()) {
      Get.put<UnitController>(
        UnitController(
          Get.find<UnitUseCases>(),
          cache: Get.find<UnitLocalDataSource>(),
          sessionController: Get.isRegistered<SessionController>()
              ? Get.find<SessionController>()
              : null,
        ),
        permanent: true,
      );
    }
  }
}
