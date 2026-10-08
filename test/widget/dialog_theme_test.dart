import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/core/widgets/app_dialogs.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/controllers/appearance_controller.dart';

/// The dialogs inherit the brand colour from the route theme, so they follow
/// whatever the resident picked without any dialog-level wiring of their own.
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
      // The same reactive wiring as CondoResidentApp.
      Obx(
        () {
          final controller = Get.find<AppearanceController>();
          return GetMaterialApp(
            theme: controller.theme,
            darkTheme: controller.darkTheme,
            themeMode: controller.themeMode,
            home: Builder(
              builder: (context) =>
                  Scaffold(body: Center(child: trigger(context))),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    Get.find<AppearanceController>().selectPreset(
      AppColorSeeds.all.firstWhere((seed) => seed.id == 'pink'),
    );
    await Get.find<AppearanceController>().applyTheme();
    await tester.pumpAndSettle();
  }

  testWidgets('confirm dialog actions use the brand colour', (tester) async {
    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showAppConfirmDialog(
          context,
          title: 'Cancel reservation?',
          message: 'The slot will be released.',
          confirmLabel: 'Yes, cancel',
        ),
        child: const Text('open'),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    const pink = Color(0xFFDB2777);

    // The button takes its fill from the theme's filledButtonTheme, so that is
    // the colour it actually paints with.
    final dialogContext = tester.element(
      find.widgetWithText(FilledButton, 'Yes, cancel'),
    );
    final resolvedFill = Theme.of(dialogContext)
        .filledButtonTheme
        .style
        ?.backgroundColor
        ?.resolve(<WidgetState>{});
    expect(resolvedFill, pink);

    // The cancel action reads from the same scheme, so both accents match.
    expect(Theme.of(dialogContext).colorScheme.primary, pink);
  });

  testWidgets('the date picker selection uses the brand colour', (tester) async {
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

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The picker is a plain Material widget: its colours all come from the
    // route's ColorScheme, which the brand change rebuilt.
    final scheme = Theme.of(tester.element(find.byType(DatePickerDialog)));
    expect(scheme.colorScheme.primary, const Color(0xFFDB2777));
    expect(scheme.colorScheme.onPrimary, Colors.white);
  });

  testWidgets('the summary dialog emphasises with the brand colour', (
    tester,
  ) async {
    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showAppConfirmSummaryDialog(
          context,
          title: 'Confirm Reservation',
          message: 'The slot is reserved in your name.',
          icon: Icons.event_available_rounded,
          confirmLabel: 'Confirm',
          summary: const [
            AppSummaryRow(label: 'Total', value: '\$12.00', emphasis: true),
          ],
          onConfirm: () async => const AppConfirmResult.success(),
        ),
        child: const Text('open'),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final total = tester.widget<Text>(find.text('\$12.00'));
    expect(total.style?.color, const Color(0xFFDB2777));
  });

  testWidgets('a new colour choice reaches an already open app on next dialog', (
    tester,
  ) async {
    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showAppConfirmDialog(
          context,
          title: 'Title',
          message: 'Message',
          confirmLabel: 'Go',
        ),
        child: const Text('open'),
      ),
    );

    // Change the colour while the app is mounted, then open the dialog.
    Get.find<AppearanceController>().selectPreset(
      AppColorSeeds.all.firstWhere((seed) => seed.id == 'orange'),
    );
    await Get.find<AppearanceController>().applyTheme();
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialogContext = tester.element(
      find.widgetWithText(FilledButton, 'Go'),
    );
    final resolvedFill = Theme.of(dialogContext)
        .filledButtonTheme
        .style
        ?.backgroundColor
        ?.resolve(<WidgetState>{});
    expect(resolvedFill, const Color(0xFFEA580C));
  });
}