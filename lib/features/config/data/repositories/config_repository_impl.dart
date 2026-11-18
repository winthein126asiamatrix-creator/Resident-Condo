import '../../domain/entities/app_config.dart';
import '../../domain/entities/condo_config.dart';
import '../../domain/repositories/config_repository.dart';
import '../datasources/config_local_data_source.dart';
import '../datasources/config_remote_data_source.dart';

class ConfigRepositoryImpl implements ConfigRepository {
  const ConfigRepositoryImpl({
    required ConfigRemoteDataSource remoteDataSource,
    required ConfigLocalDataSource localDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource;

  final ConfigRemoteDataSource _remote;
  final ConfigLocalDataSource _local;

  @override
  Future<AppConfig> fetchAppConfig() => _remote.fetchAppConfig();

  @override
  Future<AppConfig?> readCachedAppConfig() => _local.readAppConfig();

  @override
  Future<void> cacheAppConfig(AppConfig config) => _local.saveAppConfig(config);

  @override
  Future<CondoConfig> fetchCondoConfig() => _remote.fetchCondoConfig();

  @override
  Future<CondoConfig?> readCachedCondoConfig(String accountKey) =>
      _local.readCondoConfig(accountKey);

  @override
  Future<void> cacheCondoConfig(String accountKey, CondoConfig config) =>
      _local.saveCondoConfig(accountKey, config);

  @override
  Future<void> clearCondoConfig(String accountKey) =>
      _local.clearCondoConfig(accountKey);
}
