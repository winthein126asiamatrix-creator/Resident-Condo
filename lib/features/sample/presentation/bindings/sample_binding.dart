import 'package:get/get.dart';

import '../../data/datasources/sample_local_data_source.dart';
import '../../data/repositories/sample_repository_impl.dart';
import '../../domain/repositories/sample_repository.dart';
import '../../domain/usecases/sample_usecases.dart';
import '../controllers/sample_controller.dart';

class SampleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SampleRepository>(
      () => SampleRepositoryImpl(SampleLocalDataSource()),
    );
    Get.lazyPut<SampleUseCases>(() => SampleUseCases(Get.find()));
    Get.lazyPut<SampleController>(() => SampleController(Get.find()));
  }
}
