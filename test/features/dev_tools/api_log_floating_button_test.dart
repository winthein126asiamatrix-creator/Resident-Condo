import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/app/routes/app_routes.dart';
import 'package:test/core/network/api_log_store.dart';
import 'package:test/features/dev_tools/presentation/widgets/api_log_floating_button.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(ApiLogStore());
  });

  tearDown(Get.reset);

  Future<void> pumpLogger(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage<dynamic>(
            name: '/',
            page: () =>
                const Scaffold(body: Stack(children: [ApiLogFloatingButton()])),
          ),
          GetPage<dynamic>(
            name: AppRoutes.apiLogs,
            page: () => const Scaffold(body: Text('API LOGS')),
          ),
        ],
      ),
    );
  }

  Future<void> doubleTap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('double tap hides the logger and showOverlay restores it', (
    tester,
  ) async {
    await pumpLogger(tester);
    final logger = find.byIcon(Icons.terminal_rounded);
    expect(logger, findsOneWidget);

    await doubleTap(tester, logger);

    expect(logger, findsNothing);
    expect(Get.currentRoute, '/');
    expect(Get.find<ApiLogStore>().isOverlayVisible.value, isFalse);

    Get.find<ApiLogStore>().showOverlay();
    await tester.pump();

    expect(logger, findsOneWidget);
  });

  testWidgets('single tap still opens the API log viewer', (tester) async {
    await pumpLogger(tester);

    await tester.tap(find.byIcon(Icons.terminal_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('API LOGS'), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.apiLogs);
  });
}
