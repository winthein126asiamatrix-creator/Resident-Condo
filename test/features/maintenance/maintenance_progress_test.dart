import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:test/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:test/features/maintenance/domain/usecases/maintenance_usecases.dart';
import 'package:test/features/maintenance/presentation/controllers/maintenance_controller.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_detail_page.dart';

void main() {
  setUp(Get.reset);
  tearDown(Get.reset);

  test('unknown and null statuses fall back to requested', () {
    expect(MaintenanceStatus.fromApi(null), MaintenanceStatus.submitted);
    expect(
      MaintenanceStatus.fromApi('something_unexpected'),
      MaintenanceStatus.submitted,
    );
  });

  testWidgets('requested marks only the first step current', (tester) async {
    await _pump(tester, MaintenanceStatus.submitted);

    expect(_stepLabel(tester, 0), 'Step 1, current step');
    expect(_stepLabel(tester, 1), 'Step 2, not started');
    expect(_stepLabel(tester, 2), 'Step 3, not started');
    expect(_stepLabel(tester, 3), 'Step 4, not started');
    expect(_completedCount(tester), 0);
  });

  testWidgets('assigned completes requested and activates assigned', (
    tester,
  ) async {
    await _pump(tester, MaintenanceStatus.assigned);

    expect(_stepLabel(tester, 0), 'Done, completed');
    expect(_stepLabel(tester, 1), 'Step 2, current step');
    expect(_stepLabel(tester, 2), 'Step 3, not started');
    expect(_stepLabel(tester, 3), 'Step 4, not started');
    expect(_completedCount(tester), 1);
  });

  testWidgets('in progress completes two steps and activates the third', (
    tester,
  ) async {
    await _pump(tester, MaintenanceStatus.inProgress);

    expect(_stepLabel(tester, 0), 'Done, completed');
    expect(_stepLabel(tester, 1), 'Done, completed');
    expect(_stepLabel(tester, 2), 'Step 3, current step');
    expect(_stepLabel(tester, 3), 'Step 4, not started');
    expect(_completedCount(tester), 2);
  });

  testWidgets('completed keeps the final step active', (tester) async {
    await _pump(tester, MaintenanceStatus.completed);

    expect(_stepLabel(tester, 0), 'Done, completed');
    expect(_stepLabel(tester, 1), 'Done, completed');
    expect(_stepLabel(tester, 2), 'Done, completed');
    expect(_stepLabel(tester, 3), 'Step 4, current step');
    expect(_completedCount(tester), 3);
  });

  testWidgets('cancelled is terminal and never completes happy-path steps', (
    tester,
  ) async {
    await _pump(tester, MaintenanceStatus.cancelled);

    expect(find.text('Cancelled'), findsWidgets);
    expect(_stepLabel(tester, 0), 'Step 1, not started');
    expect(_stepLabel(tester, 1), 'Step 2, not started');
    expect(_stepLabel(tester, 2), 'Step 3, not started');
    expect(_stepLabel(tester, 3), 'Step 4, not started');
    expect(_completedCount(tester), 0);
  });

  testWidgets('history cannot reorder steps or add cancelled as a step', (
    tester,
  ) async {
    await _pump(
      tester,
      MaintenanceStatus.inProgress,
      history: const <MaintenanceProgressEntry>[
        MaintenanceProgressEntry(status: MaintenanceStatus.cancelled),
        MaintenanceProgressEntry(status: MaintenanceStatus.completed),
        MaintenanceProgressEntry(status: MaintenanceStatus.submitted),
      ],
    );

    expect(_stepLabel(tester, 0), 'Done, completed');
    expect(_stepLabel(tester, 1), 'Done, completed');
    expect(_stepLabel(tester, 2), 'Step 3, current step');
    expect(_stepLabel(tester, 3), 'Step 4, not started');
    expect(_completedCount(tester), 2);
    expect(find.text('Cancelled'), findsNothing);
  });
}

/// Reads the state word the shared progress widget attached to one step.
///
/// Reading the [Semantics] property avoids depending on the real semantics
/// tree, where a single list item merges several step labels into one node.
String _stepLabel(WidgetTester tester, int index) {
  final step = find.byKey(Key('progress-step-$index'));
  final ancestor = find.ancestor(
    of: step,
    matching: find.byType(Semantics),
  );
  return tester.widget<Semantics>(ancestor.first).properties.label ?? '';
}

int _completedCount(WidgetTester tester) {
  var count = 0;
  for (var index = 0; index < 4; index++) {
    if (_stepLabel(tester, index) == 'Done, completed') count++;
  }
  return count;
}

Future<void> _pump(
  WidgetTester tester,
  MaintenanceStatus status, {
  List<MaintenanceProgressEntry> history =
      const <MaintenanceProgressEntry>[],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final request = _request(status: status, history: history);
  Get.put<MaintenanceController>(
    MaintenanceController(MaintenanceUseCases(_FakeRepository())),
  );

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) =>
          GetMaterialApp(home: MaintenanceDetailPage(request: request)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Request progress'), 300);
  await tester.pumpAndSettle();
}

MaintenanceRequest _request({
  required MaintenanceStatus status,
  List<MaintenanceProgressEntry> history =
      const <MaintenanceProgressEntry>[],
}) {
  return MaintenanceRequest(
    id: '42',
    title: 'Leaky tap',
    categoryCode: 'plumbing',
    categoryLabel: 'Plumbing',
    description: 'Kitchen sink is dripping.',
    location: 'Kitchen',
    priority: MaintenancePriority.medium,
    status: status,
    createdAt: '2026-11-16T09:00:00Z',
    preferredDate: '2026-11-18',
    preferredTime: '10:00',
    cancelledAt: status == MaintenanceStatus.cancelled
        ? '2026-11-17T10:00:00Z'
        : null,
    progressHistory: history,
  );
}

class _FakeRepository implements MaintenanceRepository {
  @override
  Future<List<MaintenanceCategoryOption>> getCategories({
    bool forceRefresh = false,
  }) async =>
      const <MaintenanceCategoryOption>[];

  @override
  Future<List<MaintenanceCategoryOption>?> getCachedCategories() async => null;

  @override
  Future<MaintenancePageResult?> getCachedRequests(String accountKey) async =>
      null;

  @override
  Future<MaintenanceRequest?> getCachedRequest(
    String accountKey,
    Object id,
  ) async =>
      null;

  @override
  Future<MaintenanceSummary?> getCachedSummary(String accountKey) async => null;

  @override
  Future<MaintenancePageResult> getRequests({
    required String accountKey,
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    bool forceRefresh = false,
  }) async =>
      MaintenancePageResult.empty;

  @override
  Future<MaintenanceRequest> getRequest(
    String accountKey,
    Object id, {
    bool forceRefresh = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<MaintenanceSummary> getSummary(
    String accountKey, {
    bool forceRefresh = false,
  }) async =>
      const MaintenanceSummary();

  @override
  Future<MaintenanceRequest> createRequest({
    required String accountKey,
    required String title,
    required String categoryCode,
    required String description,
    required String location,
    required MaintenancePriority priority,
    required String preferredDate,
    required String preferredTime,
    required String unitId,
    List<MaintenancePhotoUpload> photos = const <MaintenancePhotoUpload>[],
  }) =>
      throw UnimplementedError();

  @override
  Future<MaintenanceCancellation> cancelRequest({
    required String accountKey,
    required String id,
    required String reason,
  }) =>
      throw UnimplementedError();
}
