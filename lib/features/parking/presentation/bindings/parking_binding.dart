import 'package:get/get.dart';

import '../../data/datasources/parking_local_data_source.dart';
import '../../data/repositories/parking_repository_impl.dart';
import '../../domain/repositories/parking_repository.dart';
import '../../domain/usecases/parking_usecases.dart';
import '../controllers/parking_controller.dart';

class ParkingBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ParkingRepository>(
      ParkingRepositoryImpl(ParkingLocalDataSource()),
      permanent: true,
    );
    Get.put<ParkingUseCases>(
      ParkingUseCases(Get.find<ParkingRepository>()),
      permanent: true,
    );
    Get.put<ParkingController>(
      ParkingController(Get.find<ParkingUseCases>()),
      permanent: true,
    );
  }
}
