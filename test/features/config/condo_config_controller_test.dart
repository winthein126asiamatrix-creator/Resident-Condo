import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/config/domain/entities/app_config.dart';
import 'package:test/features/config/domain/entities/condo_config.dart';
import 'package:test/features/config/domain/repositories/config_repository.dart';
import 'package:test/features/config/domain/usecases/config_usecases.dart';
import 'package:test/features/config/presentation/controllers/condo_config_controller.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  CondoConfig configWith({required Map<String, dynamic> features}) {
    return CondoConfig.parse(<String, dynamic>{'features': features});
  }

  test('treats every feature as disabled before a config resolves', () {
    final controller = CondoConfigController(
      ConfigUseCases(_FakeConfigRepository()),
      sessionController: SessionController(),
    );

    expect(controller.hasConfig, isFalse);
    expect(controller.isFeatureEnabled(CondoFeature.payments), isFalse);
    expect(controller.partialPaymentEnabled, isFalse);
  });

  test('loads the config for the signed in account', () async {
    final session = SessionController()
      ..setSession(
        const AuthUser(id: 7, name: 'Aye', phone: '', role: 'owner'),
      );
    final repository = _FakeConfigRepository()
      ..remoteConfigs['user:7'] = configWith(
        features: <String, dynamic>{'payments': true, 'lease': true},
      );
    final controller = CondoConfigController(
      ConfigUseCases(repository),
      sessionController: session,
    );

    await controller.loadForSession();

    expect(repository.fetchedAccounts, ['user:7']);
    expect(controller.isFeatureEnabled(CondoFeature.payments), isTrue);
    expect(controller.isFeatureEnabled(CondoFeature.lease), isTrue);
    expect(controller.isFeatureEnabled(CondoFeature.parking), isFalse);
    expect(controller.partialPaymentEnabled, isFalse);
    expect(controller.isResolved.value, isTrue);
  });

  test('keeps each account cache separate', () async {
    final session = SessionController()
      ..setSession(
        const AuthUser(id: 1, name: 'One', phone: '', role: 'owner'),
      );
    final repository = _FakeConfigRepository()
      ..remoteConfigs['user:1'] = configWith(
        features: <String, dynamic>{'payments': true},
      )
      ..remoteConfigs['user:2'] = configWith(
        features: <String, dynamic>{'maintenance': true},
      );
    final controller = CondoConfigController(
      ConfigUseCases(repository),
      sessionController: session,
    );

    await controller.loadForSession();
    expect(controller.isFeatureEnabled(CondoFeature.payments), isTrue);

    session.setSession(
      const AuthUser(id: 2, name: 'Two', phone: '', role: 'owner'),
    );
    await controller.loadForSession();

    expect(repository.fetchedAccounts, ['user:1', 'user:2']);
    expect(controller.isFeatureEnabled(CondoFeature.payments), isFalse);
    expect(controller.isFeatureEnabled(CondoFeature.maintenance), isTrue);
    expect(repository.savedAccounts, ['user:1', 'user:2']);
  });

  test('keeps the cached config when the refresh fails', () async {
    final session = SessionController()
      ..setSession(
        const AuthUser(id: 3, name: 'Three', phone: '', role: 'owner'),
      );
    final repository = _FakeConfigRepository()
      ..cachedConfigs['user:3'] = configWith(
        features: <String, dynamic>{'payments': true},
      )
      ..remoteConfigs['user:3'] = configWith(
        features: <String, dynamic>{'maintenance': true},
      )
      ..remoteError = const AppException('Offline');
    final controller = CondoConfigController(
      ConfigUseCases(repository),
      sessionController: session,
    );

    await controller.loadForSession();

    expect(controller.isFeatureEnabled(CondoFeature.payments), isTrue);
    expect(controller.errorMessage.value, 'Offline');
  });

  test(
    'uses the cached copy without refreshing an unverified session',
    () async {
      final session = SessionController()
        ..setSession(
          const AuthUser(id: 4, name: 'Four', phone: '', role: 'owner'),
        );
      final repository = _FakeConfigRepository()
        ..cachedConfigs['user:4'] = configWith(
          features: <String, dynamic>{'facilities': true},
        );
      final controller = CondoConfigController(
        ConfigUseCases(repository),
        sessionController: session,
      );

      await controller.loadForSession(refresh: false);

      expect(repository.fetchedAccounts, isEmpty);
      expect(controller.isFeatureEnabled(CondoFeature.facilities), isTrue);
    },
  );

  test('clears the in-memory config when the session ends', () async {
    final session = SessionController()
      ..setSession(
        const AuthUser(id: 5, name: 'Five', phone: '', role: 'owner'),
      );
    final repository = _FakeConfigRepository()
      ..remoteConfigs['user:5'] = configWith(
        features: <String, dynamic>{'payments': true},
      );
    final controller = CondoConfigController(
      ConfigUseCases(repository),
      sessionController: session,
    );

    await controller.loadForSession();
    controller.clear();

    expect(controller.hasConfig, isFalse);
    expect(controller.isResolved.value, isFalse);
    expect(controller.isFeatureEnabled(CondoFeature.payments), isFalse);
  });
}

class _FakeConfigRepository implements ConfigRepository {
  final remoteConfigs = <String, CondoConfig>{};
  final cachedConfigs = <String, CondoConfig>{};
  final fetchedAccounts = <String>[];
  final savedAccounts = <String>[];
  Object? remoteError;

  @override
  Future<CondoConfig> fetchCondoConfig() async {
    final accountKey = remoteConfigs.keys.firstWhere(
      (key) => !fetchedAccounts.contains(key),
      orElse: () => remoteConfigs.keys.last,
    );
    fetchedAccounts.add(accountKey);
    final error = remoteError;
    if (error != null) throw error;
    return remoteConfigs[accountKey]!;
  }

  @override
  Future<CondoConfig?> readCachedCondoConfig(String accountKey) async =>
      cachedConfigs[accountKey];

  @override
  Future<void> cacheCondoConfig(String accountKey, CondoConfig config) async {
    savedAccounts.add(accountKey);
    cachedConfigs[accountKey] = config;
  }

  @override
  Future<void> clearCondoConfig(String accountKey) async {
    cachedConfigs.remove(accountKey);
  }

  @override
  Future<AppConfig> fetchAppConfig() => throw UnimplementedError();

  @override
  Future<AppConfig?> readCachedAppConfig() => throw UnimplementedError();

  @override
  Future<void> cacheAppConfig(AppConfig config) => throw UnimplementedError();
}
