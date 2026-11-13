import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/lease.dart';
import '../models/lease_model.dart';

/// Stores the last successful lease responses on the device.
///
/// Backed by the shared [ApiCacheStore] so the lease screen can open from the
/// same Drift database as the rest of the app. Keys are scoped to the resident
/// who fetched them; an empty list is a real server answer and is cached too.
class LeaseLocalDataSource {
  LeaseLocalDataSource({this.cache, String? Function()? accountKey})
    : _accountKey = accountKey ?? (() => null);

  static const String leasesCacheKey = 'lease:leases';
  static const String renewalsCacheKey = 'lease:renewals';

  final ApiCacheStore? cache;
  final String? Function() _accountKey;

  Future<List<Lease>?> readLeases() async {
    return _readList(leasesCacheKey, LeaseModel.fromJson);
  }

  Future<void> saveLeases(Iterable<Lease> leases) async {
    await _saveList(
      leasesCacheKey,
      leases.map((lease) => LeaseModel.fromEntity(lease).toJson()),
    );
  }

  Future<List<LeaseRenewal>?> readRenewals() async {
    return _readList(renewalsCacheKey, LeaseRenewalModel.fromJson);
  }

  Future<void> saveRenewals(Iterable<LeaseRenewal> renewals) async {
    await _saveList(
      renewalsCacheKey,
      renewals.map((renewal) => LeaseRenewalModel.fromEntity(renewal).toJson()),
    );
  }

  Future<void> clear() async {
    await cache?.invalidate(leasesCacheKey);
    await cache?.invalidate(renewalsCacheKey);
  }

  Future<List<T>?> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final store = cache;
    final account = _accountKey();
    if (store == null || account == null) return null;

    final entry = await store.read(key);
    if (entry == null || entry.accountKey != account) return null;

    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map || json['items'] is! List) {
        return await _discard(key);
      }
      return (json['items'] as List)
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      superPrint(
        'Discarded unreadable lease cache ($key): $error',
        title: 'Lease',
      );
      return await _discard(key);
    }
  }

  Future<void> _saveList(
    String key,
    Iterable<Map<String, Object?>> items,
  ) async {
    final store = cache;
    final account = _accountKey();
    if (store == null || account == null) return;

    await store.save(
      key: key,
      accountKey: account,
      payload: <String, Object?>{'items': items.toList()},
    );
  }

  Future<List<T>?> _discard<T>(String key) async {
    await cache?.invalidate(key);
    return null;
  }
}
