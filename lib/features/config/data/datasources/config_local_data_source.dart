import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/condo_config.dart';

class ConfigLocalDataSource {
  ConfigLocalDataSource({this.cache});

  static const String appConfigKey = 'app_config';
  static const String condoConfigKeyPrefix = 'condo_config:';

  static String condoConfigKey(String accountKey) =>
      '$condoConfigKeyPrefix$accountKey';

  final ApiCacheStore? cache;

  Future<AppConfig?> readAppConfig() async {
    final entry = await cache?.read(appConfigKey);
    if (entry == null) return null;
    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) return await _discardAppConfig();
      return AppConfig.fromJson(Map<String, dynamic>.from(json));
    } catch (error) {
      superPrint(
        'Discarded unreadable app config cache: $error',
        title: 'Config',
      );
      return _discardAppConfig();
    }
  }

  Future<void> saveAppConfig(AppConfig config) async {
    await cache?.save(key: appConfigKey, payload: config.toJson());
  }

  Future<CondoConfig?> readCondoConfig(String accountKey) async {
    final key = condoConfigKey(accountKey);
    final entry = await cache?.read(key);
    if (entry == null || entry.accountKey != accountKey) return null;
    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) return await _discardCondoConfig(key);
      return CondoConfig.fromJson(Map<String, dynamic>.from(json));
    } catch (error) {
      superPrint(
        'Discarded unreadable condo config cache: $error',
        title: 'Config',
      );
      return _discardCondoConfig(key);
    }
  }

  Future<void> saveCondoConfig(String accountKey, CondoConfig config) async {
    await cache?.save(
      key: condoConfigKey(accountKey),
      accountKey: accountKey,
      payload: config.toJson(),
    );
  }

  Future<void> clearCondoConfig(String accountKey) async {
    await cache?.invalidate(condoConfigKey(accountKey));
  }

  Future<AppConfig?> _discardAppConfig() async {
    await cache?.invalidate(appConfigKey);
    return null;
  }

  Future<CondoConfig?> _discardCondoConfig(String key) async {
    await cache?.invalidate(key);
    return null;
  }
}
