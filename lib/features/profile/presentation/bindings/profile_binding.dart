import 'package:get/get.dart';

import '../../../../core/network/user_preferences_remote_data_source.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../controllers/profile_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ProfileController>(
      ProfileController(
        Get.find<SessionController>(),
        preferencesRemote: Get.isRegistered<UserPreferencesRemoteDataSource>()
            ? Get.find<UserPreferencesRemoteDataSource>()
            : null,
      ),
      permanent: true,
    );
  }
}
