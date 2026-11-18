import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:test/features/auth/data/models/auth_user.dart';
import 'package:test/features/config/domain/entities/condo_config.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';
import 'package:test/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:test/features/maintenance/domain/usecases/maintenance_usecases.dart';
import 'package:test/features/maintenance/presentation/controllers/maintenance_controller.dart';
import 'package:test/features/maintenance/presentation/pages/maintenance_detail_page.dart';
import 'package:test/features/session/presentation/controllers/session_controller.dart';

String _wireDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _wireTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

MaintenanceBookingConfig _config({
  int? maxAdvanceDays = 14,
  int? minAdvanceHours = 4,
  int? cancelBeforeHours = 2,
}) => MaintenanceBookingConfig(
  maxAdvanceDays: maxAdvanceDays,
  minAdvanceHours: minAdvanceHours,
  cancelBeforeHours: cancelBeforeHours,
);

MaintenanceRequest _request({
  required DateTime appointment,
  MaintenanceStatus status = MaintenanceStatus.submitted,
}) => MaintenanceRequest(
  id: '42',
  title: 'Leaky tap',
  categoryCode: 'plumbing',
  categoryLabel: 'Plumbing',
  description: 'Kitchen tap is leaking',
  location: 'Kitchen',
  priority: MaintenancePriority.medium,
  status: status,
  createdAt: DateTime.now().toIso8601String(),
  preferredDate: _wireDate(appointment),
  preferredTime: _wireTime(appointment),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('config parsing and rules', () {
    test('parses all three booking values from CondoConfig', () {
      final config = CondoConfig.fromJson(<String, dynamic>{
        'features': <String, bool>{},
        'booking': <String, dynamic>{
          'maintenance': <String, dynamic>{
            'max_advance_days': 14,
            'min_advance_hours': 4,
            'cancel_before_hours': 2,
          },
        },
      });
      final maintenance = config.booking?.maintenance;

      expect(maintenance?.maxAdvanceDays, 14);
      expect(maintenance?.minAdvanceHours, 4);
      expect(maintenance?.cancelBeforeHours, 2);
    });

    test('handles missing and invalid values without throwing', () {
      final maintenance = MaintenanceBookingConfig.fromJson(<String, dynamic>{
        'max_advance_days': 'not-a-number',
      });

      expect(maintenance.maxAdvanceDays, isNull);
      expect(maintenance.minAdvanceHours, isNull);
      expect(maintenance.cancelBeforeHours, isNull);
      expect(
        maintenance.validateAppointment(
          DateTime(2026, 11, 18, 10),
          DateTime(2026, 11, 18, 11),
        ),
        isNull,
      );
      expect(
        maintenance.canCancelAppointment(
          DateTime(2026, 11, 18, 10),
          DateTime(2026, 11, 18, 10, 30),
        ),
        isTrue,
      );
    });

    test('validates complete date/time values and boundaries', () {
      final config = _config();
      final now = DateTime(2026, 11, 18, 10, 0);

      expect(
        config.validateAppointment(now, DateTime(2026, 12, 3, 9)),
        isNotNull,
      );
      expect(config.validateAppointment(now, DateTime(2026, 12, 2, 9)), isNull);
      expect(
        config.validateAppointment(now, DateTime(2026, 11, 18, 13, 59)),
        isNotNull,
      );
      expect(
        config.validateAppointment(now, DateTime(2026, 11, 18, 14, 0)),
        isNull,
      );
      expect(
        MaintenanceBookingConfig.parseAppointment('2026-02-30', '10:00'),
        isNull,
      );
      expect(
        MaintenanceBookingConfig.parseAppointment('2026-11-18', '25:00'),
        isNull,
      );
    });

    test(
      'cancellation respects the configured window and started requests',
      () {
        final config = _config();
        final now = DateTime(2026, 11, 18, 10, 0);

        expect(
          config.canCancelAppointment(now, DateTime(2026, 11, 18, 12, 0)),
          isTrue,
        );
        expect(
          config.canCancelAppointment(now, DateTime(2026, 11, 18, 11, 59)),
          isFalse,
        );
        expect(
          config.canCancelAppointment(now, DateTime(2026, 11, 18, 9, 59)),
          isFalse,
        );
      },
    );
  });

  group('controller enforcement', () {
    test('rejects submissions outside the booking window', () async {
      final repository = _FakeRepository();
      final controller = MaintenanceController(
        MaintenanceUseCases(repository),
        bookingConfig: _config(),
      );
      final now = DateTime.now();

      final tooSoon = await _submit(
        controller,
        now.add(const Duration(hours: 2)),
      );
      expect(tooSoon, isNull);
      expect(controller.errorMessage.value, isNotNull);
      expect(repository.createCalls, 0);

      final tooFar = await _submit(
        controller,
        now.add(const Duration(days: 20)),
      );
      expect(tooFar, isNull);
      expect(repository.createCalls, 0);

      final valid = await _submit(
        controller,
        now.add(const Duration(hours: 5)),
      );
      expect(valid, isNotNull);
      expect(repository.createCalls, 1);
      expect(controller.errorMessage.value, isNull);
    });

    test(
      'hides and revalidates cancellation inside the configured window',
      () async {
        final repository = _FakeRepository();
        final controller = MaintenanceController(
          MaintenanceUseCases(repository),
          bookingConfig: _config(),
        );
        final now = DateTime.now();

        final tooSoon = _request(
          appointment: now.add(const Duration(hours: 1)),
        );
        expect(controller.canCancelRequest(tooSoon), isFalse);
        expect(await controller.cancelRequest(tooSoon, 'Not needed'), isFalse);
        expect(repository.cancelCalls, 0);

        final started = _request(
          appointment: now.subtract(const Duration(hours: 1)),
        );
        expect(controller.canCancelRequest(started), isFalse);

        final completed = _request(
          appointment: now.add(const Duration(hours: 3)),
          status: MaintenanceStatus.completed,
        );
        expect(controller.canCancelRequest(completed), isFalse);

        final eligible = _request(
          appointment: now.add(const Duration(hours: 3)),
        );
        expect(controller.canCancelRequest(eligible), isTrue);
        expect(await controller.cancelRequest(eligible, 'Not needed'), isTrue);
        expect(repository.cancelCalls, 1);
      },
    );

    test('without config the previous behavior is preserved', () async {
      final repository = _FakeRepository();
      final controller = MaintenanceController(MaintenanceUseCases(repository));
      final now = DateTime.now();

      expect(
        await _submit(controller, now.add(const Duration(hours: 1))),
        isNotNull,
      );
      final started = _request(
        appointment: now.subtract(const Duration(hours: 1)),
      );
      expect(controller.canCancelRequest(started), isTrue);
    });

    testWidgets('detail page hides cancel inside the cancellation window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final request = _request(
        appointment: DateTime.now().add(const Duration(hours: 1)),
      );
      Get.put<MaintenanceController>(
        MaintenanceController(
          MaintenanceUseCases(_FakeRepository()),
          bookingConfig: _config(),
        ),
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              GetMaterialApp(home: MaintenanceDetailPage(request: request)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancel-maintenance-request')), findsNothing);
    });

    testWidgets('detail page shows cancel outside the cancellation window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final request = _request(
        appointment: DateTime.now().add(const Duration(hours: 3)),
      );
      Get.put<MaintenanceController>(
        MaintenanceController(
          MaintenanceUseCases(_FakeRepository()),
          bookingConfig: _config(),
        ),
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              GetMaterialApp(home: MaintenanceDetailPage(request: request)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('cancel-maintenance-request')),
        300,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cancel-maintenance-request')),
        findsOneWidget,
      );
    });
  });
}

Future<MaintenanceRequest?> _submit(
  MaintenanceController controller,
  DateTime appointment,
) => controller.createRequest(
  title: 'Leaky tap',
  categoryCode: 'plumbing',
  description: 'Kitchen tap is leaking',
  location: 'Kitchen',
  priority: MaintenancePriority.medium,
  preferredDate: _wireDate(appointment),
  preferredTime: _wireTime(appointment),
  unitId: '5',
);

class _FakeRepository implements MaintenanceRepository {
  int createCalls = 0;
  int cancelCalls = 0;
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
  }) async =>
      _request(appointment: DateTime.now().add(const Duration(hours: 3)));

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
  }) async {
    createCalls++;
    return MaintenanceRequest(
      id: '99',
      title: title,
      categoryCode: categoryCode,
      categoryLabel: 'Plumbing',
      description: description,
      location: location,
      priority: priority,
      status: MaintenanceStatus.submitted,
      createdAt: DateTime.now().toIso8601String(),
      preferredDate: preferredDate,
      preferredTime: preferredTime,
    );
  }

  @override
  Future<MaintenanceCancellation> cancelRequest({
    required String accountKey,
    required String id,
    required String reason,
  }) async {
    cancelCalls++;
    return const MaintenanceCancellation(id: '42');
  }
}
