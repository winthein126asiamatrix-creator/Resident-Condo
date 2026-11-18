import '../entities/app_config.dart';
import '../entities/condo_config.dart';
import '../repositories/config_repository.dart';

class ConfigUseCases {
  const ConfigUseCases(this._repository);

  final ConfigRepository _repository;

  Future<AppConfig> fetchAppConfig() => _repository.fetchAppConfig();

  Future<AppConfig?> readCachedAppConfig() => _repository.readCachedAppConfig();

  Future<void> cacheAppConfig(AppConfig config) =>
      _repository.cacheAppConfig(config);

  Future<CondoConfig> fetchCondoConfig() => _repository.fetchCondoConfig();

  Future<CondoConfig?> readCachedCondoConfig(String accountKey) =>
      _repository.readCachedCondoConfig(accountKey);

  Future<void> cacheCondoConfig(String accountKey, CondoConfig config) =>
      _repository.cacheCondoConfig(accountKey, config);

  Future<void> clearCondoConfig(String accountKey) =>
      _repository.clearCondoConfig(accountKey);
}
