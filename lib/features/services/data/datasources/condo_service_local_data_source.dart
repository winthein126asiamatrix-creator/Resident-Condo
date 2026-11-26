import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/condo_service.dart';
import '../models/condo_service_model.dart';

/// Reads and writes the services data the app keeps on the device.
///
/// Backed by the existing [ApiCacheStore] rather than a second persistence
/// system: the same Drift database that caches API responses already stores a
/// serialized payload keyed per account. There is no seeded demo list here, so a
/// screen only ever shows services and requests that actually came back from the
/// API for the signed-in resident.
class CondoServiceLocalDataSource {
  CondoServiceLocalDataSource({this._cache, String? Function()? accountKey})
    : _accountKey = accountKey ?? (() => null);

  static const String servicesCacheKey = 'services:catalogue';

  /// The catalogue snapshot belonging to one resident.
  ///
  /// The shared [servicesCacheKey] is kept as a fallback for installs that
  /// cached a catalogue before it was scoped, but a signed-in resident reads
  /// and writes this key so refreshing their list cannot replace another
  /// resident's copy.
  static String _servicesKeyFor(String accountKey) =>
      '$servicesCacheKey:$accountKey';

  /// Prefix shared by every cached request list, so one lookup can drop them all.
  static const String requestsCacheKeyPrefix = 'service_requests:';

  static const String activeRequestsCacheKey =
      '${requestsCacheKeyPrefix}active';
  static const String historyRequestsCacheKey =
      '${requestsCacheKeyPrefix}history';

  static const String _activeStatus = 'active';
  static const String _historyStatus = 'history';

  final ApiCacheStore? _cache;
  final String? Function() _accountKey;

  /// The cached catalogue, or null when nothing has been cached yet.
  ///
  /// Null and an empty list are different: the first means there is no snapshot
  /// to fall back to, the second is a real, empty catalogue the API returned.
  Future<List<CondoService>?> readServices() async {
    final account = _accountKey();
    if (account != null) {
      final scoped = await _readServicesEntry(
        _servicesKeyFor(account),
        accountKey: account,
      );
      if (scoped != null) return scoped;
    }
    // No snapshot for this resident yet: fall back to the shared catalogue
    // written by older builds so the screen still has something to show.
    return _readServicesEntry(servicesCacheKey);
  }

  /// Saves a page of the catalogue.
  ///
  /// Page 1 is a full refresh, so it replaces the cached list: services the
  /// API no longer returns disappear from the screen. Later pages are appended
  /// to the pages already on the device, keyed by service id so a record that
  /// appears twice is kept once with the newest API copy.
  Future<void> saveServices(
    Iterable<CondoService> services, {
    int page = 1,
  }) async {
    final incoming = services.toList(growable: false);
    var items = incoming;
    if (page > 1) {
      final cached = await readServices();
      if (cached != null) {
        final merged = <int, CondoService>{};
        for (final service in cached) {
          merged[service.id] = service;
        }
        for (final service in incoming) {
          // The API copy wins, but a duplicate keeps the position the earlier
          // page gave it so the list order stays stable.
          merged[service.id] = service;
        }
        items = merged.values.toList(growable: false);
      }
    }

    final payload = <String, Object?>{
      'items': items.map((service) => service.toJson()).toList(),
      'page': page,
    };
    final account = _accountKey();
    if (account != null) {
      await _cache?.save(
        key: _servicesKeyFor(account),
        accountKey: account,
        payload: payload,
      );
    }
    await _cache?.save(key: servicesCacheKey, payload: payload);
  }

  Future<List<CondoService>?> _readServicesEntry(
    String key, {
    String? accountKey,
  }) async {
    final entry = await _cache?.read(key);
    if (entry == null) return null;
    if (accountKey != null && entry.accountKey != accountKey) return null;
    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) return await _discardServices(key);
      final items = json['items'];
      if (items is! List) return await _discardServices(key);
      // Older builds could leave the same service in the payload more than
      // once; collapse them here so the screen never renders a duplicate even
      // before the next page 1 refresh rewrites the cache.
      final unique = <int, CondoService>{};
      for (final item in items.whereType<Map>()) {
        final service = CondoService.fromJson(Map<String, dynamic>.from(item));
        unique[service.id] = service;
      }
      return unique.values.toList();
    } catch (error) {
      superPrint(
        'Discarded unreadable service catalogue cache: $error',
        title: 'Services',
      );
      return _discardServices(key);
    }
  }

  /// The cached page for [status], or null when nothing belongs to this account.
  Future<ServiceRequestPageResult?> readRequests(String status) async {
    final key = _keyForStatus(status);
    final account = _accountKey();
    if (key == null || account == null) return null;

    final entry = await _cache?.read(key);
    if (entry == null || entry.accountKey != account) return null;

    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) return await _discardRequests(key);
      final itemsJson = json['items'];
      if (itemsJson is! List) return await _discardRequests(key);
      return ServiceRequestPageResult(
        items: itemsJson
            .whereType<Map>()
            .map(
              (item) =>
                  ServiceRequest.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
        page: _asInt(json['page']) ?? 1,
        limit: _asInt(json['limit']) ?? 20,
        total: _asInt(json['total']) ?? itemsJson.length,
      );
    } catch (error) {
      superPrint(
        'Discarded unreadable service request cache: $error',
        title: 'Services',
      );
      return _discardRequests(key);
    }
  }

  Future<void> saveRequests(
    String status,
    ServiceRequestPageResult page,
  ) async {
    final key = _keyForStatus(status);
    final account = _accountKey();
    if (key == null || account == null) return;

    var items = page.items;
    if (status == _historyStatus && page.page > 1) {
      // Loading an older page must keep the pages already on the device. The
      // server's copy of a record wins when the same one appears twice.
      final cached = await readRequests(_historyStatus);
      if (cached != null) {
        final merged = <String, ServiceRequest>{};
        for (final item in cached.items) {
          merged[item.id] = item;
        }
        for (final item in page.items) {
          merged[item.id] = item;
        }
        items = merged.values.toList();
      }
    }

    await _cache?.save(
      key: key,
      accountKey: account,
      payload: <String, Object?>{
        'items': items.map((item) => item.toJson()).toList(),
        'page': page.page,
        'limit': page.limit,
        'total': page.total,
      },
    );
  }

  /// Adds a newly created request to the cache before the next refresh.
  Future<void> addRequest(ServiceRequest request) async {
    final status = request.status.isHistory ? _historyStatus : _activeStatus;
    final cached = await readRequests(status);
    final known = cached?.items.any((item) => item.id == request.id) ?? false;
    final items = <ServiceRequest>[
      request,
      ...?cached?.items.where((item) => item.id != request.id),
    ];
    await saveRequests(
      status,
      ServiceRequestPageResult(
        items: items,
        page: cached?.page ?? 1,
        limit: cached?.limit ?? 20,
        total: (cached?.total ?? (cached?.items.length ?? 0)) + (known ? 0 : 1),
      ),
    );
  }

  Future<ServiceRequestModel> updateStatus(
    ServiceRequest request,
    ServiceRequestStatus status,
  ) {
    return _replace(request.copyWith(status: status));
  }

  Future<ServiceRequestModel> cancelRequest(ServiceRequest request) {
    if (request.status != ServiceRequestStatus.requested) {
      throw const AppException(
        'This request can no longer be cancelled. Contact the concierge.',
      );
    }
    return _replace(request.copyWith(status: ServiceRequestStatus.cancelled));
  }

  Future<ServiceRequestModel> replaceRequest(ServiceRequest updated) =>
      _replace(updated);

  Future<ServiceRequestModel> rateRequest(
    ServiceRequest request,
    int rating,
    String feedback,
  ) {
    if (request.status != ServiceRequestStatus.completed) {
      throw const AppException('Only completed services can be rated.');
    }
    if (rating < 1 || rating > 5) {
      throw const AppException('Choose a rating between 1 and 5.');
    }
    return _replace(
      request.copyWith(rating: rating, feedback: feedback.trim()),
    );
  }

  Future<ServiceRequestModel> _replace(ServiceRequest updated) async {
    if (_accountKey() == null) {
      throw const AppException('Sign in to update service requests.');
    }

    final active = await readRequests(_activeStatus);
    final history = await readRequests(_historyStatus);
    final wasActive =
        active?.items.any((item) => item.id == updated.id) ?? false;
    final wasHistory =
        history?.items.any((item) => item.id == updated.id) ?? false;
    if (!wasActive && !wasHistory) {
      throw const AppException('Service request could not be found.');
    }

    final activeItems = (active?.items ?? const <ServiceRequest>[])
        .where((item) => item.id != updated.id)
        .toList();
    final historyItems = (history?.items ?? const <ServiceRequest>[])
        .where((item) => item.id != updated.id)
        .toList();
    if (updated.status.isHistory) {
      historyItems.insert(0, updated);
    } else {
      activeItems.insert(0, updated);
    }

    if (wasActive || !updated.status.isHistory) {
      await saveRequests(
        _activeStatus,
        ServiceRequestPageResult(
          items: activeItems,
          page: active?.page ?? 1,
          limit: active?.limit ?? 20,
          total: activeItems.length,
        ),
      );
    }
    if (wasHistory || updated.status.isHistory) {
      var total = history?.total ?? historyItems.length;
      if (wasActive && updated.status.isHistory) {
        total += 1;
      } else if (wasHistory && !updated.status.isHistory && total > 0) {
        total -= 1;
      }
      await saveRequests(
        _historyStatus,
        ServiceRequestPageResult(
          items: historyItems,
          page: history?.page ?? 1,
          limit: history?.limit ?? 20,
          total: total,
        ),
      );
    }

    return ServiceRequestModel.fromEntity(updated);
  }

  String? _keyForStatus(String status) {
    switch (status) {
      case _activeStatus:
        return activeRequestsCacheKey;
      case _historyStatus:
        return historyRequestsCacheKey;
      default:
        return null;
    }
  }

  Future<List<CondoService>?> _discardServices(String key) async {
    await _cache?.invalidate(key);
    return null;
  }

  Future<ServiceRequestPageResult?> _discardRequests(String key) async {
    await _cache?.invalidate(key);
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
