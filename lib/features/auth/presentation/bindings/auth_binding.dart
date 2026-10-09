import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/network/api_binding.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/auth_remote_data_source.dart';
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

    // Auth is built on the shared client, so make sure it exists. The app
    // registers it at startup; this covers any entry point that reaches the
    // login route first.
    ApiBinding.register();

    final controller = Get.find<DioApiService>();

    // The one place that knows a session has ended. The refresh interceptor
    // raises this after clearing the tokens; turning it into a screen change
    // here keeps navigation out of the network layer and keeps every feature
    // from having to handle expiry for itself.
    controller.onSessionExpired = () => _handleSessionExpired();

    Get.put<AuthRepository>(
      AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(controller),
        localDataSource: AuthLocalDataSource(),
        tokenStorage: Get.find(),
      ),
      permanent: true,
    );
    Get.put<AuthUseCases>(AuthUseCases(Get.find<AuthRepository>()), permanent: true);
    Get.put<AuthController>(
      AuthController(Get.find<AuthUseCases>()),
      permanent: true,
    );
  }

  /// Sends the resident back to the login screen after an unrecoverable expiry.
  ///
  /// Guarded because the failure arrives from a background request that may land
  /// while a route change is already under way, and two `offAllNamed` calls for
  /// one expiry would flicker the whole stack.
  static void _handleSessionExpired() {
    if (Get.currentRoute == AppRoutes.login) {
      return;
    }
    if (Get.isRegistered<SessionController>()) {
      Get.find<SessionController>().clearResident();
    }
    Get.offAllNamed(AppRoutes.login);
  }
}