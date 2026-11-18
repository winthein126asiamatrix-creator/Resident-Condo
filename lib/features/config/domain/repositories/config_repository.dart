import '../entities/app_config.dart';
import '../entities/condo_config.dart';

abstract class ConfigRepository {
  Future<AppConfig> fetchAppConfig();

  Future<AppConfig?> readCachedAppConfig();

  Future<void> cacheAppConfig(AppConfig config);

  Future<CondoConfig> fetchCondoConfig();

  Future<CondoConfig?> readCachedCondoConfig(String accountKey);

  Future<void> cacheCondoConfig(String accountKey, CondoConfig config);

  Future<void> clearCondoConfig(String accountKey);
}
