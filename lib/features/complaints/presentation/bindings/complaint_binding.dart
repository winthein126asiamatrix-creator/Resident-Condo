import 'package:get/get.dart';

import '../../data/datasources/complaint_local_data_source.dart';
import '../../data/repositories/complaint_repository_impl.dart';
import '../../domain/repositories/complaint_repository.dart';
import '../../domain/usecases/complaint_usecases.dart';
import '../controllers/complaint_controller.dart';

class ComplaintBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ComplaintRepository>(
      ComplaintRepositoryImpl(ComplaintLocalDataSource()),
      permanent: true,
    );
    Get.put<ComplaintUseCases>(
      ComplaintUseCases(Get.find<ComplaintRepository>()),
      permanent: true,
    );
    Get.put<ComplaintController>(
      ComplaintController(Get.find<ComplaintUseCases>()),
      permanent: true,
    );
  }
}
