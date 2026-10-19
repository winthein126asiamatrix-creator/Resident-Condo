import 'package:get/get.dart';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../data/datasources/notification_local_data_source.dart';
import '../../data/datasources/notification_remote_data_source.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/notification_usecases.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../controllers/notification_controller.dart';

/// Wires the notification feature.
///
/// The remote data source is the app's shared [DioApiService], so notifications
/// behave like sign-in and every other call: one HTTP client, one token, one set
/// of error translations. The device's copy goes through the existing
/// `ApiCacheStore`, which `ApiBinding` has already registered.
///
/// Everything is permanent, like the rest of `AppBinding`, because the bell on
/// the dashboard reads [NotificationController] and has to find the same
/// instance the notifications page uses.
class NotificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<NotificationRemoteDataSource>(
      NotificationRemoteDataSource(Get.find<DioApiService>()),
      permanent: true,
    );
    Get.put<NotificationLocalDataSource>(
      NotificationLocalDataSource(
        cache: Get.isRegistered<ApiCacheStore>()
            ? Get.find<ApiCacheStore>()
            : null,
        // Scoping the cached history to the signed-in resident is what stops one
        // account's notifications showing under another on a shared device.
        accountKey: _currentAccountKey,
      ),
      permanent: true,
    );
    Get.put<NotificationRepository>(
      NotificationRepositoryImpl(
        remoteDataSource: Get.find<NotificationRemoteDataSource>(),
        localDataSource: Get.find<NotificationLocalDataSource>(),
      ),
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

  /// The resident whose notifications the cache belongs to, or null when nobody
  /// is signed in.
  static String? _currentAccountKey() {
    if (!Get.isRegistered<SessionController>()) {
      return null;
    }
    final session = Get.find<SessionController>().session.value;
    if (session == null) {
      return null;
    }
    final email = session.email.trim();
    return email.isEmpty ? session.name.trim() : email;
  }
}
