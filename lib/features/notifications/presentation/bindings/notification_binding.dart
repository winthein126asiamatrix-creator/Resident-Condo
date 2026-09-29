import 'package:get/get.dart';

import '../../data/datasources/notification_local_data_source.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/notification_usecases.dart';
import '../controllers/notification_controller.dart';

class NotificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<NotificationRepository>(
      NotificationRepositoryImpl(NotificationLocalDataSource()),
      permanent: true,
    );
    Get.put<NotificationUseCases>(
      NotificationUseCases(Get.find<NotificationRepository>()),
      permanent: true,
    );
    Get.put<NotificationController>(
      NotificationController(Get.find<NotificationUseCases>()),
      permanent: true,
    );
  }
}
