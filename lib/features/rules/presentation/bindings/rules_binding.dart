import 'package:get/get.dart';

import '../../data/datasources/rules_local_data_source.dart';
import '../../data/repositories/rules_repository_impl.dart';
import '../../domain/repositories/rules_repository.dart';
import '../../domain/usecases/rules_usecases.dart';
import '../controllers/rules_controller.dart';

class RulesBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<RulesRepository>(
      RulesRepositoryImpl(RulesLocalDataSource()),
      permanent: true,
    );
    Get.put<RulesUseCases>(
      RulesUseCases(Get.find<RulesRepository>()),
      permanent: true,
    );
    Get.put<RulesController>(
      RulesController(Get.find<RulesUseCases>()),
      permanent: true,
    );
  }
}
