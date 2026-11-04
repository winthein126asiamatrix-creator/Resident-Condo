import 'package:get/get.dart';

import '../../../session/presentation/controllers/session_controller.dart';
import '../controllers/profile_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ProfileController>(
      ProfileController(Get.find<SessionController>()),
      permanent: true,
    );
  }
}
