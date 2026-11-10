import 'package:get/get.dart';

import '../../../../core/cache/api_cache_store.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../data/datasources/condo_service_local_data_source.dart';
import '../../data/datasources/condo_service_remote_data_source.dart';
import '../../data/repositories/condo_service_repository_impl.dart';
import '../../domain/repositories/condo_service_repository.dart';
import '../../domain/usecases/condo_service_usecases.dart';
import '../controllers/condo_service_controller.dart';

class CondoServiceBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CondoServiceRemoteDataSource>()) {
      Get.put<CondoServiceRemoteDataSource>(
        CondoServiceRemoteDataSource(Get.find()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CondoServiceRepository>()) {
      Get.put<CondoServiceRepository>(
        CondoServiceRepositoryImpl(
          remoteDataSource: Get.find<CondoServiceRemoteDataSource>(),
          localDataSource: CondoServiceLocalDataSource(
            cache: Get.isRegistered<ApiCacheStore>()
                ? Get.find<ApiCacheStore>()
                : null,
            // Requests are personal, so the device copy is scoped to the
            // resident who fetched it.
            accountKey: _currentAccountKey,
          ),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CondoServiceUseCases>()) {
      Get.put<CondoServiceUseCases>(
        CondoServiceUseCases(Get.find<CondoServiceRepository>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CondoServiceController>()) {
      Get.put<CondoServiceController>(
        CondoServiceController(Get.find<CondoServiceUseCases>()),
        permanent: true,
      );
    }
  }

  /// The resident whose requests the cache belongs to, or null when signed out.
  static String? _currentAccountKey() {
    if (!Get.isRegistered<SessionController>()) {
      return null;
    }
    final user = Get.find<SessionController>().currentUser;
    if (user == null) {
      return null;
    }
    if (user.id > 0) return 'user:${user.id}';
    final email = user.email?.trim() ?? '';
    return email.isEmpty ? user.displayName : email;
  }
}
