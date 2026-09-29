import 'package:get/get.dart';

import '../../data/datasources/condo_service_local_data_source.dart';
import '../../data/repositories/condo_service_repository_impl.dart';
import '../../domain/repositories/condo_service_repository.dart';
import '../../domain/usecases/condo_service_usecases.dart';
import '../controllers/condo_service_controller.dart';

class CondoServiceBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CondoServiceRepository>(
      CondoServiceRepositoryImpl(CondoServiceLocalDataSource()),
      permanent: true,
    );
    Get.put<CondoServiceUseCases>(
      CondoServiceUseCases(Get.find<CondoServiceRepository>()),
      permanent: true,
    );
    Get.put<CondoServiceController>(
      CondoServiceController(Get.find<CondoServiceUseCases>()),
      permanent: true,
    );
  }
}
