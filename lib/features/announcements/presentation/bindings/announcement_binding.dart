import 'package:get/get.dart';

import '../../data/datasources/announcement_local_data_source.dart';
import '../../data/repositories/announcement_repository_impl.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../../domain/usecases/announcement_usecases.dart';
import '../controllers/announcement_controller.dart';

class AnnouncementBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AnnouncementRepository>(
      AnnouncementRepositoryImpl(AnnouncementLocalDataSource()),
      permanent: true,
    );
    Get.put<AnnouncementUseCases>(
      AnnouncementUseCases(Get.find<AnnouncementRepository>()),
      permanent: true,
    );
    Get.put<AnnouncementController>(
      AnnouncementController(Get.find<AnnouncementUseCases>()),
      permanent: true,
    );
  }
}
