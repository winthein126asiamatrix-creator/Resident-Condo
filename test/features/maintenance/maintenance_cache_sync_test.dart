import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/cache/api_cache_store.dart';
import 'package:test/core/cache/app_cache_database.dart';
import 'package:test/features/maintenance/data/datasources/maintenance_local_data_source.dart';
import 'package:test/features/maintenance/data/datasources/maintenance_remote_data_source.dart';
import 'package:test/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:test/features/maintenance/domain/entities/maintenance_request.dart';

void main() {
  late _FakeCache cache;
  late MaintenanceLocalDataSource local;
  late _FakeRemote remote;
  late MaintenanceRepositoryImpl repository;

  setUp(() {
    cache = _FakeCache();
    local = MaintenanceLocalDataSource(cache);
    remote = _FakeRemote();
    repository = MaintenanceRepositoryImpl(remote, local);
  });

  test(
    'a list refresh updates an existing detail cache and keeps detail-only fields',
    () async {
      await local.saveRequest(
        '1',
        _request(
          status: MaintenanceStatus.submitted,
          description: 'Full description from the details endpoint.',
          photos: const <MaintenancePhoto>[
            MaintenancePhoto(id: 'p1', url: 'https://example.test/1.jpg'),
          ],
          progress: const <MaintenanceProgressEntry>[
            MaintenanceProgressEntry(status: MaintenanceStatus.submitted),
          ],
        ),
      );
      remote.listResult = _page(<MaintenanceRequest>[
        _request(
          status: MaintenanceStatus.assigned,
          priority: MaintenancePriority.high,
          description: '',
          technician: 'Aung Aung',
        ),
      ]);

      await repository.getRequests(accountKey: '1', forceRefresh: true);

      final cached = await repository.getCachedRequest('1', '1');
      expect(cached, isNotNull);
      expect(cached!.status, MaintenanceStatus.assigned);
      expect(cached.priority, MaintenancePriority.high);
      expect(cached.technician, 'Aung Aung');
      expect(cached.description, 'Full description from the details endpoint.');
      expect(cached.photos, hasLength(1));
      expect(cached.progressHistory, hasLength(1));
    },
  );

  test('a list refresh does not seed a missing detail cache', () async {
    remote.listResult = _page(<MaintenanceRequest>[
      _request(id: '2', status: MaintenanceStatus.assigned),
    ]);
    remote.details['2'] = _request(id: '2', status: MaintenanceStatus.assigned);

    await repository.getRequests(accountKey: '1', forceRefresh: true);

    expect(await local.readRequest('1', '2'), isNull);
    final loaded = await repository.getRequest('1', '2');
    expect(loaded.id, '2');
    expect(remote.detailCalls, 1);
  });

  test('a fresh cached detail is served without a network call', () async {
    await local.saveRequest(
      '1',
      _request(status: MaintenanceStatus.assigned),
    );
    remote.details['1'] = _request(id: '1', status: MaintenanceStatus.completed);

    final loaded = await repository.getRequest('1', '1');

    expect(loaded.status, MaintenanceStatus.assigned);
    expect(remote.detailCalls, 0);
  });

  test('a stale cached detail is refreshed and saved', () async {
    await local.saveRequest(
      '1',
      _request(status: MaintenanceStatus.submitted),
    );
    cache.age(
      'maintenance:request:1:1',
      const Duration(minutes: 10),
    );
    remote.details['1'] = _request(id: '1', status: MaintenanceStatus.completed);

    final loaded = await repository.getRequest('1', '1');

    expect(loaded.status, MaintenanceStatus.completed);
    expect(remote.detailCalls, 1);
    final cached = await local.readRequestEntry('1', '1');
    expect(cached!.request.status, MaintenanceStatus.completed);
    expect(
      DateTime.now().difference(cached.updatedAt),
      lessThan(const Duration(minutes: 1)),
    );
  });

  test('forceRefresh bypasses a fresh cache', () async {
    await local.saveRequest(
      '1',
      _request(status: MaintenanceStatus.submitted),
    );
    remote.details['1'] = _request(id: '1', status: MaintenanceStatus.assigned);

    final loaded = await repository.getRequest('1', '1', forceRefresh: true);

    expect(loaded.status, MaintenanceStatus.assigned);
    expect(remote.detailCalls, 1);
  });

  test('a failed detail refresh falls back to a stale cache', () async {
    await local.saveRequest(
      '1',
      _request(status: MaintenanceStatus.assigned),
    );
    cache.age('maintenance:request:1:1', const Duration(hours: 1));
    remote.detailError = Exception('offline');

    final loaded = await repository.getRequest('1', '1');

    expect(loaded.status, MaintenanceStatus.assigned);
    expect(remote.detailCalls, 1);
  });

  test('a failed detail fetch with no cache rethrows', () async {
    remote.detailError = Exception('offline');

    await expectLater(
      repository.getRequest('1', '1'),
      throwsA(isA<Exception>()),
    );
  });

  test('a failed list fetch leaves the detail cache untouched', () async {
    await local.saveRequest(
      '1',
      _request(status: MaintenanceStatus.assigned),
    );
    remote.listError = Exception('offline');

    await expectLater(
      repository.getRequests(accountKey: '1', forceRefresh: true),
      throwsA(isA<Exception>()),
    );

    final cached = await local.readRequest('1', '1');
    expect(cached!.status, MaintenanceStatus.assigned);
  });

  test('detail cache stays isolated by account', () async {
    await local.saveRequest(
      '1',
      _request(status: MaintenanceStatus.assigned),
    );
    remote.details['1'] = _request(id: '1', status: MaintenanceStatus.completed);

    expect(await local.readRequestEntry('2', '1'), isNull);
    final loaded = await repository.getRequest('2', '1');
    expect(loaded.status, MaintenanceStatus.completed);
    expect(remote.detailCalls, 1);
    expect(
      (await local.readRequest('1', '1'))!.status,
      MaintenanceStatus.assigned,
    );
  });

  test('an empty list response does not delete detail caches', () async {
    await local.saveRequest(
      '1',
      _request(status: MaintenanceStatus.assigned),
    );
    remote.listResult = _page(const <MaintenanceRequest>[]);

    await repository.getRequests(accountKey: '1', forceRefresh: true);

    expect(await local.readRequest('1', '1'), isNotNull);
  });
}

MaintenanceRequest _request({
  String id = '1',
  MaintenanceStatus status = MaintenanceStatus.submitted,
  MaintenancePriority priority = MaintenancePriority.medium,
  String title = 'Leaky tap',
  String description = 'Kitchen sink is dripping.',
  String? technician,
  List<MaintenancePhoto> photos = const <MaintenancePhoto>[],
  List<MaintenanceProgressEntry> progress =
      const <MaintenanceProgressEntry>[],
}) {
  return MaintenanceRequest(
    id: id,
    title: title,
    categoryCode: 'plumbing',
    categoryLabel: 'Plumbing',
    description: description,
    location: 'Kitchen',
    priority: priority,
    status: status,
    createdAt: '2026-11-16T09:00:00Z',
    preferredDate: '2026-11-18',
    preferredTime: '10:00',
    technician: technician,
    photos: photos,
    progressHistory: progress,
  );
}

MaintenancePageResult _page(List<MaintenanceRequest> items) {
  return MaintenancePageResult(
    items: items,
    page: 1,
    limit: 20,
    total: items.length,
  );
}

class _FakeRemote implements MaintenanceRemoteDataSource {
  MaintenancePageResult? listResult;
  Object? listError;
  int listCalls = 0;

  Map<String, MaintenanceRequest> details = <String, MaintenanceRequest>{};
  Object? detailError;
  int detailCalls = 0;

  @override
  Future<MaintenancePageResult> getRequests({
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
  }) async {
    listCalls++;
    final failure = listError;
    if (failure != null) throw failure;
    return listResult ?? MaintenancePageResult.empty;
  }

  @override
  Future<MaintenanceRequest> getRequest(Object id) async {
    detailCalls++;
    final failure = detailError;
    if (failure != null) throw failure;
    final found = details[id.toString()];
    if (found == null) throw StateError('No detail configured for $id.');
    return found;
  }

  @override
  Future<List<MaintenanceCategoryOption>> getCategories() async =>
      const <MaintenanceCategoryOption>[];

  @override
  Future<MaintenanceSummary> getSummary() async => const MaintenanceSummary();

  @override
  Future<MaintenanceRequest> createRequest({
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
    required String id,
    required String reason,
  }) =>
      throw UnimplementedError();
}

class _FakeCache extends ApiCacheStore {
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

  void age(String key, Duration duration) {
    final entry = entries[key];
    if (entry == null) return;
    entries[key] = CachedApiEntry(
      key: entry.key,
      accountKey: entry.accountKey,
      payloadJson: entry.payloadJson,
      updatedAt: entry.updatedAt.subtract(duration),
    );
  }
}
