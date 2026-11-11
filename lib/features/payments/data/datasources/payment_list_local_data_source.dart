import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/payment_list.dart';
import '../models/payment_list_model.dart';

class PaymentListLocalDataSource {
  PaymentListLocalDataSource({this._cache, String? Function()? accountKey})
    : _accountKey = accountKey ?? (() => null);

  static const String cacheKeyPrefix = 'payments:list:';
  static const int cachedItemLimit = 20;

  final ApiCacheStore? _cache;
  final String? Function() _accountKey;

  static String cacheKeyFor(int userId) => '$cacheKeyPrefix$userId';

  Future<CachedPaymentList?> read(int userId) async {
    if (userId <= 0) return null;

    final key = cacheKeyFor(userId);
    final accountKey = _accountKeyFor(userId);
    final entry = await _cache?.read(key);
    if (entry == null) return null;
    if (entry.accountKey != accountKey || _accountKey() != accountKey) {
      return null;
    }

    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) {
        return await _discard(key);
      }
      final response = PaymentListResponseModel.fromJson(
        Map<String, dynamic>.from(json),
      );
      return CachedPaymentList(response: response, updatedAt: entry.updatedAt);
    } catch (error) {
      superPrint(
        'Discarded unreadable payment list cache: $error',
        title: 'Payments',
      );
      return _discard(key);
    }
  }

  Future<void> save(int userId, PaymentListResponse response) async {
    if (userId <= 0 || response.page > 1) return;

    final accountKey = _accountKeyFor(userId);
    if (_accountKey() != accountKey) return;

    final limitedItems = response.items
        .take(cachedItemLimit)
        .toList(growable: false);
    final model = PaymentListResponseModel.fromEntity(
      response,
      items: limitedItems,
    );
    await _cache?.save(
      key: cacheKeyFor(userId),
      accountKey: accountKey,
      payload: model.toJson(),
    );
  }

  Future<void> clear() async {
    await _cache?.invalidatePrefix(cacheKeyPrefix);
  }

  Future<CachedPaymentList?> _discard(String key) async {
    await _cache?.invalidate(key);
    return null;
  }

  static String _accountKeyFor(int userId) => 'user:$userId';
}
