import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test/app/theme/app_theme.dart';
import 'package:test/features/auth/presentation/bindings/auth_binding.dart';
import 'package:test/features/auth/presentation/pages/login_page.dart';

/// Reference images of the login screen, for reviewing the layout as a picture
/// rather than as assertions.
///
/// Regenerate with:
/// `flutter test test/features/auth/login_golden_test.dart --update-goldens`
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });
  tearDown(Get.reset);

  Future<void> capture(
    WidgetTester tester,
    String name, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const LoginPage(onSignedIn: _noop),
        initialBinding: AuthBinding(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('login-$name.png'),
    );
  }

  testWidgets('default', (tester) => capture(tester, 'default'));

  testWidgets('small screen', (tester) =>
      capture(tester, 'small', size: const Size(320, 568)));

  testWidgets('password revealed', (tester) async {
    await capture(tester, 'revealed');
    await tester.tap(find.byKey(const Key('login-password-toggle')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('login-revealed.png'),
    );
  });
}

void _noop() {}