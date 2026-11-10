import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/core/network/api_exception.dart';
import 'package:test/features/services/data/datasources/condo_service_local_data_source.dart';
import 'package:test/features/services/domain/entities/condo_service.dart';
import 'package:test/features/services/domain/repositories/condo_service_repository.dart';
import 'package:test/features/services/domain/usecases/condo_service_usecases.dart';
import 'package:test/features/services/presentation/controllers/condo_service_controller.dart';

void main() {
  test('service JSON keeps detail fields used by the booking screen', () {
    const service = CondoService(
      id: 7,
      category: ServiceCategory.laundry,
      name: 'Clothing',
      providerName: 'BrightHome Services',
      description: 'Wash and fold.',
      pricing: ServicePricing(
        type: ServicePricingType.perUnit,
        price: 30000,
        unit: 'KG',
        currency: 'USD',
      ),
      estimatedDurationMinutes: 120,
      bookingFields: <ServiceBookingField>[
        ServiceBookingField(
          key: 'quantity',
          label: 'Quantity',
          type: ServiceBookingFieldType.quantity,
          required: true,
          min: 1,
          max: 10,
          defaultValue: 2,
        ),
      ],
      availableDates: <ServiceAvailableDate>[
        ServiceAvailableDate(
          date: '2026-11-08',
          slots: <ServiceTimeSlot>[
            ServiceTimeSlot(
              id: 1,
              startTime: '09:00',
              endTime: '11:00',
              status: 'available',
            ),
          ],
        ),
      ],
      categoryId: 5,
      categoryCode: 'laundry',
      categoryLabel: 'Laundry',
      icon: 'local_laundry_service',
      noticeDays: 2,
    );

    final restored = CondoService.fromJson(service.toJson());

    expect(restored.categoryId, 5);
    expect(restored.categoryCode, 'laundry');
    expect(restored.categoryLabel, 'Laundry');
    expect(restored.icon, 'local_laundry_service');
    expect(restored.noticeDays, 2);
    expect(restored.bookingFields.single.defaultValue, 2);
    expect(restored.availableDates.single.slots.single.startTime, '09:00');
    expect(restored.pricing.currency, 'USD');
    expect(restored.pricing.unit, 'KG');
  });

  test('service request JSON round-trips every detail field', () {
    const request = ServiceRequest(
      id: '42',
      code: 'SR-42',
      serviceId: 1,
      serviceName: 'Clothing',
      category: ServiceCategory.laundry,
      scheduledDate: '2026-11-08',
      scheduledSlot: '09:00 - 11:00',
      status: ServiceRequestStatus.inProgress,
      statusLabel: 'In progress',
      price: 30000,
      currency: 'USD',
      qty: 2,
      requestedOn: 'Nov 6, 2026',
      provider: 'BrightHome Services',
      notes: 'Handle with care',
      feedback: 'Great service',
      rating: 5,
      slotId: 1,
      bookingDetails: <String, dynamic>{'quantity': 2},
    );

    final restored = ServiceRequest.fromJson(request.toJson());

    expect(restored.id, '42');
    expect(restored.code, 'SR-42');
    expect(restored.serviceId, 1);
    expect(restored.serviceName, 'Clothing');
    expect(restored.category, ServiceCategory.laundry);
    expect(restored.scheduledDate, '2026-11-08');
    expect(restored.scheduledSlot, '09:00 - 11:00');
    expect(restored.status, ServiceRequestStatus.inProgress);
    expect(restored.statusLabel, 'In progress');
    expect(restored.price, 30000);
    expect(restored.currency, 'USD');
    expect(restored.qty, 2);
    expect(restored.requestedOn, 'Nov 6, 2026');
    expect(restored.provider, 'BrightHome Services');
    expect(restored.notes, 'Handle with care');
    expect(restored.feedback, 'Great service');
    expect(restored.rating, 5);
    expect(restored.slotId, 1);
    expect(restored.bookingDetails, <String, dynamic>{'quantity': 2});
  });

  test('cached requests are scoped to the resident who fetched them', () async {
    final cache = _FakeCache();
    var account = 'user:1';
    final local = CondoServiceLocalDataSource(
      cache: cache,
      accountKey: () => account,
    );

    await local.saveServices(<CondoService>[_service(1)]);
    await local.saveRequests(
      'active',
      ServiceRequestPageResult(
        items: <ServiceRequest>[_request('a')],
        page: 1,
        limit: 20,
        total: 1,
      ),
    );

    expect(await local.readServices(), hasLength(1));
    expect((await local.readRequests('active'))?.items, hasLength(1));

    account = 'user:2';
    expect(await local.readRequests('active'), isNull);
    expect(await local.readServices(), hasLength(1));

    account = 'user:1';
    expect((await local.readRequests('active'))?.items.single.id, 'a');
  });

  test('loading an older history page keeps the cached pages', () async {
    final local = CondoServiceLocalDataSource(
      cache: _FakeCache(),
      accountKey: () => 'user:1',
    );

    await local.saveRequests(
      'history',
      ServiceRequestPageResult(
        items: <ServiceRequest>[_request('a'), _request('b')],
        page: 1,
        limit: 2,
        total: 4,
      ),
    );
    await local.saveRequests(
      'history',
      ServiceRequestPageResult(
        items: <ServiceRequest>[_request('c'), _request('d')],
        page: 2,
        limit: 2,
        total: 4,
      ),
    );

    final cached = await local.readRequests('history');

    expect(cached?.items.map((request) => request.id), <String>[
      'a',
      'b',
      'c',
      'd',
    ]);
    expect(cached?.page, 2);
    expect(cached?.total, 4);
  });

  test('a status change keeps both cached lists consistent', () async {
    final local = CondoServiceLocalDataSource(
      cache: _FakeCache(),
      accountKey: () => 'user:1',
    );
    final active = _request('a');
    await local.saveRequests(
      'active',
      ServiceRequestPageResult(
        items: <ServiceRequest>[active],
        page: 1,
        limit: 20,
        total: 1,
      ),
    );
    await local.saveRequests('history', ServiceRequestPageResult.empty);

    await local.cancelRequest(active);

    final activeCache = await local.readRequests('active');
    final historyCache = await local.readRequests('history');
    expect(activeCache?.items, isEmpty);
    expect(historyCache?.items.single.id, 'a');
    expect(historyCache?.items.single.status, ServiceRequestStatus.cancelled);
    expect(historyCache?.total, 1);
  });

  test(
    'controller shows cache and no error when the API is unreachable',
    () async {
      final repository = _FakeRepository()
        ..cachedServices = <CondoService>[_service(1)]
        ..cachedActive = ServiceRequestPageResult(
          items: <ServiceRequest>[_request('a')],
          page: 1,
          limit: 20,
          total: 1,
        )
        ..cachedHistory = ServiceRequestPageResult.empty
        ..error = const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = CondoServiceController(
        CondoServiceUseCases(repository),
      );

      await controller.loadAll();

      expect(controller.services.single.id, 1);
      expect(controller.activeRequests.single.id, 'a');
      expect(controller.isShowingCachedData.value, isTrue);
      expect(controller.errorMessage.value, isNull);
    },
  );

  test('controller replaces cache with a successful API response', () async {
    final repository = _FakeRepository()
      ..cachedServices = <CondoService>[_service(1)]
      ..cachedActive = ServiceRequestPageResult.empty
      ..cachedHistory = ServiceRequestPageResult.empty
      ..services = <CondoService>[_service(2)]
      ..active = ServiceRequestPageResult(
        items: <ServiceRequest>[_request('fresh')],
        page: 1,
        limit: 20,
        total: 1,
      );
    final controller = CondoServiceController(CondoServiceUseCases(repository));

    await controller.loadAll();

    expect(controller.services.single.id, 2);
    expect(controller.activeRequests.single.id, 'fresh');
    expect(controller.isShowingCachedData.value, isFalse);
    expect(controller.errorMessage.value, isNull);
  });

  test(
    'controller reports an error when there is no cache to fall back to',
    () async {
      final repository = _FakeRepository()
        ..cachedServices = null
        ..cachedActive = null
        ..cachedHistory = null
        ..error = const ApiException(
          'No connection.',
          kind: ApiFailureKind.network,
        );
      final controller = CondoServiceController(
        CondoServiceUseCases(repository),
      );

      await controller.loadAll();

      expect(controller.services, isEmpty);
      expect(controller.isShowingCachedData.value, isFalse);
      expect(controller.errorMessage.value, 'No connection.');
    },
  );
}

CondoService _service(int id) {
  return CondoService(
    id: id,
    category: ServiceCategory.cleaning,
    name: 'Service $id',
    providerName: 'Provider',
    pricing: const ServicePricing(
      type: ServicePricingType.fixed,
      price: 10,
      currency: 'MMK',
    ),
  );
}

ServiceRequest _request(String id) {
  return ServiceRequest(
    id: id,
    serviceId: 1,
    serviceName: 'Service 1',
    category: ServiceCategory.cleaning,
    scheduledDate: '2026-11-08',
    scheduledSlot: '09:00 - 11:00',
    status: ServiceRequestStatus.requested,
    price: 10,
    requestedOn: 'Nov 6, 2026',
    provider: 'Provider',
  );
}

class _FakeCache extends ApiCacheStore {
  // One database instance keeps drift from warning about multiple connections;
  // every method that would touch it is overridden below.
  static final AppCacheDatabase _database = AppCacheDatabase();

  _FakeCache() : super(_database);

  final entries = <String, CachedApiEntry>{};

  @override
  Future<CachedApiEntry?> read(String key) async => entries[key];

  @override
  Future<void> save({
    required String key,
    String? accountKey,
    required Object payload,
  }) async {
    entries[key] = CachedApiEntry(
      key: key,
      accountKey: accountKey,
      payloadJson: jsonEncode(payload),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> invalidate(String key) async {
    entries.remove(key);
  }

  @override
  Future<void> clearAll() async => entries.clear();
}

class _FakeRepository implements CondoServiceRepository {
  List<CondoService>? cachedServices;
  ServiceRequestPageResult? cachedActive;
  ServiceRequestPageResult? cachedHistory;
  List<CondoService> services = const <CondoService>[];
  ServiceRequestPageResult active = ServiceRequestPageResult.empty;
  ServiceRequestPageResult history = ServiceRequestPageResult.empty;
  Object? error;

  @override
  Future<List<CondoService>?> getCachedServices() async => cachedServices;

  @override
  Future<ServiceRequestPageResult?> getCachedRequests({
    required String status,
  }) async {
    return switch (status) {
      'active' => cachedActive,
      'history' => cachedHistory,
      _ => null,
    };
  }

  @override
  Future<List<CondoService>> getServices() async {
    if (error != null) throw error!;
    return services;
  }

  @override
  Future<CondoService> getService(int id) async {
    if (error != null) throw error!;
    return services.firstWhere((service) => service.id == id);
  }

  @override
  Future<ServiceRequestPageResult> getRequests({
    required String status,
    int page = 1,
  }) async {
    if (error != null) throw error!;
    return switch (status) {
      'active' => active,
      'history' => page == 1 ? history : ServiceRequestPageResult.empty,
      _ => ServiceRequestPageResult.empty,
    };
  }

  @override
  Future<ServiceRequest> createRequest(ServiceRequest request) async => request;

  @override
  Future<ServiceRequest> updateStatus(
    ServiceRequest request,
    ServiceRequestStatus status,
  ) async {
    return request.copyWith(status: status);
  }

  @override
  Future<ServiceRequest> cancelRequest(ServiceRequest request) async {
    return request.copyWith(status: ServiceRequestStatus.cancelled);
  }

  @override
  Future<ServiceRequest> rateRequest(
    ServiceRequest request,
    int rating,
    String feedback,
  ) async {
    return request.copyWith(rating: rating, feedback: feedback);
  }
}
