import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/app/routes/app_pages.dart';
import 'package:test/app/routes/app_routes.dart';
import 'package:test/features/config/domain/entities/app_config.dart';
import 'package:test/features/config/domain/entities/condo_config.dart';
import 'package:test/features/config/domain/repositories/config_repository.dart';
import 'package:test/features/config/domain/usecases/config_usecases.dart';
import 'package:test/features/config/presentation/controllers/app_config_controller.dart';
import 'package:test/features/config/presentation/middlewares/update_gate_middleware.dart';
import 'package:test/features/config/presentation/pages/app_config_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppConfig _appConfig({
  String min = '1.0.0',
  String latest = '2.0.0',
  String? updateUrl = 'https://example.com/app',
  bool maintenance = false,
}) => AppConfig.parse(<String, dynamic>{
  'app_version': <String, dynamic>{
    'min_supported': min,
    'latest': latest,
    'update_url': ?updateUrl,
  },
  'maintenance': <String, dynamic>{'enabled': maintenance},
});

Future<AppConfigController> _loadedController({
  required String installed,
  String min = '1.0.0',
  String latest = '2.0.0',
  String? updateUrl = 'https://example.com/app',
  bool maintenance = false,
  _FakeConfigRepository? repository,
}) async {
  final repo =
      repository ??
      _FakeConfigRepository(
        remoteAppConfig: _appConfig(
          min: min,
          latest: latest,
          updateUrl: updateUrl,
          maintenance: maintenance,
        ),
      );
  final controller = AppConfigController(ConfigUseCases(repo))
    ..config.value = repo.remoteAppConfig
    ..installedVersion.value = installed;
  return controller;
}

Future<void> _pumpGate(
  WidgetTester tester,
  AppConfigController controller,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Get.put<AppConfigController>(controller);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: AppConfigGate(
          child: Scaffold(
            key: const Key('app-child'),
            body: const Text('app content'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(Get.reset);

  test('app routes expose the dedicated update route and gate middleware', () {
    expect(
      AppPages.pages.any((page) => page.name == AppRoutes.appUpdate),
      isTrue,
    );
    final home = AppPages.pages.firstWhere(
      (page) => page.name == AppRoutes.home,
    );
    expect(home.middlewares?.first, isA<UpdateGateMiddleware>());
  });

  testWidgets('mandatory update shows only the blocking update screen', (
    tester,
  ) async {
    final controller = await _loadedController(
      installed: '0.9.0',
      min: '1.0.0',
      latest: '2.0.0',
    );
    await _pumpGate(tester, controller);

    expect(find.byKey(const Key('mandatory-update-screen')), findsOneWidget);
    expect(find.text('Update Required'), findsOneWidget);
    expect(find.byKey(const Key('mandatory-update-button')), findsOneWidget);
    expect(find.byKey(const Key('optional-update-later')), findsNothing);
    expect(find.byKey(const Key('optional-update-screen')), findsNothing);
    expect(find.byKey(const Key('app-child')), findsNothing);
    expect(
      find.text('Updating is required to continue using Condo Residents.'),
      findsOneWidget,
    );

    final popScope = tester.widget<PopScope<bool>>(find.byType(PopScope<bool>));
    expect(popScope.canPop, isFalse);
  });

  testWidgets('optional update shows Later and resumes the app', (
    tester,
  ) async {
    final controller = await _loadedController(
      installed: '1.5.0',
      min: '1.0.0',
      latest: '2.0.0',
    );
    await _pumpGate(tester, controller);

    expect(find.byKey(const Key('optional-update-screen')), findsOneWidget);
    expect(find.text('Update Available'), findsOneWidget);
    expect(find.byKey(const Key('optional-update-later')), findsOneWidget);
    expect(find.byKey(const Key('app-child')), findsNothing);

    await tester.tap(find.byKey(const Key('optional-update-later')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('optional-update-screen')), findsNothing);
    expect(find.byKey(const Key('app-child')), findsOneWidget);

    await tester.pumpWidget(Container(key: const Key('rebuild')));
    await _pumpGate(tester, controller);
    expect(find.byKey(const Key('optional-update-screen')), findsNothing);
    expect(find.byKey(const Key('app-child')), findsOneWidget);
  });

  testWidgets('current version skips the update screen', (tester) async {
    final controller = await _loadedController(
      installed: '2.0.0',
      min: '1.0.0',
      latest: '2.0.0',
    );
    await _pumpGate(tester, controller);

    expect(find.byKey(const Key('app-child')), findsOneWidget);
    expect(find.byKey(const Key('mandatory-update-screen')), findsNothing);
    expect(find.byKey(const Key('optional-update-screen')), findsNothing);
  });

  testWidgets('maintenance keeps priority over a mandatory update', (
    tester,
  ) async {
    final controller = await _loadedController(
      installed: '0.9.0',
      min: '1.0.0',
      latest: '2.0.0',
      maintenance: true,
    );
    await _pumpGate(tester, controller);

    expect(find.byKey(const Key('maintenance-screen')), findsOneWidget);
    expect(find.byKey(const Key('mandatory-update-screen')), findsNothing);
  });

  test(
    'middleware redirects feature routes during a mandatory update',
    () async {
      final controller = await _loadedController(
        installed: '0.9.0',
        min: '1.0.0',
        latest: '2.0.0',
      );
      Get.put<AppConfigController>(controller);
      final middleware = UpdateGateMiddleware();

      expect(middleware.redirect(AppRoutes.home)?.name, AppRoutes.appUpdate);
      expect(middleware.redirect(AppRoutes.appUpdate), isNull);

      controller.config.value = _appConfig(maintenance: true);
      expect(middleware.redirect(AppRoutes.home), isNull);
    },
  );

  test('force reload re-fetches /app/config for resume checks', () async {
    final repository = _FakeConfigRepository(remoteAppConfig: _appConfig());
    final controller = AppConfigController(ConfigUseCases(repository));

    await controller.load();
    await controller.load(force: true);

    expect(repository.appFetchCalls, 2);
  });

  test('Update Now opens the configured update URL', () async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launched = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            launched.add(call.arguments['url'] as String);
            return true;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final controller = await _loadedController(installed: '0.9.0');

    expect(await controller.openUpdateUrl(), isTrue);
    expect(launched, <String>['https://example.com/app']);
  });
}

class _FakeConfigRepository implements ConfigRepository {
  _FakeConfigRepository({required this.remoteAppConfig});

  final AppConfig remoteAppConfig;
  int appFetchCalls = 0;

  @override
  Future<AppConfig> fetchAppConfig() async {
    appFetchCalls++;
    return remoteAppConfig;
  }

  @override
  Future<AppConfig?> readCachedAppConfig() async => null;

  @override
  Future<void> cacheAppConfig(AppConfig config) async {}

  @override
  Future<CondoConfig> fetchCondoConfig() => throw UnimplementedError();

  @override
  Future<CondoConfig?> readCachedCondoConfig(String accountKey) async => null;

  @override
  Future<void> cacheCondoConfig(String accountKey, CondoConfig config) async {}

  @override
  Future<void> clearCondoConfig(String accountKey) async {}
}
