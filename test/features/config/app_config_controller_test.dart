import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/features/config/domain/entities/app_config.dart';
import 'package:test/features/config/domain/entities/condo_config.dart';
import 'package:test/features/config/domain/repositories/config_repository.dart';
import 'package:test/features/config/domain/usecases/config_usecases.dart';
import 'package:test/features/config/presentation/controllers/app_config_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppConfig versionConfig({String? min, String? latest}) {
    return AppConfig.parse(<String, dynamic>{
      'app_version': <String, dynamic>{
        'min_supported': ?min,
        'latest': ?latest,
        'update_url': 'https://example.com/app',
      },
      'maintenance': <String, dynamic>{'enabled': false},
    });
  }

  test('requires an update below the minimum supported version', () async {
    final repository = _FakeConfigRepository(
      remoteAppConfig: versionConfig(min: '2.0.0', latest: '2.1.0'),
    );
    final controller = AppConfigController(ConfigUseCases(repository));

    await controller.load();
    controller.installedVersion.value = '1.9.0';

    expect(controller.updateRequirement, UpdateRequirement.mandatory);
    expect(controller.shouldShowOptionalUpdate, isFalse);
    expect(repository.cachedAppConfig, isNotNull);
  });

  test('offers an optional update between minimum and latest', () async {
    final repository = _FakeConfigRepository(
      remoteAppConfig: versionConfig(min: '1.0.0', latest: '2.1.0'),
    );
    final controller = AppConfigController(ConfigUseCases(repository));

    await controller.load();
    controller.installedVersion.value = '2.0.0';

    expect(controller.updateRequirement, UpdateRequirement.optional);
    expect(controller.shouldShowOptionalUpdate, isTrue);
  });

  test('reports no update when the installed version is current', () async {
    final repository = _FakeConfigRepository(
      remoteAppConfig: versionConfig(min: '1.0.0', latest: '2.1.0'),
    );
    final controller = AppConfigController(ConfigUseCases(repository));

    await controller.load();
    controller.installedVersion.value = '2.1.0';

    expect(controller.updateRequirement, UpdateRequirement.none);
  });

  test('exposes maintenance mode from the config', () async {
    final repository = _FakeConfigRepository(
      remoteAppConfig: AppConfig.parse(<String, dynamic>{
        'app_version': <String, dynamic>{'latest': '1.0.0'},
        'maintenance': <String, dynamic>{
          'enabled': true,
          'message': 'Down for upgrades',
        },
      }),
    );
    final controller = AppConfigController(ConfigUseCases(repository));

    await controller.load();

    expect(controller.maintenanceActive, isTrue);
    expect(controller.maintenance?.message, 'Down for upgrades');
  });

  test('keeps the cached config when the refresh fails', () async {
    final repository = _FakeConfigRepository(
      cachedAppConfig: versionConfig(latest: '1.5.0'),
      remoteError: const AppException('Offline'),
    );
    final controller = AppConfigController(ConfigUseCases(repository));

    await controller.load();

    expect(controller.config.value?.version?.latest, '1.5.0');
    expect(controller.errorMessage.value, 'Offline');
  });

  test('persists an optional update dismissal', () async {
    final repository = _FakeConfigRepository(
      remoteAppConfig: versionConfig(min: '1.0.0', latest: '2.0.0'),
    );
    final controller = AppConfigController(ConfigUseCases(repository));

    await controller.load();
    controller.installedVersion.value = '1.5.0';
    expect(controller.shouldShowOptionalUpdate, isTrue);

    await controller.dismissOptionalUpdate();
    expect(controller.shouldShowOptionalUpdate, isFalse);

    final restored = AppConfigController(ConfigUseCases(repository));
    await restored.load();
    restored.installedVersion.value = '1.5.0';

    expect(restored.shouldShowOptionalUpdate, isFalse);
  });

  test('deduplicates concurrent loads', () async {
    final repository = _FakeConfigRepository(
      remoteAppConfig: versionConfig(latest: '1.0.0'),
    );
    final controller = AppConfigController(ConfigUseCases(repository));

    await Future.wait([controller.load(), controller.load()]);

    expect(repository.appFetchCalls, 1);
  });
}

class _FakeConfigRepository implements ConfigRepository {
  _FakeConfigRepository({
    this.cachedAppConfig,
    this.remoteAppConfig,
    this.remoteError,
  });

  AppConfig? cachedAppConfig;
  AppConfig? remoteAppConfig;
  Object? remoteError;
  int appFetchCalls = 0;

  @override
  Future<AppConfig> fetchAppConfig() async {
    appFetchCalls++;
    final error = remoteError;
    if (error != null) throw error;
    return remoteAppConfig!;
  }

  @override
  Future<AppConfig?> readCachedAppConfig() async => cachedAppConfig;

  @override
  Future<void> cacheAppConfig(AppConfig config) async {
    cachedAppConfig = config;
  }

  @override
  Future<CondoConfig> fetchCondoConfig() => throw UnimplementedError();

  @override
  Future<CondoConfig?> readCachedCondoConfig(String accountKey) =>
      throw UnimplementedError();

  @override
  Future<void> cacheCondoConfig(String accountKey, CondoConfig config) =>
      throw UnimplementedError();

  @override
  Future<void> clearCondoConfig(String accountKey) =>
      throw UnimplementedError();
}
