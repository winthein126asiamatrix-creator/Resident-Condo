import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../domain/entities/maintenance_request.dart';
import '../models/maintenance_request_model.dart';

class MaintenanceLocalDataSource {
  const MaintenanceLocalDataSource(this._cache);

  final ApiCacheStore _cache;

  static const String _categoriesKey = 'maintenance:categories';

  String _summaryKey(String accountKey) => 'maintenance:summary:$accountKey';

  String _requestsKey(String accountKey) => 'maintenance:requests:$accountKey';

  String _requestKey(String accountKey, String id) =>
      'maintenance:request:$accountKey:$id';

  Future<List<MaintenanceCategoryOption>?> readCategories() async {
    final entry = await _cache.read(_categoriesKey);
    if (entry == null) return null;
    final decoded = _decode(entry.payloadJson);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map(
          (item) => MaintenanceCategoryOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> saveCategories(
    List<MaintenanceCategoryOption> categories,
  ) async {
    if (categories.isEmpty) return;
    await _cache.save(
      key: _categoriesKey,
      payload: categories.map((option) => option.toJson()).toList(),
    );
  }

  Future<MaintenanceSummary?> readSummary(String accountKey) async {
    final entry = await _cache.read(_summaryKey(accountKey));
    if (entry == null) return null;
    return MaintenanceSummary.fromJson(_decode(entry.payloadJson));
  }

  Future<void> saveSummary(
    String accountKey,
    MaintenanceSummary summary,
  ) async {
    await _cache.save(
      key: _summaryKey(accountKey),
      accountKey: accountKey,
      payload: summary.toJson(),
    );
  }

  Future<MaintenancePageResult?> readRequests(String accountKey) async {
    final entry = await _cache.read(_requestsKey(accountKey));
    if (entry == null) return null;
    return MaintenancePageResult.fromJson(_decode(entry.payloadJson));
  }

  Future<void> saveRequests(
    String accountKey,
    MaintenancePageResult result,
  ) async {
    await _cache.save(
      key: _requestsKey(accountKey),
      accountKey: accountKey,
      payload: result.toJson(),
    );
  }

  Future<MaintenanceRequest?> readRequest(String accountKey, String id) async {
    final entry = await _cache.read(_requestKey(accountKey, id));
    if (entry == null) return null;
    final decoded = _decode(entry.payloadJson);
    if (decoded is! Map) return null;
    return MaintenanceRequestModel.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveRequest(
    String accountKey,
    MaintenanceRequest request,
  ) async {
    await _cache.save(
      key: _requestKey(accountKey, request.id),
      accountKey: accountKey,
      payload: MaintenanceRequestModelData.toJson(request),
    );
  }

  Future<void> invalidateRequests(String accountKey) =>
      _cache.invalidate(_requestsKey(accountKey));

  Future<void> invalidateSummary(String accountKey) =>
      _cache.invalidate(_summaryKey(accountKey));

  Future<void> invalidateRequest(String accountKey, String id) =>
      _cache.invalidate(_requestKey(accountKey, id));

  Object? _decode(String payload) {
    try {
      return jsonDecode(payload);
    } catch (_) {
      return null;
    }
  }
}
