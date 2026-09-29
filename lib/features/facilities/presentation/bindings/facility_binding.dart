import 'package:get/get.dart';

import '../../data/datasources/facility_local_data_source.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/usecases/facility_usecases.dart';
import '../controllers/facility_controller.dart';

class FacilityBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<FacilityRepository>(
      FacilityRepositoryImpl(FacilityLocalDataSource()),
      permanent: true,
    );
    Get.put<FacilityUseCases>(
      FacilityUseCases(Get.find<FacilityRepository>()),
      permanent: true,
    );
    Get.put<FacilityController>(
      FacilityController(Get.find<FacilityUseCases>()),
      permanent: true,
    );
  }
}
