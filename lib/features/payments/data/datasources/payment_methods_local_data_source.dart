import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/payment_method_option.dart';
import '../models/payment_method_option_model.dart';

class PaymentMethodsLocalDataSource {
  PaymentMethodsLocalDataSource({this._cache, String? Function()? accountKey})
    : _accountKey = accountKey ?? (() => null);

  static const String cacheKeyPrefix = 'payments:methods:';

  final ApiCacheStore? _cache;
  final String? Function() _accountKey;

  static String cacheKeyFor(int userId) => '$cacheKeyPrefix$userId';

  Future<CachedPaymentMethods?> read(int userId) async {
    if (userId <= 0) {
      return null;
    }

    final key = cacheKeyFor(userId);
    final accountKey = _accountKeyFor(userId);
    final entry = await _cache?.read(key);
    if (entry == null) {
      return null;
    }
    if (entry.accountKey != accountKey || _accountKey() != accountKey) {
      return null;
    }

    try {
      final json = jsonDecode(entry.payloadJson);
      final methods = PaymentMethodOptionModel.parseList(json);
      return CachedPaymentMethods(methods: methods, updatedAt: entry.updatedAt);
    } catch (error) {
      superPrint(
        'Discarded unreadable payment methods cache: $error',
        title: 'Payments',
      );
      return _discard(key);
    }
  }

  Future<void> save(int userId, List<PaymentMethodOption> methods) async {
    if (userId <= 0) {
      return;
    }

    final accountKey = _accountKeyFor(userId);
    if (_accountKey() != accountKey) {
      return;
    }

    final models = methods
        .map(
          (method) => method is PaymentMethodOptionModel
              ? method
              : PaymentMethodOptionModel.fromEntity(method),
        )
        .toList(growable: false);
    await _cache?.save(
      key: cacheKeyFor(userId),
      accountKey: accountKey,
      payload: <String, dynamic>{
        'items': models.map((method) => method.toJson()).toList(),
      },
    );
  }

  Future<void> clear() async {
    await _cache?.invalidatePrefix(cacheKeyPrefix);
  }

  Future<CachedPaymentMethods?> _discard(String key) async {
    await _cache?.invalidate(key);
    return null;
  }

  static String _accountKeyFor(int userId) => 'user:$userId';
}
