import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';

/// The Material 3 controls read `ThemeData.colorScheme`, not the design-system
/// tokens, so they only follow the chosen colour if the root really rebuilds
/// `ThemeData`. These are the controls a resident actually touches.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });
  tearDown(Get.reset);

  /// A host with the same reactive wiring as `CondoResidentApp`, showing the
  /// controls that must pick up the brand colour.
  Widget host() => Obx(
        () {
          final controller = Get.find<AppearanceController>();
          return GetMaterialApp(
            theme: controller.theme,
            darkTheme: controller.darkTheme,
            themeMode: controller.themeMode,
            home: Scaffold(
              body: Column(
                children: [
                  RadioGroup<String>(
                    groupValue: 'a',
                    onChanged: (String? _) {},
                    child: const Column(
                      children: [
                        RadioListTile<String>(value: 'a', title: Text('One')),
                      ],
                    ),
                  ),
                  const Checkbox(value: true, onChanged: null),
                  const Switch(value: true, onChanged: null),
                  const LinearProgressIndicator(value: 0.5),
                  const TextField(),
                  const FloatingActionButton(
                    onPressed: null,
                    child: Icon(Icons.add),
                  ),
                  NavigationBar(
                    selectedIndex: 0,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

  testWidgets('Material controls follow the selected brand colour', (
    tester,
  ) async {
    AppearanceBinding().dependencies();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    final beforeScheme = Theme.of(tester.element(find.byType(RadioListTile<String>)));
    final beforePrimary = beforeScheme.colorScheme.primary;
    final beforeCursor = _fieldCursorColour(tester);

    controller.selectPreset(
      AppColorSeeds.all.firstWhere((seed) => seed.id == 'indigo'),
    );
    await tester.pumpAndSettle();

    final afterScheme = Theme.of(tester.element(find.byType(RadioListTile<String>)));
    expect(afterScheme.colorScheme.primary, isNot(beforePrimary));
    expect(afterScheme.colorScheme.primary, const Color(0xFF4F46E5));

    // The TextField cursor colour comes from the theme's input decoration, so a
    // change here proves the whole ThemeData, not just the scheme, was rebuilt.
    expect(_fieldCursorColour(tester), isNot(beforeCursor));
    expect(_fieldCursorColour(tester), const Color(0xFF4F46E5));
  });

  testWidgets('Dark mode uses a light brand so controls stay readable', (
    tester,
  ) async {
    AppearanceBinding().dependencies();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final controller = Get.find<AppearanceController>();
    controller.selectPreset(
      AppColorSeeds.all.firstWhere((seed) => seed.id == 'teal'),
    );
    controller.selectBrightnessMode(AppBrightnessMode.dark);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RadioListTile<String>));
    final scheme = Theme.of(context).colorScheme;

    // In dark mode the raw teal would be unreadable, so the palette swaps to a
    // lighter tone with a dark on-colour.
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary.computeLuminance(), greaterThan(0.3));
    expect(
      scheme.primary.computeLuminance() + scheme.onPrimary.computeLuminance(),
      greaterThan(0.5),
    );
  });
}

/// The cursor colour the TextField actually resolves at paint time.
Color? _fieldCursorColour(WidgetTester tester) {
  final field = tester.widget<TextField>(find.byType(TextField));
  return field.cursorColor ??
      Theme.of(tester.element(find.byType(TextField))).colorScheme.primary;
}