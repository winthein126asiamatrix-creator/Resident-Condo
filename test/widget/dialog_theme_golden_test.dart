import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/core/widgets/app_dialogs.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';

/// Reference images of the app's dialogs, so the brand colour reaching them
/// can be reviewed as a picture.
///
/// Regenerate with:
/// `flutter test test/widget/dialog_theme_golden_test.dart --update-goldens`
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });
  tearDown(Get.reset);

  Future<void> pumpHost(
    WidgetTester tester, {
    required Widget Function(BuildContext context) trigger,
  }) async {
    AppearanceBinding().dependencies();
    await tester.pumpWidget(
      // The same reactive wiring as CondoResidentApp: the dialogs inherit the
      // theme from the route they are pushed onto, so this is what decides
      // whether they follow the chosen colour.
      Obx(
        () {
          final controller = Get.find<AppearanceController>();
          return GetMaterialApp(
            theme: controller.theme,
            darkTheme: controller.darkTheme,
            themeMode: controller.themeMode,
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (context) =>
                  Scaffold(body: Center(child: trigger(context))),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('confirm dialog', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showAppConfirmDialog(
          context,
          title: 'Cancel reservation?',
          message: 'The gym slot will be released for other residents.',
          confirmLabel: 'Cancel reservation',
        ),
        child: const Text('open'),
      ),
    );

    // Pick a colour the same way the Appearance screen does.
    Get.find<AppearanceController>().selectPreset(
      AppColorSeeds.all.firstWhere((seed) => seed.id == 'indigo'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('dialog-confirm.png'),
    );
  });

  testWidgets('summary dialog', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showAppConfirmSummaryDialog(
          context,
          title: 'Confirm Reservation',
          message: 'The slot is reserved in your name.',
          icon: Icons.event_available_rounded,
          confirmLabel: 'Confirm Reservation',
          summary: const [
            AppSummaryRow(label: 'Facility', value: 'Gym'),
            AppSummaryRow(label: 'Time', value: '9:00 AM – 10:00 AM'),
            AppSummaryRow(label: 'Total', value: '\$12.00', emphasis: true),
          ],
          onConfirm: () async => const AppConfirmResult.success(),
        ),
        child: const Text('open'),
      ),
    );

    Get.find<AppearanceController>().selectPreset(AppColorSeeds.all.firstWhere((seed) => seed.id == 'indigo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('dialog-summary.png'),
    );
  });

  testWidgets('date picker', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showDatePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime(2027),
          initialDate: DateTime(2026, 9, 30),
        ),
        child: const Text('open'),
      ),
    );

    Get.find<AppearanceController>().selectPreset(AppColorSeeds.all.firstWhere((seed) => seed.id == 'indigo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('dialog-date.png'),
    );
  });

  testWidgets('time picker', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 9, minute: 30),
        ),
        child: const Text('open'),
      ),
    );

    Get.find<AppearanceController>().selectPreset(AppColorSeeds.all.firstWhere((seed) => seed.id == 'indigo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('dialog-time.png'),
    );
  });
}

