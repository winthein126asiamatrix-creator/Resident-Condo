import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/routes/app_routes.dart';
import 'package:test/core/theme/app_theme_tokens.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';
import 'package:test/features/appearance/presentation/pages/appearance_page.dart';

/// The Appearance contract: a swatch moves only the preview, "Apply Theme" is
/// the only path to the running app, and leaving without it discards the try.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });
  tearDown(Get.reset);

  /// A navigator with the Appearance screen as a real route, so a back gesture
  /// exercises the discard path exactly as a resident would trigger it.
  Future<void> pumpWithAppearanceRoute(WidgetTester tester) async {
    GetMaterialApp buildApp() {
      final controller = Get.find<AppearanceController>();
      return GetMaterialApp(
        theme: controller.theme,
        darkTheme: controller.darkTheme,
        themeMode: controller.themeMode,
        initialRoute: '/probe',
        getPages: [
          GetPage<dynamic>(
            name: '/probe',
            page: () => const _ThemeProbePage(),
          ),
          GetPage<dynamic>(
            name: AppRoutes.appearance,
            page: () => const AppearancePage(),
            binding: AppearanceBinding(),
          ),
        ],
      );
    }

    await tester.pumpWidget(Obx(() => buildApp()));
    await tester.pumpAndSettle();
  }

  Future<void> openAppearance(WidgetTester tester) async {
    await tester.tap(find.text('Open appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your app color'), findsOneWidget);
  }

  Future<void> tapSwatch(WidgetTester tester, String id) async {
    final swatch = find.byKey(Key('appearance-seed-$id'));
    final scroll = find.byKey(const Key('appearance-scroll'));
    for (var i = 0; i < 15; i++) {
      if (swatch.evaluate().isNotEmpty) {
        await tester.ensureVisible(swatch.first);
        await tester.pumpAndSettle();
        if (swatch.hitTestable().evaluate().isNotEmpty) {
          await tester.tap(swatch.first);
          await tester.pumpAndSettle();
          return;
        }
      }
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    fail('appearance-seed-$id could not be scrolled into view');
  }

  Color probeBrand(WidgetTester tester) => tester
      .widget<ColoredBox>(find.byKey(const Key('probe-brand')))
      .color;

  testWidgets('trying two colours moves only the preview, never the app', (
    tester,
  ) async {
    AppearanceBinding().dependencies();
    await pumpWithAppearanceRoute(tester);
    final controller = Get.find<AppearanceController>();

    await openAppearance(tester);
    final appliedBefore = controller.appliedThemeColor;

    // Colour A: preview moves, app does not.
    await tapSwatch(tester, 'amber');
    expect(controller.previewThemeColor, const Color(0xFFD97706));
    expect(controller.appliedThemeColor, appliedBefore);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Colour B: same isolation, and the preview tracks the latest pick.
    await openAppearance(tester);
    await tapSwatch(tester, 'violet');
    expect(controller.previewThemeColor, const Color(0xFF7C3AED));
    expect(controller.appliedThemeColor, appliedBefore);

    // Leaving without applying discards the try entirely.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(controller.previewThemeColor, appliedBefore);
    expect(controller.hasUnsavedChanges, isFalse);
  });

  testWidgets('re-opening starts the preview from the applied theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'appearance.seed_color': 0xFF4F46E5,
      'appearance.preset_id': 'indigo',
      'appearance.brightness_mode': 'light',
    });
    AppearanceBinding().dependencies();
    await pumpWithAppearanceRoute(tester);
    final controller = Get.find<AppearanceController>();
    await tester.pumpAndSettle();

    await openAppearance(tester);

    // Indigo is the applied theme, so the preview opens on it, not on the
    // shipped teal and not on anything a previous visit left behind.
    expect(controller.previewThemeColor, const Color(0xFF4F46E5));
    expect(controller.hasUnsavedChanges, isFalse);
  });

  testWidgets('Apply Theme commits the preview to the whole app and to disk', (
    tester,
  ) async {
    AppearanceBinding().dependencies();
    await pumpWithAppearanceRoute(tester);
    final controller = Get.find<AppearanceController>();

    await openAppearance(tester);
    await tapSwatch(tester, 'red');
    expect(controller.appliedThemeColor, isNot(const Color(0xFFDC2626)));

    await tester.scrollUntilVisible(
      find.byKey(const Key('appearance-apply')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('appearance-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('appearance-apply')));
    await tester.pumpAndSettle();

    expect(controller.appliedThemeColor, const Color(0xFFDC2626));
    expect(controller.hasUnsavedChanges, isFalse);

    // Back on another screen, the new theme is live.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(probeBrand(tester), const Color(0xFFDC2626));

    // And it stuck: a cold read of storage returns the applied colour.
    final stored = await controller.useCases.getPreference();
    expect(stored.seedColor, const Color(0xFFDC2626));
    expect(stored.presetId, 'red');
  });

  testWidgets('the applied theme survives a restart', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'appearance.seed_color': 0xFF9333EA,
      'appearance.preset_id': 'purple',
      'appearance.brightness_mode': 'light',
    });
    AppearanceBinding().dependencies();
    await pumpWithAppearanceRoute(tester);
    await tester.pumpAndSettle();

    expect(probeBrand(tester), const Color(0xFF9333EA));
    expect(
      Get.find<AppearanceController>().appliedThemeColor,
      const Color(0xFF9333EA),
    );
  });
}

/// A second page in the test navigator, showing the applied brand colour so the
/// test can tell the running theme apart from the preview.
class _ThemeProbePage extends StatelessWidget {
  const _ThemeProbePage();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              key: const Key('probe-brand'),
              color: tokens.brand,
              child: const SizedBox(width: 10, height: 10),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Get.toNamed(AppRoutes.appearance),
              child: const Text('Open appearance'),
            ),
          ],
        ),
      ),
    );
  }
}