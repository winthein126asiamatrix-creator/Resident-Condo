import 'package:get/get.dart';

import '../../data/datasources/auth_local_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // Pushing the login route again must not reset a form the resident is
    // halfway through filling in.
    if (Get.isRegistered<AuthController>()) {
      return;
    }
    Get.put<AuthRepository>(
      AuthRepositoryImpl(AuthLocalDataSource()),
      permanent: true,
    );
    Get.put<AuthUseCases>(AuthUseCases(Get.find<AuthRepository>()), permanent: true);
    Get.put<AuthController>(
      AuthController(Get.find<AuthUseCases>()),
      permanent: true,
    );
  }
}