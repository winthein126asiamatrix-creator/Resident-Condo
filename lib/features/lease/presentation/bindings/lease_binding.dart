import 'package:get/get.dart';

import '../../data/datasources/lease_local_data_source.dart';
import '../../data/repositories/lease_repository_impl.dart';
import '../../domain/repositories/lease_repository.dart';
import '../../domain/usecases/lease_usecases.dart';
import '../controllers/lease_controller.dart';

class LeaseBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LeaseRepository>(
      LeaseRepositoryImpl(LeaseLocalDataSource()),
      permanent: true,
    );
    Get.put<LeaseUseCases>(
      LeaseUseCases(Get.find<LeaseRepository>()),
      permanent: true,
    );
    Get.put<LeaseController>(
      LeaseController(Get.find<LeaseUseCases>()),
      permanent: true,
    );
  }
}
