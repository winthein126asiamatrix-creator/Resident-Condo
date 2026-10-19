import 'dart:convert';

import '../../../../core/cache/api_cache_store.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/notification_item.dart';
import '../models/notification_item_model.dart';

/// Reads and writes the notification list the app keeps on the device.
///
/// Backed by the app's existing [ApiCacheStore] rather than a second
/// persistence system: the same Drift database that caches API responses already
/// stores a serialized payload keyed per account, which is exactly what the
/// notification history needs. No new table, no new package.
///
/// The in-memory [_notifications] list stays the working copy the UI renders, so
/// the rest of the app keeps treating this as a plain list source.
class NotificationLocalDataSource {
  NotificationLocalDataSource({
    ApiCacheStore? cache,
    String? Function()? accountKey,
  }) : _cache = cache,
       _accountKey = accountKey ?? (() => null),
       _notifications = List<NotificationItemModel>.of(_initialNotifications);

  /// Cache key for the history. Prefix, so [ApiCacheStore.invalidatePrefix] can
  /// drop every notification entry for this account on sign-out.
  static const String cacheKeyPrefix = 'notifications:';

  static const String _listCacheKey = '${cacheKeyPrefix}list';

  final ApiCacheStore? _cache;
  final String? Function() _accountKey;

  final List<NotificationItemModel> _notifications;

  static final List<NotificationItemModel> _initialNotifications = [
    const NotificationItemModel(
      id: 'notification-001',
      type: NotificationType.paymentDue,
      title: 'Payment due soon',
      message: 'Your September condo fee of \$135.00 is due on Sep 30, 2026.',
      period: NotificationPeriod.today,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-002',
      type: NotificationType.maintenanceUpdated,
      title: 'Maintenance request updated',
      message: 'Carlos M. is now working on “Leaking kitchen sink”.',
      period: NotificationPeriod.today,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-003',
      type: NotificationType.visitorArrival,
      title: 'Visitor arriving today',
      message:
          'Jamie Johnson is expected to arrive between 2:00 PM and 3:00 PM.',
      period: NotificationPeriod.today,
      isRead: true,
    ),
    const NotificationItemModel(
      id: 'notification-004',
      type: NotificationType.facilityBookingConfirmed,
      title: 'Gym booking confirmed',
      message:
          'Your Fitness Centre reservation for Sep 24 at 6:00 PM is confirmed.',
      period: NotificationPeriod.yesterday,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-005',
      type: NotificationType.newAnnouncement,
      title: 'New community announcement',
      message: 'Rooftop BBQ weekend is coming up this Saturday.',
      period: NotificationPeriod.earlier,
      isRead: true,
    ),
    const NotificationItemModel(
      id: 'notification-007',
      type: NotificationType.violationIssued,
      title: 'Rule violation issued',
      message: 'A quiet hours violation of \$80.00 was issued on Sep 12, 2026. You can appeal it from Rules & violations.',
      period: NotificationPeriod.yesterday,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-008',
      type: NotificationType.leaseRenewal,
      title: 'Lease ends in 36 days',
      message: 'Your rental agreement for Tower A · 1205 ends on Oct 31, 2026. Submit a renewal request from the lease screen.',
      period: NotificationPeriod.today,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-006',
      type: NotificationType.paymentSuccessful,
      title: 'Payment successful',
      message: 'Your August condo fee payment was processed successfully.',
      period: NotificationPeriod.earlier,
      isRead: true,
    ),
  ];

  Future<List<NotificationItemModel>> getNotifications() async {
    return List<NotificationItemModel>.unmodifiable(_notifications);
  }

  /// Replaces the working list and the cached copy with a server page.
  ///
  /// Read state lives in the cache along with the records, which is what lets a
  /// notification marked read while offline stay read once the API comes back.
  Future<void> replaceAll(
    List<NotificationItemModel> items, {
    int? unreadCount,
  }) async {
    _notifications
      ..clear()
      ..addAll(items);
    final entry = await _readCache();
    await _writeCache(
      items: items,
      unreadCount: unreadCount ?? entry?.unreadCount ?? 0,
    );
  }

  /// The cached history, or null when nothing has been cached for this account.
  ///
  /// Read when the API is unreachable so the resident still sees their
  /// notifications, which is the whole point of keeping them on the device.
  Future<NotificationCache?> readCache() => _readCache();

  /// Drops every cached notification for this account.
  ///
  /// Called on sign-out: the next resident to sign in on this device must not
  /// briefly see the previous one's history.
  Future<void> clearCache() async {
    await _cache?.invalidatePrefix(cacheKeyPrefix);
  }

  Future<NotificationCache?> _readCache() async {
    final entry = await _cache?.read(_listCacheKey);
    if (entry == null) {
      return null;
    }
    try {
      final json = jsonDecode(entry.payloadJson);
      if (json is! Map) {
        return null;
      }
      final rawItems = json['items'];
      final items = <NotificationItemModel>[];
      if (rawItems is List) {
        for (final raw in rawItems) {
          final item = NotificationItemModel.fromCacheJson(raw);
          if (item != null) {
            items.add(item);
          }
        }
      }
      final unread = json['unread_count'];
      return NotificationCache(
        items: items,
        unreadCount: unread is num ? unread.toInt() : items.length,
        updatedAt: entry.updatedAt,
      );
    } catch (error) {
      // A cache written by an older build, or a half-written row: drop it
      // rather than failing the screen that only wanted it as a fallback.
      superPrint(
        'Discarded an unreadable notification cache: $error',
        title: 'Notifications',
      );
      await _cache?.invalidate(_listCacheKey);
      return null;
    }
  }

  Future<void> _writeCache({
    required List<NotificationItemModel> items,
    required int unreadCount,
  }) async {
    await _cache?.save(
      key: _listCacheKey,
      accountKey: _accountKey(),
      payload: <String, Object?>{
        'items': items.map((item) => item.toCacheJson()).toList(),
        'unread_count': unreadCount,
      },
    );
  }

  Future<NotificationItemModel> markAsRead(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw const AppException('Notification could not be found.');
    }
    final item = _notifications[index];
    _notifications[index] = NotificationItemModel(
      id: item.id,
      type: item.type,
      title: item.title,
      message: item.message,
      period: item.period,
      isRead: true,
    );
    final unread = _notifications.where((entry) => !entry.isRead).length;
    await _writeCache(items: _notifications, unreadCount: unread);
    return _notifications[index];
  }

  /// Applies a read state to the working list and the cache, without a request.
  ///
  /// Used for the optimistic path: the badge corrects immediately, and the
  /// change survives a restart even if the request to the backend is what
  /// ultimately failed.
  Future<void> applyReadState({
    required String id,
    required bool isRead,
    int? unreadCount,
  }) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: isRead);
    }
    final unread =
        unreadCount ?? _notifications.where((item) => !item.isRead).length;
    await _writeCache(items: _notifications, unreadCount: unread);
  }
}

/// A cached history, and the unread count that went with it.
class NotificationCache {
  const NotificationCache({
    required this.items,
    required this.unreadCount,
    required this.updatedAt,
  });

  final List<NotificationItemModel> items;
  final int unreadCount;
  final DateTime updatedAt;
}
