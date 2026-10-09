import 'package:get/get.dart';

import 'dio_api_service.dart';
import 'secure_token_storage.dart';
import 'token_storage.dart';

/// Registers the shared network layer.
///
/// App scoped and permanent, because there is one HTTP client for the whole
/// app: a second `Dio` instance would mean a second connection pool and a
/// second token to keep in sync.
abstract final class ApiBinding extends Bindings {
  /// Registers the shared client, unless it is already in the container.
  ///
  /// [tokenStorage] and [service] exist for tests, which swap the platform
  /// keychain and the real network for in-memory fakes. Left null in the app,
  /// where the keychain and the configured base URL are used.
  ///
  /// A store already in the container is reused too, so a test can register its
  /// own before the app boots.
  static void register({TokenStorage? tokenStorage, DioApiService? service}) {
    if (Get.isRegistered<DioApiService>()) {
      return;
    }
    final storage = tokenStorage ??
        (Get.isRegistered<TokenStorage>()
            ? Get.find<TokenStorage>()
            : SecureTokenStorage());
    Get.put<TokenStorage>(storage, permanent: true);
    Get.put<DioApiService>(
      service ?? DioApiService(tokenStorage: storage),
      permanent: true,
    );
  }

  /// Satisfies [Bindings] so the layer can also be attached to a route.
  @override
  void dependencies() => register();
}