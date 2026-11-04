import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/utils/super_print.dart';
import '../models/my_unit_models.dart';

class UnitLocalDataSource {
  UnitLocalDataSource({this.cache, String? Function()? accountKey})
    : _accountKey = accountKey ?? (() => null);

  static const String cacheKey = 'my_unit';

  final ApiCacheStore? cache;
  final String? Function() _accountKey;

  Future<MyUnitResponse?> read(int? userId) async {
    final entry = await cache?.read(cacheKey);
    if (entry == null) return null;
    if (userId != null &&
        entry.accountKey != null &&
        entry.accountKey != userId.toString()) {
      return null;
    }
    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) return null;
      return MyUnitResponse.fromJson(Map<String, dynamic>.from(json));
    } catch (error) {
      superPrint('Discarded unreadable my-unit cache: $error', title: 'Unit');
      await cache?.invalidate(cacheKey);
      return null;
    }
  }

  Future<void> save(int? userId, MyUnitResponse data) async {
    await cache?.save(
      key: cacheKey,
      accountKey: userId?.toString(),
      payload: data.toJson(),
    );
  }

  Future<void> clear() async {
    await cache?.invalidate(cacheKey);
  }
}
