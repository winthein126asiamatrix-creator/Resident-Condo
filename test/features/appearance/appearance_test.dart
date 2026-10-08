import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/features/appearance/data/datasources/appearance_local_data_source.dart';
import 'package:test/features/appearance/data/repositories/appearance_repository_impl.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/domain/entities/appearance_preference.dart';
import 'package:test/features/appearance/domain/repositories/appearance_repository.dart';
import 'package:test/features/appearance/domain/usecases/appearance_usecases.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';

/// Appearance is wired to `Get.changeTheme`, so every test that exercises the
/// controller needs a `GetMaterialApp` mounted, or the swap throws.
Future<AppearanceController> pumpController(WidgetTester tester) async {
  late AppearanceController controller;
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (context) {
          controller = Get.find<AppearanceController>();
          return const SizedBox.shrink();
        },
      ),
      initialBinding: AppearanceBinding(),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('defaults', () {
    test('a fresh install is the shipped teal following the system', () {
      final defaults = AppearancePreference.defaults();

      expect(defaults.seedColor, AppColorSeeds.defaultSeed.color);
      expect(defaults.presetId, 'teal');
      expect(defaults.brightnessMode, AppBrightnessMode.system);
      expect(defaults.isCustomColor, isFalse);
      expect(defaults.label, 'Teal');
    });

    test('the palette offers fifteen distinct presets', () {
      expect(AppColorSeeds.all, hasLength(15));
      expect(
        AppColorSeeds.all.map((seed) => seed.id).toSet(),
        hasLength(AppColorSeeds.all.length),
      );
      expect(AppColorSeeds.byId('teal')?.color, AppColorSeeds.defaultSeed.color);
      expect(AppColorSeeds.byId('nope'), isNull);
    });
  });

  group('controller', () {
    testWidgets('starts clean, with nothing to apply', (tester) async {
      final controller = await pumpController(tester);
      await tester.pumpAndSettle();

      expect(controller.saved.value, AppearancePreference.defaults());
      expect(controller.draft.value, AppearancePreference.defaults());
      expect(controller.hasUnsavedChanges, isFalse);
      expect(controller.canReset, isFalse);
    });

    testWidgets('picking a preset marks the draft as unapplied',
        (tester) async {
      final controller = await pumpController(tester);
      await tester.pumpAndSettle();

      controller.selectPreset(
        AppColorSeeds.all.firstWhere((seed) => seed.id == 'indigo'),
      );

      expect(controller.draft.value.seedColor, const Color(0xFF4F46E5));
      expect(controller.draft.value.presetId, 'indigo');
      // Still nothing saved, so nothing may have reached the app theme yet.
      expect(controller.saved.value, AppearancePreference.defaults());
      expect(controller.hasUnsavedChanges, isTrue);
      expect(controller.canReset, isTrue);
    });

    testWidgets('applying commits the draft to the saved preference',
        (tester) async {
      final controller = await pumpController(tester);
      await tester.pumpAndSettle();

      controller.selectPreset(
        AppColorSeeds.all.firstWhere((seed) => seed.id == 'pink'),
      );
      controller.selectBrightnessMode(AppBrightnessMode.dark);
      final applied = await controller.applyTheme();
      await tester.pumpAndSettle();

      expect(applied, isTrue);
      expect(controller.saved.value.seedColor, const Color(0xFFDB2777));
      expect(controller.saved.value.brightnessMode, AppBrightnessMode.dark);
      expect(controller.hasUnsavedChanges, isFalse);
    });

    testWidgets('the preview follows the draft, not the saved preference',
        (tester) async {
      final controller = await pumpController(tester);
      await tester.pumpAndSettle();

      controller.selectPreset(
        AppColorSeeds.all.firstWhere((seed) => seed.id == 'orange'),
      );
      await tester.pump();

      expect(controller.previewTokens.brand, isNot(AppearancePreference.defaults().seedColor));
      expect(controller.previewTokens.seed, const Color(0xFFEA580C));
      // The saved preference has not moved.
      expect(controller.saved.value.seedColor, AppColorSeeds.defaultSeed.color);
    });

    testWidgets('a custom colour drops the preset id and shows its hex',
        (tester) async {
      final controller = await pumpController(tester);
      await tester.pumpAndSettle();

      const chosen = Color(0xFF7C3AED);
      controller.previewCustomColor(chosen);
      controller.commitCustomColor(chosen);

      expect(controller.draft.value.seedColor, chosen);
      expect(controller.draft.value.isCustomColor, isTrue);
      expect(controller.draft.value.label, '#7C3AED');
    });

    testWidgets('System resolves against the device brightness',
        (tester) async {
      final controller = await pumpController(tester);
      await tester.pumpAndSettle();

      controller.selectBrightnessMode(AppBrightnessMode.system);
      final systemBrightness = AppearanceController.currentPlatformBrightness();
      expect(
        controller.previewBrightness,
        systemBrightness,
      );

      controller.selectBrightnessMode(AppBrightnessMode.dark);
      expect(controller.previewBrightness, Brightness.dark);

      controller.selectBrightnessMode(AppBrightnessMode.light);
      expect(controller.previewBrightness, Brightness.light);
    });

    testWidgets('reset restores the default and applies it immediately',
        (tester) async {
      final controller = await pumpController(tester);
      await tester.pumpAndSettle();

      controller.selectPreset(
        AppColorSeeds.all.firstWhere((seed) => seed.id == 'red'),
      );
      controller.selectBrightnessMode(AppBrightnessMode.dark);
      await controller.applyTheme();
      await tester.pumpAndSettle();

      final ok = await controller.resetToDefault();
      await tester.pumpAndSettle();

      expect(ok, isTrue);
      expect(controller.saved.value, AppearancePreference.defaults());
      expect(controller.draft.value, AppearancePreference.defaults());
      expect(controller.canReset, isFalse);
    });

    testWidgets('a failing repository surfaces a message instead of throwing',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const SizedBox.shrink(),
          initialBinding: BindingsBuilder(() {
            Get.put<AppearanceRepository>(_FailingRepository());
            Get.put<AppearanceUseCases>(AppearanceUseCases(Get.find<AppearanceRepository>()));
            Get.put<AppearanceController>(
              AppearanceController(Get.find<AppearanceUseCases>()),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      final controller = Get.find<AppearanceController>();

      expect(
        controller.errorMessage.value,
        'Unable to load your appearance settings.',
      );
      expect(await controller.applyTheme(), isFalse);
      expect(controller.errorMessage.value, 'Unable to apply the theme.');
    });
  });

  group('data source', () {
    test('save and reset round trip', () async {
      final source = AppearanceLocalDataSource();

      const purple = Color(0xFF9333EA);
      final saved = await source.savePreference(
        const AppearancePreference(
          seedColor: purple,
          presetId: 'purple',
          brightnessMode: AppBrightnessMode.dark,
        ),
      );
      expect(saved.seedColor, purple);
      expect((await source.getPreference()).brightnessMode, AppBrightnessMode.dark);

      final reset = await source.resetPreference();
      expect(reset, AppearancePreference.defaults());
    });
  });

  group('binding', () {
    test('provides the appearance dependency graph', () {
      AppearanceBinding().dependencies();

      expect(Get.find<AppearanceRepository>(), isA<AppearanceRepositoryImpl>());
      expect(Get.find<AppearanceUseCases>(), isA<AppearanceUseCases>());
      expect(Get.find<AppearanceController>(), isA<AppearanceController>());
      expect(
        Get.find<AppearanceController>().useCases.repository,
        isA<AppearanceRepositoryImpl>(),
      );
    });
  });
}

class _FailingRepository implements AppearanceRepository {
  @override
  Future<AppearancePreference> getPreference() =>
      throw Exception('offline');

  @override
  Future<AppearancePreference> savePreference(
    AppearancePreference preference,
  ) =>
      throw Exception('offline');

  @override
  Future<AppearancePreference> resetPreference() async {
    // A reset that does not reach storage must not silently report success.
    throw Exception('offline');
  }
}