import 'package:get/get.dart';

import '../../data/datasources/unit_local_data_source.dart';
import '../../data/repositories/unit_repository_impl.dart';
import '../../domain/repositories/unit_repository.dart';
import '../../domain/usecases/unit_usecases.dart';
import '../controllers/unit_controller.dart';

class UnitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UnitRepository>(
      () => UnitRepositoryImpl(UnitLocalDataSource()),
    );
    Get.lazyPut<UnitUseCases>(() => UnitUseCases(Get.find()));
    Get.lazyPut<UnitController>(() => UnitController(Get.find()));
  }
}
