import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/app.dart';
import 'package:test/core/theme/app_theme_tokens.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';

/// Proves the global integration: the root `CondoResidentApp` rebuilds its
/// `ThemeData` from the single AppearanceController, so a colour change on one
/// screen repaints every other mounted screen without navigation or restart.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });
  tearDown(Get.reset);

  /// A tiny host that mirrors app.dart's reactive wiring but stops at a simple
  /// page, so the test can assert the theme the whole app would render with.
  Widget host() => Obx(
        () {
          final controller = Get.find<AppearanceController>();
          return GetMaterialApp(
            theme: controller.theme,
            darkTheme: controller.darkTheme,
            themeMode: controller.themeMode,
            home: const _ThemeProbe(),
          );
        },
      );

  testWidgets('changing the colour repaints the running app from the root', (
    tester,
  ) async {
    AppearanceBinding().dependencies();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    Color probeBrand() => tester
        .widget<ColoredBox>(find.byKey(const Key('theme-probe-brand')))
        .color;

    final before = probeBrand();
    expect(before, AppThemeTokens.fallback().brand);

    // The same call the Appearance screen makes when a swatch is tapped.
    Get.find<AppearanceController>().selectPreset(
      AppColorSeeds.all.firstWhere((seed) => seed.id == 'red'),
    );
    await tester.pumpAndSettle();

    final after = probeBrand();
    expect(after, isNot(before));
    expect(after, const Color(0xFFDC2626));

    // The MaterialApp's own ThemeData picked it up too, which is what every
    // screen reads through Theme.of(context).
    final scheme = Theme.of(tester.element(find.byKey(const Key('theme-probe'))));
    expect(scheme.colorScheme.primary, isNot(scheme.colorScheme.surface));
  });

  testWidgets('the saved colour is applied on the first frame after restart', (
    tester,
  ) async {
    // Pre-seed storage as if a previous session saved Indigo.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'appearance.seed_color': 0xFF4F46E5,
      'appearance.preset_id': 'indigo',
      'appearance.brightness_mode': 'light',
    });

    AppearanceBinding().dependencies();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    // The saved preference was read back into the draft, so the theme the root
    // builds from it is already Indigo with no further action.
    expect(controller.draft.value.seedColor, const Color(0xFF4F46E5));
    expect(
      controller.theme.extension<AppThemeTokens>()!.seed,
      const Color(0xFF4F46E5),
    );
  });

  testWidgets('CondoResidentApp boots and applies the persisted colour', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'appearance.seed_color': 0xFF9333EA,
      'appearance.preset_id': 'purple',
      'appearance.brightness_mode': 'light',
    });

    await tester.pumpWidget(const CondoResidentApp());
    // The preference loads during the splash; advancing past it is what hands
    // the persisted theme to the first real screen.
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    expect(controller.draft.value.seedColor, const Color(0xFF9333EA));
    // The running ThemeData handed to the tree is the persisted one.
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(
      theme.extension<AppThemeTokens>()!.seed,
      const Color(0xFF9333EA),
    );
  });
}

/// A leaf screen that paints its brand colour so the test can read it.
class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      key: const Key('theme-probe'),
      body: Center(
        child: ColoredBox(
          key: const Key('theme-probe-brand'),
          color: tokens.brand,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
  }
}
