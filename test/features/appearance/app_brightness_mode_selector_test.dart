import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/appearance/domain/entities/app_color_seed.dart';
import 'package:test/features/appearance/presentation/widgets/app_brightness_mode_selector.dart';

void main() {
  // The card widths below match the device where the selector first
  // overflowed: three 128.3px cards on a 447px wide screen.
  Future<void> pumpSelector(WidgetTester tester, {double textScale = 1}) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(447 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21),
              child: AppBrightnessModeSelector(
                value: AppBrightnessMode.light,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the three options fit their cards without overflowing', (
    tester,
  ) async {
    // 1.15 is the text scale the affected phone reported (13.sp → 14.9).
    await pumpSelector(tester, textScale: 1.15);

    expect(tester.takeException(), isNull);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('larger text grows the row instead of overflowing it', (
    tester,
  ) async {
    await pumpSelector(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);

    // All three cards still share one height.
    final heights = <double>{
      for (final mode in AppBrightnessMode.values)
        tester.getSize(find.byKey(Key('appearance-mode-${mode.id}'))).height,
    };
    expect(heights, hasLength(1));
  });
}
