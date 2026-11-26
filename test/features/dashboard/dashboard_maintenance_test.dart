import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/app/routes/app_routes.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:test/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:test/features/maintenance/domain/usecases/maintenance_usecases.dart';
import 'package:test/features/maintenance/presentation/controllers/maintenance_controller.dart';
import 'package:test/features/dashboard/presentation/widgets/dashboard_maintenance_section.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

void main() {
  setUp(() {
    Get.reset();
    final session = SessionController()
      ..setSession(
        const AuthUser(id: 1, name: 'Owner', phone: '555', role: 'owner'),
      );
    Get.put<SessionController>(session);
  });

  tearDown(Get.reset);

  testWidgets('shows real requests, limited to the latest two, never mock data', (
    tester,
  ) async {
    final repository = _FakeMaintenanceRepository()
      ..items = <MaintenanceRequest>[
        _request('1', 'Real request one', MaintenanceStatus.submitted),
      ];
    final maintenance = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(repository)),
    );
    await maintenance.loadRequests();
    maintenance.requests.assignAll(<MaintenanceRequest>[
      _request('1', 'Real request one', MaintenanceStatus.submitted),
      _request('2', 'Real request two', MaintenanceStatus.inProgress),
      _request('3', 'Real request three', MaintenanceStatus.completed),
    ]);
    await _pumpSection(tester);

    expect(find.text('Real request one'), findsOneWidget);
    expect(find.text('Real request two'), findsOneWidget);
    expect(find.text('Real request three'), findsNothing);
    expect(find.text('Leaking kitchen sink'), findsNothing);
    expect(find.textContaining('MR-1'), findsOneWidget);
    expect(find.text(MaintenanceStatus.submitted.label), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-maintenance-request-3')),
      findsNothing,
    );
    expect(repository.getRequestsCalls, 1);
  });

  testWidgets('empty request list hides the section', (tester) async {
    Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(_FakeMaintenanceRepository())),
    );
    await _pumpSection(tester);

    expect(
      find.byKey(const Key('dashboard-maintenance-section')),
      findsNothing,
    );
    expect(find.byKey(const Key('dashboard-maintenance-card')), findsNothing);
    expect(find.text('No maintenance requests yet'), findsNothing);
    expect(find.text('Leaking kitchen sink'), findsNothing);
  });

  testWidgets('API failure with no requests hides the section', (tester) async {
    final repository = _FakeMaintenanceRepository()..error = true;
    final maintenance = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(repository)),
    );
    await maintenance.loadRequests();
    await _pumpSection(tester);

    expect(maintenance.errorMessage.value, 'No connection.');
    expect(
      find.byKey(const Key('dashboard-maintenance-section')),
      findsNothing,
    );
    expect(find.text('No connection.'), findsNothing);
    expect(find.text('Leaking kitchen sink'), findsNothing);
  });

  testWidgets('visibility reacts when requests are added and removed', (
    tester,
  ) async {
    final maintenance = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(_FakeMaintenanceRepository())),
    );
    await _pumpSection(tester);

    expect(
      find.byKey(const Key('dashboard-maintenance-section')),
      findsNothing,
    );

    maintenance.requests.add(
      _request('1', 'Newly added request', MaintenanceStatus.submitted),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('dashboard-maintenance-section')),
      findsOneWidget,
    );
    expect(find.text('Newly added request'), findsOneWidget);

    maintenance.requests.clear();
    await tester.pump();

    expect(
      find.byKey(const Key('dashboard-maintenance-section')),
      findsNothing,
    );
  });

  testWidgets('cached data is marked on the section', (tester) async {
    final maintenance = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(_FakeMaintenanceRepository())),
    );
    await maintenance.loadRequests();
    maintenance.requests.assignAll(<MaintenanceRequest>[
      _request('1', 'Saved request', MaintenanceStatus.submitted),
    ]);
    maintenance.isShowingCachedData.value = true;
    await _pumpSection(tester);

    expect(find.text('Saved request'), findsOneWidget);
    expect(
      find.text('Showing saved maintenance data. Pull to refresh.'),
      findsOneWidget,
    );
  });

  testWidgets('loading keeps already loaded requests visible', (tester) async {
    final maintenance = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(_FakeMaintenanceRepository())),
    );
    await maintenance.loadRequests();
    maintenance.requests.assignAll(<MaintenanceRequest>[
      _request('1', 'Saved request', MaintenanceStatus.submitted),
    ]);
    maintenance.isLoading.value = true;
    await _pumpSection(tester, settle: false);

    expect(
      find.byKey(const Key('dashboard-maintenance-section')),
      findsOneWidget,
    );
    expect(find.text('Saved request'), findsOneWidget);
  });

  testWidgets('tapping a request opens the maintenance detail page', (
    tester,
  ) async {
    final request = _request('42', 'Tappable request', MaintenanceStatus.submitted);
    final maintenance = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(_FakeMaintenanceRepository())),
    );
    await maintenance.loadRequests();
    maintenance.requests.assignAll(<MaintenanceRequest>[request]);
    await _pumpSection(
      tester,
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: AppRoutes.maintenanceDetail,
          page: () => const _DetailStub(),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('dashboard-maintenance-request-42')));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.maintenanceDetail);
    expect(maintenance.selectedRequest.value?.id, '42');
    expect(find.text('detail:42'), findsOneWidget);
  });

  testWidgets('View all opens the maintenance list tab', (tester) async {
    final maintenance = Get.put<MaintenanceController>(
      MaintenanceController(MaintenanceUseCases(_FakeMaintenanceRepository())),
    );
    await maintenance.loadRequests();
    maintenance.requests.assignAll(<MaintenanceRequest>[
      _request('1', 'Real request one', MaintenanceStatus.submitted),
    ]);
    final selected = <int>[];
    await _pumpSection(tester, onViewAll: () => selected.add(2));

    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(selected, <int>[2]);
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  List<GetPage<dynamic>>? getPages,
  VoidCallback? onViewAll,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => GetMaterialApp(
        getPages: getPages ?? const <GetPage<dynamic>>[],
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardMaintenanceSection(
              onViewAll: onViewAll ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

MaintenanceRequest _request(String id, String title, MaintenanceStatus status) {
  return MaintenanceRequest(
    id: id,
    reference: 'MR-$id',
    title: title,
    categoryCode: 'plumbing',
    categoryLabel: 'Plumbing',
    description: '',
    location: 'Kitchen',
    priority: MaintenancePriority.high,
    status: status,
    createdAt: '2026-11-16T09:00:00Z',
    preferredDate: '2026-11-18',
    preferredTime: '10:00',
  );
}

class _DetailStub extends StatelessWidget {
  const _DetailStub();

  @override
  Widget build(BuildContext context) {
    final request = Get.arguments as MaintenanceRequest;
    return Scaffold(body: Text('detail:${request.id}'));
  }
}

class _FakeMaintenanceRepository implements MaintenanceRepository {
  List<MaintenanceRequest> items = const <MaintenanceRequest>[];
  bool error = false;
  int getRequestsCalls = 0;

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
  }) async {
    getRequestsCalls++;
    if (error) throw const AppException('No connection.');
    return MaintenancePageResult(
      items: items,
      page: 1,
      limit: 20,
      total: items.length,
    );
  }

  @override
  Future<MaintenanceRequest> getRequest(
    String accountKey,
    Object id, {
    bool forceRefresh = false,
  }) async =>
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
