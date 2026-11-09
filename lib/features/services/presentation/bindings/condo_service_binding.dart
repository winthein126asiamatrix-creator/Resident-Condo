import 'package:get/get.dart';

import '../../data/datasources/condo_service_local_data_source.dart';
import '../../data/datasources/condo_service_remote_data_source.dart';
import '../../data/repositories/condo_service_repository_impl.dart';
import '../../domain/repositories/condo_service_repository.dart';
import '../../domain/usecases/condo_service_usecases.dart';
import '../controllers/condo_service_controller.dart';

class CondoServiceBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CondoServiceRemoteDataSource>()) {
      Get.put<CondoServiceRemoteDataSource>(
        CondoServiceRemoteDataSource(Get.find()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CondoServiceRepository>()) {
      Get.put<CondoServiceRepository>(
        CondoServiceRepositoryImpl(
          remoteDataSource: Get.find<CondoServiceRemoteDataSource>(),
          localDataSource: CondoServiceLocalDataSource(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CondoServiceUseCases>()) {
      Get.put<CondoServiceUseCases>(
        CondoServiceUseCases(Get.find<CondoServiceRepository>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CondoServiceController>()) {
      Get.put<CondoServiceController>(
        CondoServiceController(Get.find<CondoServiceUseCases>()),
        permanent: true,
      );
    }
  }
}
