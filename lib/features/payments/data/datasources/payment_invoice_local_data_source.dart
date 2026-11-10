import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/invoice_list.dart';
import '../models/invoice_list_model.dart';

/// Stores only the first page of an invoice list, and only its newest ten rows.
///
/// The list is personal, so the resident id and the active status filter are
/// part of the key and the stored account key is checked again on read and
/// write. Later pages are deliberately never written: offline reading is about
/// showing the latest snapshot, not impersonating a full local database.
class PaymentInvoiceLocalDataSource {
  PaymentInvoiceLocalDataSource({this._cache, String? Function()? accountKey})
    : _accountKey = accountKey ?? (() => null);

  static const String cacheKeyPrefix = 'payments:invoices:';
  static const int cachedItemLimit = 10;

  final ApiCacheStore? _cache;
  final String? Function() _accountKey;

  static String cacheKeyFor(int userId, String status) {
    return '$cacheKeyPrefix$userId:${_normalizeStatus(status)}';
  }

  Future<CachedInvoiceList?> read(int userId, String status) async {
    if (userId <= 0) return null;

    final key = cacheKeyFor(userId, status);
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
      final response = InvoiceListResponseModel.fromJson(
        Map<String, dynamic>.from(json),
      );
      return CachedInvoiceList(response: response, updatedAt: entry.updatedAt);
    } catch (error) {
      superPrint(
        'Discarded unreadable invoice list cache: $error',
        title: 'Payments',
      );
      return _discard(key);
    }
  }

  /// Saves the first page, truncated to the newest [cachedItemLimit] rows.
  ///
  /// A later page is ignored completely; the caller still displays it, but the
  /// device copy stays the latest snapshot the list opened with.
  Future<void> save(
    int userId,
    String status,
    InvoiceListResponse response,
  ) async {
    if (userId <= 0 || response.page > 1) return;

    final accountKey = _accountKeyFor(userId);
    if (_accountKey() != accountKey) return;

    final limitedItems = response.items
        .take(cachedItemLimit)
        .toList(growable: false);
    final model = InvoiceListResponseModel.fromEntity(
      response,
      items: limitedItems,
    );
    await _cache?.save(
      key: cacheKeyFor(userId, status),
      accountKey: accountKey,
      payload: model.toJson(),
    );
  }

  Future<void> clear() async {
    await _cache?.invalidatePrefix(cacheKeyPrefix);
  }

  Future<CachedInvoiceList?> _discard(String key) async {
    await _cache?.invalidate(key);
    return null;
  }

  static String _normalizeStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized.isEmpty ? 'all' : normalized;
  }

  static String _accountKeyFor(int userId) => 'user:$userId';
}
