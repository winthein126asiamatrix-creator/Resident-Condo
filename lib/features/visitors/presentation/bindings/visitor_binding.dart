import 'package:get/get.dart';

import '../../data/datasources/visitor_local_data_source.dart';
import '../../data/repositories/visitor_repository_impl.dart';
import '../../domain/repositories/visitor_repository.dart';
import '../../domain/usecases/visitor_usecases.dart';
import '../controllers/visitor_controller.dart';

class VisitorBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<VisitorRepository>(
      VisitorRepositoryImpl(VisitorLocalDataSource()),
      permanent: true,
    );
    Get.put<VisitorUseCases>(
      VisitorUseCases(Get.find<VisitorRepository>()),
      permanent: true,
    );
    Get.put<VisitorController>(
      VisitorController(Get.find<VisitorUseCases>()),
      permanent: true,
    );
  }
}
