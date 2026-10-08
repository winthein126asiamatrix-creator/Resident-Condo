import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/theme/app_theme.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';
import 'package:test/features/appearance/presentation/pages/appearance_page.dart';

/// The whole screen, themed the way the app themes it in production.
Widget buildAppearanceApp() => GetMaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AppearancePage(),
      initialBinding: AppearanceBinding(),
    );

/// Golden images of the Appearance screen, so the layout can be reviewed as an
/// image rather than as a pile of assertions.
///
/// Regenerate after an intentional design change:
/// `flutter test test/features/appearance/appearance_golden_test.dart --update-goldens`
void main() {
  setUp(() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  Get.testMode = true;
});
  tearDown(Get.reset);

  Future<void> capture(
    WidgetTester tester,
    String name, {
    void Function(AppearanceController controller)? arrange,
  }) async {
    // Tall enough for the whole screen plus the sticky action bar, so a review
    // image shows it in one piece rather than clipped at a phone's fold.
    tester.view.physicalSize = const Size(390 * 3, 1460 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildAppearanceApp());
    await tester.pumpAndSettle();

    if (arrange != null) {
      arrange(Get.find<AppearanceController>());
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('appearance-$name.png'),
    );
  }

  testWidgets('light', (tester) => capture(tester, 'light'));

  testWidgets('dark', (tester) => capture(
        tester,
        'dark',
        arrange: (controller) =>
            controller.selectBrightnessMode(AppBrightnessMode.dark),
      ));

  testWidgets('indigo chosen', (tester) => capture(
        tester,
        'indigo',
        arrange: (controller) => controller.selectPreset(
          AppColorSeeds.all.firstWhere((seed) => seed.id == 'indigo'),
        ),
      ));

  testWidgets('amber chosen', (tester) => capture(
        tester,
        'amber',
        arrange: (controller) => controller.selectPreset(
          AppColorSeeds.all.firstWhere((seed) => seed.id == 'amber'),
        ),
      ));

  testWidgets('a custom colour', (tester) => capture(
        tester,
        'custom',
        arrange: (controller) =>
            controller.commitCustomColor(const Color(0xFF7C3AED)),
      ));

  testWidgets('the custom picker sheet', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildAppearanceApp());
    await tester.pumpAndSettle();

    final custom = find.byKey(const Key('appearance-seed-custom'));
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    await tester.tap(custom);
    await tester.pumpAndSettle();

    // The sheet lives on its own route, so the app root is the only thing that
    // includes both the page behind it and the sheet over it.
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('appearance-picker.png'),
    );
  });
}