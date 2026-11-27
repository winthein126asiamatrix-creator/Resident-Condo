import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/core/utils/app_dates.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:test/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:test/features/maintenance/domain/usecases/maintenance_usecases.dart';
import 'package:test/features/maintenance/presentation/controllers/maintenance_controller.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_detail_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

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

  test('createdAtDisplay preserves the backend date and time', () {
    final request = _request(
      status: MaintenanceStatus.submitted,
      createdAt: '2026-11-16T09:30:00',
    );

    expect(request.createdAtDisplay, 'Nov 16, 2026 · 9:30 AM');
  });

  test('an invalid created_at is handled gracefully', () {
    final request = _request(
      status: MaintenanceStatus.submitted,
      createdAt: 'not-a-date',
    );

    expect(request.createdAtDisplay, '');
  });

  test('progress entries read the API "at" timestamp', () {
    final entry = MaintenanceProgressEntry.fromJson(const <String, dynamic>{
      'status': 'assigned',
      'at': '2026-11-25T14:40:06',
      'comment': null,
      'by': 'H1',
    });

    expect(entry.status, MaintenanceStatus.assigned);
    expect(entry.actor, 'H1');
    expect(entry.occurredAtDisplay, 'Nov 25, 2026 · 2:40 PM');
  });

  test('progress entries without a timestamp have no display time', () {
    final entry = MaintenanceProgressEntry.fromJson(const <String, dynamic>{
      'status': 'completed',
      'at': null,
    });

    expect(entry.occurredAtDisplay, isNull);
  });

  test('list workflow timestamps are parsed', () {
    final request = MaintenanceRequestModelData.fromJson(
      const <String, dynamic>{
        'id': 7,
        'status': 'assigned',
        'created_at': '2026-11-25T18:20:14Z',
        'assigned_at': '2026-11-25T18:20:46Z',
        'in_progress_at': null,
        'completed_at': null,
        'cancelled_at': null,
      },
    );

    expect(request.assignedAt, '2026-11-25T18:20:46Z');
    expect(request.inProgressAt, isNull);
    expect(
      request.statusTimestampDisplay(MaintenanceStatus.assigned),
      isNotNull,
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

  testWidgets('submitted step shows the backend submission date and time', (
    tester,
  ) async {
    await _pump(
      tester,
      MaintenanceStatus.submitted,
      createdAt: '2026-11-16T09:30:00',
    );

    // Shown both in the Request information row and on the Submitted step.
    expect(find.text('Nov 16, 2026 · 9:30 AM'), findsNWidgets(2));
  });

  testWidgets('invalid submission timestamp does not crash the timeline', (
    tester,
  ) async {
    await _pump(tester, MaintenanceStatus.submitted, createdAt: 'not-a-date');

    expect(find.text('Request progress'), findsOneWidget);
    expect(find.text('Submitted'), findsWidgets);
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

  testWidgets('each status shows the date and time from progress history', (
    tester,
  ) async {
    await _pump(
      tester,
      MaintenanceStatus.completed,
      history: const <MaintenanceProgressEntry>[
        MaintenanceProgressEntry(
          status: MaintenanceStatus.submitted,
          createdAt: '2026-11-25T14:39:37',
        ),
        MaintenanceProgressEntry(
          status: MaintenanceStatus.assigned,
          createdAt: '2026-11-25T14:40:06',
        ),
        MaintenanceProgressEntry(
          status: MaintenanceStatus.inProgress,
          createdAt: '2026-11-25T14:41:33',
        ),
        MaintenanceProgressEntry(
          status: MaintenanceStatus.completed,
          createdAt: '2026-11-25T14:42:53',
        ),
      ],
    );

    expect(find.text('Nov 25, 2026 · 2:39 PM'), findsOneWidget);
    expect(find.text('Nov 25, 2026 · 2:40 PM'), findsOneWidget);
    expect(find.text('Nov 25, 2026 · 2:41 PM'), findsOneWidget);
    expect(find.text('Nov 25, 2026 · 2:42 PM'), findsOneWidget);
  });

  testWidgets('list workflow timestamps fill the timeline without history', (
    tester,
  ) async {
    await _pump(
      tester,
      MaintenanceStatus.completed,
      createdAt: '2026-11-25T18:10:14',
      assignedAt: '2026-11-25T18:20:46',
      inProgressAt: '2026-11-25T18:21:00',
      completedAt: '2026-11-25T18:22:00',
    );

    // The Request information row and the Submitted step share created_at.
    expect(find.text('Nov 25, 2026 · 6:10 PM'), findsNWidgets(2));
    expect(find.text('Nov 25, 2026 · 6:20 PM'), findsOneWidget);
    expect(find.text('Nov 25, 2026 · 6:21 PM'), findsOneWidget);
    expect(find.text('Nov 25, 2026 · 6:22 PM'), findsOneWidget);
  });

  testWidgets(
    'a detail response without assigned_at keeps the list timestamp',
    (tester) async {
      // Mirrors the List API item for MNT-2026-0007, including `assigned_at`.
      final listRequest = MaintenancePageResult.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'reference': 'MNT-2026-0007',
            'title': 'QQQQQ',
            'description': 'wewtrey',
            'category': <String, dynamic>{
              'id': 1,
              'code': 'plumbing',
              'label': 'Plumbing',
            },
            'priority': 'medium',
            'status': 'assigned',
            'location': 'bedroom',
            'unit': <String, dynamic>{'id': 1, 'label': 'Tower A · Unit 102'},
            'technician': <String, dynamic>{'id': 7, 'name': 'H1'},
            'created_at': '2026-11-25T18:10:14Z',
            'assigned_at': '2026-11-25T18:20:46Z',
            'in_progress_at': null,
            'completed_at': null,
            'cancelled_at': null,
            'preferred_date': '2026-11-28',
            'preferred_time': '10:00',
            'photo_count': 0,
          },
        ],
        'page': 1,
        'limit': 20,
        'total': 1,
      }).items.single;
      // The detail endpoint can omit assigned_at; the list snapshot must win.
      final detail = _request(
        status: MaintenanceStatus.assigned,
        createdAt: '2026-11-25T18:10:14Z',
      );

      await _pump(
        tester,
        MaintenanceStatus.assigned,
        request: listRequest,
        detail: detail,
      );

      final assigned = AppDates.formatDateTime(
        DateTime.parse('2026-11-25T18:20:46Z').toLocal(),
      );
      expect(find.text(assigned), findsOneWidget);
    },
  );

  testWidgets('statuses without a history timestamp show no date', (
    tester,
  ) async {
    await _pump(
      tester,
      MaintenanceStatus.completed,
      createdAt: '',
      history: const <MaintenanceProgressEntry>[
        MaintenanceProgressEntry(status: MaintenanceStatus.submitted),
        MaintenanceProgressEntry(status: MaintenanceStatus.assigned),
        MaintenanceProgressEntry(status: MaintenanceStatus.inProgress),
        MaintenanceProgressEntry(status: MaintenanceStatus.completed),
      ],
    );

    expect(find.text('Request progress'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data?.contains('·') ?? false),
      ),
      findsNothing,
    );
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
  final ancestor = find.ancestor(of: step, matching: find.byType(Semantics));
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
  List<MaintenanceProgressEntry> history = const <MaintenanceProgressEntry>[],
  String createdAt = '2026-11-16T09:00:00Z',
  String? assignedAt,
  String? inProgressAt,
  String? completedAt,
  MaintenanceRequest? request,
  MaintenanceRequest? detail,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final listRequest =
      request ??
      _request(
        status: status,
        history: history,
        createdAt: createdAt,
        assignedAt: assignedAt,
        inProgressAt: inProgressAt,
        completedAt: completedAt,
      );
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
  Get.put<MaintenanceController>(
    MaintenanceController(
      MaintenanceUseCases(_FakeRepository(detail: detail ?? listRequest)),
    ),
  );

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) =>
          GetMaterialApp(home: MaintenanceDetailPage(request: listRequest)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Request progress'), 300);
  await tester.pumpAndSettle();
}

MaintenanceRequest _request({
  required MaintenanceStatus status,
  List<MaintenanceProgressEntry> history = const <MaintenanceProgressEntry>[],
  String createdAt = '2026-11-16T09:00:00Z',
  String? assignedAt,
  String? inProgressAt,
  String? completedAt,
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
    createdAt: createdAt,
    preferredDate: '2026-11-18',
    preferredTime: '10:00',
    assignedAt: assignedAt,
    inProgressAt: inProgressAt,
    completedAt: completedAt,
    cancelledAt: status == MaintenanceStatus.cancelled
        ? '2026-11-17T10:00:00Z'
        : null,
    progressHistory: history,
  );
}

class _FakeRepository implements MaintenanceRepository {
  _FakeRepository({this.detail});

  final MaintenanceRequest? detail;

  @override
  Future<List<MaintenanceCategoryOption>> getCategories({
    bool forceRefresh = false,
  }) async => const <MaintenanceCategoryOption>[];

  @override
  Future<List<MaintenanceCategoryOption>?> getCachedCategories() async => null;

  @override
  Future<MaintenancePageResult?> getCachedRequests(String accountKey) async =>
      null;

  @override
  Future<MaintenanceRequest?> getCachedRequest(
    String accountKey,
    Object id,
  ) async => null;

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
  }) async => MaintenancePageResult.empty;

  @override
  Future<MaintenanceRequest> getRequest(
    String accountKey,
    Object id, {
    bool forceRefresh = false,
  }) async {
    final request = detail;
    if (request == null) throw UnimplementedError();
    return request;
  }

  @override
  Future<MaintenanceSummary> getSummary(
    String accountKey, {
    bool forceRefresh = false,
  }) async => const MaintenanceSummary();

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
  }) => throw UnimplementedError();

  @override
  Future<MaintenanceCancellation> cancelRequest({
    required String accountKey,
    required String id,
    required String reason,
  }) => throw UnimplementedError();
}
