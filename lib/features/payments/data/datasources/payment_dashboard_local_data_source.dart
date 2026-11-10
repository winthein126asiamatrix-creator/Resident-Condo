import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/payment_dashboard.dart';
import '../models/payment_dashboard_model.dart';

/// Reads and writes the payment dashboard snapshot kept on the device.
///
/// Backed by the app's existing [ApiCacheStore] instead of a second persistence
/// system. The cache key carries the resident id, and the stored account key is
/// checked again on read, so one resident's dashboard can never be shown to
/// another.
class PaymentDashboardLocalDataSource {
  PaymentDashboardLocalDataSource({this._cache, String? Function()? accountKey})
    : _accountKey = accountKey ?? (() => null);

  static const String cacheKeyPrefix = 'payments:dashboard:';

  static String cacheKeyFor(int userId) => '$cacheKeyPrefix$userId';

  final ApiCacheStore? _cache;
  final String? Function() _accountKey;

  /// The cached dashboard for [userId], or null when there is no snapshot.
  ///
  /// A successful empty response is still a snapshot, so null only means
  /// nothing has been stored for this resident yet.
  Future<CachedPaymentDashboard?> read(int userId) async {
    if (userId <= 0) return null;

    final key = cacheKeyFor(userId);
    final accountKey = _accountKeyFor(userId);
    final entry = await _cache?.read(key);
    if (entry == null) return null;
    // Both the requested resident and the signed-in resident must match, so a
    // caller cannot read a previous account's row by passing its id.
    if (entry.accountKey != accountKey || _accountKey() != accountKey) {
      return null;
    }

    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) {
        return await _discard(key);
      }
      return CachedPaymentDashboard(
        dashboard: PaymentDashboardModel.fromJson(
          Map<String, dynamic>.from(json),
        ),
        updatedAt: entry.updatedAt,
      );
    } catch (error) {
      superPrint(
        'Discarded unreadable payment dashboard cache: $error',
        title: 'Payments',
      );
      return await _discard(key);
    }
  }

  /// Stores a validated API response for [userId].
  ///
  /// The resident is checked again at write time: a response that arrives
  /// after a sign-out or an account switch must not recreate the previous
  /// resident's cache entry.
  Future<void> save(int userId, PaymentDashboard dashboard) async {
    if (userId <= 0) return;

    final accountKey = _accountKeyFor(userId);
    if (_accountKey() != accountKey) return;

    final model = dashboard is PaymentDashboardModel
        ? dashboard
        : PaymentDashboardModel.fromEntity(dashboard);
    await _cache?.save(
      key: cacheKeyFor(userId),
      accountKey: accountKey,
      payload: model.toJson(),
    );
  }

  /// Drops every resident's dashboard snapshot.
  ///
  /// Called on sign-out so a later resident cannot read the previous one's
  /// cached balance from this device.
  Future<void> clear() async {
    await _cache?.invalidatePrefix(cacheKeyPrefix);
  }

  Future<CachedPaymentDashboard?> _discard(String key) async {
    await _cache?.invalidate(key);
    return null;
  }

  static String _accountKeyFor(int userId) => 'user:$userId';
}
