import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_cache_database.dart';

/// One normalized cached response returned by [ApiCacheStore].
class CachedApiEntry {
  const CachedApiEntry({
    required this.key,
    required this.accountKey,
    required this.payloadJson,
    required this.updatedAt,
  });

  final String key;
  final String? accountKey;
  final String payloadJson;
  final DateTime updatedAt;
}

/// Reusable key/value cache backed by Drift. Caching is opt-in per endpoint:
/// callers decide the key, TTL and serialized payload.
class ApiCacheStore {
  ApiCacheStore(this._database);

  final AppCacheDatabase _database;

  Future<CachedApiEntry?> read(String key) async {
    final row = await (_database.select(
      _database.cacheEntries,
    )..where((t) => t.cacheKey.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return CachedApiEntry(
      key: row.cacheKey,
      accountKey: row.accountKey,
      payloadJson: row.payloadJson,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> save({
    required String key,
    String? accountKey,
    required Object payload,
  }) async {
    await _database
        .into(_database.cacheEntries)
        .insertOnConflictUpdate(
          CacheEntriesCompanion(
            cacheKey: Value(key),
            accountKey: Value(accountKey),
            payloadJson: Value(jsonEncode(payload)),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> invalidate(String key) async {
    await (_database.delete(
      _database.cacheEntries,
    )..where((t) => t.cacheKey.equals(key))).go();
  }

  Future<void> invalidatePrefix(String prefix) async {
    await (_database.delete(
      _database.cacheEntries,
    )..where((t) => t.cacheKey.like('$prefix%'))).go();
  }

  Future<void> clearAll() async {
    await _database.delete(_database.cacheEntries).go();
  }
}
