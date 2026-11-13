import 'package:get/get.dart';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../data/datasources/lease_local_data_source.dart';
import '../../data/datasources/lease_remote_data_source.dart';
import '../../data/repositories/lease_repository_impl.dart';
import '../../domain/repositories/lease_repository.dart';
import '../../domain/usecases/lease_usecases.dart';
import '../controllers/lease_controller.dart';

class LeaseBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LeaseRemoteDataSource>()) {
      Get.put<LeaseRemoteDataSource>(
        LeaseRemoteDataSource(Get.find<DioApiService>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<LeaseLocalDataSource>()) {
      Get.put<LeaseLocalDataSource>(
        LeaseLocalDataSource(
          cache: Get.isRegistered<ApiCacheStore>()
              ? Get.find<ApiCacheStore>()
              : null,
          accountKey: _currentAccountKey,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<LeaseRepository>()) {
      Get.put<LeaseRepository>(
        LeaseRepositoryImpl(
          remoteDataSource: Get.find<LeaseRemoteDataSource>(),
          localDataSource: Get.find<LeaseLocalDataSource>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<LeaseUseCases>()) {
      Get.put<LeaseUseCases>(
        LeaseUseCases(Get.find<LeaseRepository>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<LeaseController>()) {
      Get.put<LeaseController>(
        LeaseController(Get.find<LeaseUseCases>()),
        permanent: true,
      );
    }
  }

  static String? _currentAccountKey() {
    if (!Get.isRegistered<SessionController>()) return null;
    final user = Get.find<SessionController>().currentUser;
    if (user == null || user.id <= 0) return null;
    return 'user:${user.id}';
  }
}
