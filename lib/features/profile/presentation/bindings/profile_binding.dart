import 'package:get/get.dart';

import '../../data/datasources/profile_local_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/profile_usecases.dart';
import '../controllers/profile_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ProfileRepository>(
      ProfileRepositoryImpl(ProfileLocalDataSource()),
      permanent: true,
    );
    Get.put<ProfileUseCases>(
      ProfileUseCases(Get.find<ProfileRepository>()),
      permanent: true,
    );
    Get.put<ProfileController>(
      ProfileController(Get.find<ProfileUseCases>()),
      permanent: true,
    );
  }
}
