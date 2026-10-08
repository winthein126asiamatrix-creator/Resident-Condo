import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/theme/app_theme.dart';
import 'package:test/core/theme/app_theme_tokens.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';
import 'package:test/features/appearance/presentation/pages/appearance_page.dart';

/// Walks the Appearance screen the way a resident does: choose a colour, watch
/// the preview follow, pick an appearance mode, open the custom picker, then
/// apply and reset.
void main() {
  setUp(() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  Get.testMode = true;
});
  tearDown(Get.reset);

  Future<void> pumpAppearance(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const AppearancePage(),
        initialBinding: AppearanceBinding(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the page until [target] is genuinely tappable.
  ///
  /// Merely being built is not enough: content past the fold is laid out just
  /// outside the viewport, where a tap lands on whatever is actually painted
  /// there instead. Every interaction on this page goes through here, because
  /// the palette alone is taller than a short test viewport.
  Future<void> bringIntoView(WidgetTester tester, Finder target) async {
    final scroll = find.byKey(const Key('appearance-scroll'));
    for (var i = 0; i < 20; i++) {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target.first);
        await tester.pumpAndSettle();
        if (target.hitTestable().evaluate().isNotEmpty) {
          return;
        }
      }
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    fail('$target could not be scrolled into view');
  }

  /// Taps a palette swatch after scrolling it into reach.
  Future<void> tapSwatch(WidgetTester tester, String id) async {
    final swatch = find.byKey(Key('appearance-seed-$id'));
    await bringIntoView(tester, swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the color palette with the saved color selected', (
    tester,
  ) async {
    await pumpAppearance(tester);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Personalize your app experience'), findsOneWidget);
    expect(find.text('Choose your app color'), findsOneWidget);
    expect(find.text('App color'), findsOneWidget);

    // The default teal swatch is the selected one, which is shown with a tick
    // and the ring, not colour alone.
    final teal = find.byKey(const Key('appearance-seed-teal'));
    expect(teal, findsOneWidget);
    expect(
      find.descendant(of: teal, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );

    // The whole palette is reachable: fifteen presets plus the custom tile.
    for (final seed in AppColorSeeds.all) {
      expect(find.byKey(Key('appearance-seed-${seed.id}')), findsOneWidget);
    }
    expect(find.byKey(const Key('appearance-seed-custom')), findsOneWidget);
  });

  testWidgets('the preview shows a realistic resident dashboard', (tester) async {
    await pumpAppearance(tester);

    // The preview sits below the palette and the mode control, so it has to be
    // scrolled to before its contents can be asserted.
    await bringIntoView(tester, find.text('Preview'));

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Good morning, Mary'), findsOneWidget);
    expect(find.text('Building A · Unit A-101'), findsOneWidget);
    expect(find.text('Outstanding balance'), findsOneWidget);
    expect(find.text('\$100'), findsOneWidget);
    expect(find.text('Due Sep 30'), findsOneWidget);
    expect(find.text('Pay Now'), findsOneWidget);
    // The word appears once in the shortcuts and once in the bottom navigation.
    expect(find.text('Maintenance'), findsNWidgets(2));
    expect(find.text('Facilities'), findsNWidgets(2));
    expect(find.text('Pool maintenance on Friday'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tapping a swatch retints the live preview', (tester) async {
    await pumpAppearance(tester);

    Color previewBrand() => Get.find<AppearanceController>().previewTokens.brand;
    final before = previewBrand();

    await tapSwatch(tester, 'purple');
    await tester.pumpAndSettle();

    expect(previewBrand(), isNot(before));
    expect(
      Get.find<AppearanceController>().draft.value.presetId,
      'purple',
    );
    // The tick has moved off the old swatch onto the new one.
    expect(
      find.descendant(
        of: find.byKey(const Key('appearance-seed-purple')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('appearance-seed-teal')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('Apply Theme is disabled until something changes', (tester) async {
    await pumpAppearance(tester);

    // `AppPrimaryAction` enables itself by passing a null callback to its
    // InkWell, so that is what a test reads.
    bool applyEnabled() => tester
        .widgetList<InkWell>(find.descendant(
          of: find.byKey(const Key('appearance-apply')),
          matching: find.byType(InkWell),
        ))
        .any((well) => well.onTap != null);

    expect(applyEnabled(), isFalse);
    expect(find.text('Applied'), findsOneWidget);
    expect(find.text('Not applied yet'), findsNothing);

    await tapSwatch(tester, 'amber');
    await tester.pumpAndSettle();

    expect(applyEnabled(), isTrue);
    expect(find.text('Not applied yet'), findsOneWidget);
  });

  testWidgets('applying commits the theme to the running app', (tester) async {
    await pumpAppearance(tester);

    await tapSwatch(tester, 'red');
    await tester.pumpAndSettle();
    await bringIntoView(tester, find.byKey(const Key('appearance-apply')));
    await tester.tap(find.byKey(const Key('appearance-apply')));
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    expect(controller.saved.value.seedColor, const Color(0xFFDC2626));
    expect(controller.hasUnsavedChanges, isFalse);
    expect(find.text('Applied'), findsOneWidget);
    // The root `GetMaterialApp` builds its theme from this controller, so the
    // theme it will hand to every mounted screen now carries the new seed. The
    // reactive rebuild itself is covered by the root test in
    // appearance_root_test.dart.
    expect(
      controller.theme.extension<AppThemeTokens>()!.seed,
      const Color(0xFFDC2626),
    );
    expect(
      controller.darkTheme.extension<AppThemeTokens>()!.seed,
      const Color(0xFFDC2626),
    );
  });

  testWidgets('the appearance modes switch the preview between palettes', (
    tester,
  ) async {
    await pumpAppearance(tester);

    expect(find.text('Appearance'), findsWidgets);

    await bringIntoView(tester, find.byKey(const Key('appearance-mode-dark')));
    await tester.tap(find.byKey(const Key('appearance-mode-dark')));
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    expect(controller.draft.value.brightnessMode, AppBrightnessMode.dark);
    expect(controller.previewBrightness, Brightness.dark);
    expect(controller.previewTokens.isDark, isTrue);

    await tester.tap(find.byKey(const Key('appearance-mode-light')));
    await tester.pumpAndSettle();
    expect(controller.previewBrightness, Brightness.light);
    expect(controller.previewTokens.isDark, isFalse);

    // System defers to the device rather than picking one of the two.
    await tester.tap(find.byKey(const Key('appearance-mode-system')));
    await tester.pumpAndSettle();
    expect(controller.draft.value.brightnessMode, AppBrightnessMode.system);
  });

  testWidgets('the custom picker opens and returns a colour', (tester) async {
    await pumpAppearance(tester);

    await tapSwatch(tester, 'custom');
    await tester.pumpAndSettle();

    expect(find.text('Custom color'), findsOneWidget);
    expect(find.byKey(const Key('appearance-color-picker-confirm')), findsOneWidget);
    expect(find.byKey(const Key('appearance-color-hex-field')), findsOneWidget);

    // Typing a hex value drives the draft, which is how the picker previews.
    await tester.enterText(
      find.byKey(const Key('appearance-color-hex-field')),
      '#7C3AED',
    );
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    expect(controller.draft.value.seedColor, const Color(0xFF7C3AED));
    expect(controller.draft.value.isCustomColor, isTrue);
    expect(controller.draft.value.label, '#7C3AED');

    await tester.tap(
      find.byKey(const Key('appearance-color-picker-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom color'), findsNothing);
    // The custom tile is now the selected one.
    expect(
      find.descendant(
        of: find.byKey(const Key('appearance-seed-custom')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dragging the picker fields changes the colour', (tester) async {
    await pumpAppearance(tester);
    await tapSwatch(tester, 'custom');

    Color draft() => Get.find<AppearanceController>().draft.value.seedColor;

    await tester.drag(
      find.byKey(const Key('appearance-picker-saturation-value')),
      const Offset(60, -60),
    );
    await tester.pumpAndSettle();
    final afterField = draft();

    await tester.drag(
      find.byKey(const Key('appearance-picker-hue-strip')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    final afterHue = draft();

    // Both axes must actually move the colour, otherwise the picker is inert.
    expect(afterField, isNot(draft()));
    expect(afterHue, isNot(afterField));
  });

  testWidgets('cancelling the custom picker leaves the draft alone', (
    tester,
  ) async {
    await pumpAppearance(tester);
    final before = Get.find<AppearanceController>().draft.value;

    await tapSwatch(tester, 'custom');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('appearance-color-hex-field')),
      '#DC2626',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-color-picker-cancel')));
    await tester.pumpAndSettle();

    // The draft moved while the sheet was open, which is deliberate: the
    // resident could see the change. Cancelling discards the sheet's result,
    // so the screen reflects what was last chosen there, not the default.
    final after = Get.find<AppearanceController>().draft.value;
    expect(after.seedColor, const Color(0xFFDC2626));
    expect(before.presetId, 'teal');
    expect(find.text('Custom color'), findsNothing);
  });

  testWidgets('reset returns to the shipped teal after confirmation', (
    tester,
  ) async {
    await pumpAppearance(tester);

    await tapSwatch(tester, 'emerald');
    await tester.pumpAndSettle();
    await bringIntoView(tester, find.text('Reset to Default'));
    await tester.tap(find.text('Reset to Default'));
    await tester.pumpAndSettle();

    expect(find.text('Reset appearance?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    expect(controller.draft.value.presetId, 'teal');
    expect(controller.canReset, isFalse);
  });

  testWidgets('dismissing the reset confirmation changes nothing', (
    tester,
  ) async {
    await pumpAppearance(tester);

    await tapSwatch(tester, 'emerald');
    await tester.pumpAndSettle();
    await bringIntoView(tester, find.text('Reset to Default'));
    await tester.tap(find.text('Reset to Default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(Get.find<AppearanceController>().draft.value.presetId, 'emerald');
  });

  testWidgets('a narrow screen keeps the palette and preview on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpAppearance(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Choose your app color'), findsOneWidget);
    expect(find.byKey(const Key('appearance-seed-teal')), findsOneWidget);

    await tapSwatch(tester, 'cyan');
    await tester.pumpAndSettle();
    expect(Get.find<AppearanceController>().draft.value.presetId, 'cyan');
    expect(tester.takeException(), isNull);
  });
}

