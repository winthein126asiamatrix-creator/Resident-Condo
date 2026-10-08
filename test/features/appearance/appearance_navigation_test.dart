import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/bindings/app_binding.dart';
import 'package:test/app/routes/app_routes.dart';
import 'package:test/app/theme/app_theme.dart';
import 'package:test/features/appearance/presentation/bindings/appearance_binding.dart';
import 'package:test/features/appearance/presentation/pages/appearance_page.dart';
import 'package:test/features/dashboard/presentation/pages/main_shell_page.dart';

/// The Appearance screen reached the way a resident reaches it: Profile, then
/// the preference row.
void main() {
  setUp(() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  Get.testMode = true;
});
  tearDown(Get.reset);

  testWidgets('Profile opens Appearance', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        
        // The app's own graph, so the Profile tab and its controllers resolve.
        initialBinding: AppBinding(),
        // Mounted as `home` rather than as an initial route: the Profile tab is
        // what this test drives, and GetX's route middleware needs the full page
        // list to resolve an initial route by name.
        home: const MainShellPage(),
        getPages: [
          GetPage<dynamic>(
            name: AppRoutes.appearance,
            page: () => const AppearancePage(),
            binding: AppearanceBinding(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The Profile tab is the last bottom navigation destination.
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    final row = find.text('App appearance');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('profile-scroll')),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pumpAndSettle();

    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text('Personalize your app experience'), findsOneWidget);
    expect(find.text('Choose your app color'), findsOneWidget);
  });
}

