import 'package:get/get.dart';

import '../../data/datasources/appearance_local_data_source.dart';
import '../../data/repositories/appearance_repository_impl.dart';
import '../../domain/repositories/appearance_repository.dart';
import '../../domain/usecases/appearance_usecases.dart';
import '../controllers/appearance_controller.dart';

/// Registers the appearance dependency graph.
///
/// The controller is app scoped rather than page scoped, because the root
/// `GetMaterialApp` reads it to build the theme, so it has to exist before the
/// first frame. [dependencies] is therefore safe to run more than once: the root
/// widget calls it, and so does this screen's route.
class AppearanceBinding extends Bindings {
  @override
  void dependencies() {
    if (Get.isRegistered<AppearanceController>()) {
      return;
    }
    Get.put<AppearanceRepository>(
      AppearanceRepositoryImpl(AppearanceLocalDataSource()),
      permanent: true,
    );
    Get.put<AppearanceUseCases>(
      AppearanceUseCases(Get.find<AppearanceRepository>()),
      permanent: true,
    );
    Get.put<AppearanceController>(
      AppearanceController(Get.find<AppearanceUseCases>()),
      permanent: true,
    );
  }
}