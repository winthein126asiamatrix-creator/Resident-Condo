import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:test/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:test/features/maintenance/domain/usecases/maintenance_usecases.dart';
import 'package:test/features/maintenance/presentation/controllers/maintenance_controller.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_detail_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  setUp(() {
    Get.reset();
    final session = SessionController()
      ..setSession(
        const AuthUser(
          id: 1,
          name: 'Owner',
          phone: '555',
          role: 'owner',
          unit: AuthUnit(
            id: 5,
            label: 'Tower A - 1205',
            tower: 'Tower A',
            number: '1205',
          ),
        ),
      );
    Get.put<SessionController>(session);
  });

  tearDown(Get.reset);

  test('cancelling adds a cancellation step to the progress history', () async {
    final request = _request();
    final repository = _FakeRepository()..request = request;
    final controller = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(repository)),
    );
    await controller.loadRequests();
    controller.selectRequest(request);

    final cancelled = await controller.cancelRequest(request, 'No longer needed');

    expect(cancelled, isTrue);
    expect(repository.cancelCalls, 1);
    final current = controller.selectedRequest.value!;
    expect(current.status, MaintenanceStatus.cancelled);
    expect(current.cancelledAt, '2026-11-17T10:00:00Z');
    expect(current.progressHistory, hasLength(2));
    expect(current.progressHistory.last.status, MaintenanceStatus.cancelled);
    expect(current.progressHistory.last.note, 'No longer needed');
    expect(
      controller.requests.singleWhere((item) => item.id == '42').status,
      MaintenanceStatus.cancelled,
    );
  });

  test('a failed cancellation leaves the request unchanged', () async {
    final repository = _FakeRepository()
      ..request = _request()
      ..cancelError = const AppException('Too late to cancel.');
    final controller = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(repository)),
    );
    final request = _request();
    controller.selectRequest(request);

    final cancelled = await controller.cancelRequest(request, 'No longer needed');

    expect(cancelled, isFalse);
    expect(controller.selectedRequest.value!.status, MaintenanceStatus.submitted);
    expect(controller.selectedRequest.value!.progressHistory, hasLength(1));
    expect(controller.errorMessage.value, 'Too late to cancel.');
  });

  testWidgets('cancel dialog updates the progress UI without disposing the reason field too early', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final request = _request();
    final repository = _FakeRepository()..request = request;
    Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(repository)),
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(home: MaintenanceDetailPage(request: request)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceDetailPage), findsOneWidget);
    expect(find.text('Request details'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('cancel-maintenance-request')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-maintenance-request')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-maintenance-request')));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this request?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'No longer needed');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel request'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel-maintenance-request')), findsNothing);
    await tester.scrollUntilVisible(find.text('Request progress'), 300);
    await tester.pumpAndSettle();
    expect(find.text(MaintenanceStatus.cancelled.label), findsWidgets);
    expect(repository.cancelCalls, 1);

    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}

MaintenanceRequest _request() {
  return MaintenanceRequest(
    id: '42',
    title: 'Leaky tap',
    categoryCode: 'plumbing',
    categoryLabel: 'Plumbing',
    description: 'Kitchen sink is dripping.',
    location: 'Kitchen',
    priority: MaintenancePriority.medium,
    status: MaintenanceStatus.submitted,
    createdAt: '2026-11-16T09:00:00Z',
    preferredDate: '2026-11-18',
    preferredTime: '10:00',
    progressHistory: const <MaintenanceProgressEntry>[
      MaintenanceProgressEntry(
        status: MaintenanceStatus.submitted,
        createdAt: '2026-11-16T09:00:00Z',
      ),
    ],
  );
}

class _FakeRepository implements MaintenanceRepository {
  MaintenanceRequest? request;
  Object? cancelError;
  int cancelCalls = 0;

  @override
  Future<List<MaintenanceCategoryOption>> getCategories({
    bool forceRefresh = false,
  }) async =>
      const <MaintenanceCategoryOption>[];

  @override
  Future<List<MaintenanceCategoryOption>?> getCachedCategories() async => null;

  @override
  Future<MaintenancePageResult?> getCachedRequests(String accountKey) async => null;

  @override
  Future<MaintenanceRequest?> getCachedRequest(String accountKey, Object id) async =>
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
  }) async {
    final current = request;
    if (current == null) throw StateError('No request configured.');
    return current;
  }

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
  }) async {
    cancelCalls++;
    if (cancelError != null) throw cancelError!;
    return MaintenanceCancellation(
      id: id,
      cancelledAt: '2026-11-17T10:00:00Z',
    );
  }
}
