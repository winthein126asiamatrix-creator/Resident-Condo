import 'package:get/get.dart';

import '../../data/datasources/store_local_data_source.dart';
import '../../data/repositories/store_repository_impl.dart';
import '../../domain/repositories/store_repository.dart';
import '../../domain/usecases/store_usecases.dart';
import '../controllers/store_controller.dart';

class StoreBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StoreRepository>(
      StoreRepositoryImpl(StoreLocalDataSource()),
      permanent: true,
    );
    Get.put<StoreUseCases>(StoreUseCases(Get.find<StoreRepository>()), permanent: true);
    Get.put<StoreController>(
      StoreController(Get.find<StoreUseCases>()),
      permanent: true,
    );
  }
}
