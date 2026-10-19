import '../../../../core/network/api_end_points.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_api_service.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/notification_item.dart';
import '../models/notification_item_model.dart';

/// One page of notifications, plus the counts the bell needs.
///
/// [unreadCount] is the server's own number rather than something counted from
/// [items], because the list is paginated: counting the page would under-report
/// as soon as there is more history than one screenful.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
  });

  final List<NotificationItemModel> items;
  final int unreadCount;
  final bool hasMore;
}

/// Talks to the backend's notification endpoints.
///
/// Uses the app's shared [DioApiService] rather than a client of its own, so
/// base URL, timeouts, the bearer token, token refresh, the Odoo JSON-RPC
/// unwrapping and error translation all behave here exactly as they do for sign
/// in.
///
/// Every path and field here is **provisional**: `ApiEndPoints` documents that
/// the backend has no notification API yet. Until the backend team confirms the
/// real paths and shape, these calls are expected to fail, and the repository
/// above falls back to the cached list rather than showing an empty screen.
class NotificationRemoteDataSource {
  const NotificationRemoteDataSource(this._service);

  final DioApiService _service;

  /// One page of the resident's notifications.
  ///
  /// `cursor` is the opaque value from a previous page's `next_cursor`; the
  /// backend decides what it means, so it is passed through untouched.
  Future<NotificationPage> fetchNotifications({
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _service.get<Map<String, dynamic>>(
      ApiEndPoints.notifications,
      query: <String, dynamic>{
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final rawItems =
        response['results'] ?? response['items'] ?? response['rows'];
    final items = <NotificationItemModel>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        final item = NotificationItemModel.fromWire(entry);
        // One malformed record is skipped rather than failing the page: losing
        // a notification is better than losing the whole history.
        if (item != null) {
          items.add(item);
        }
      }
    }
    superPrint({
      'count': items.length,
      'unread': _countOf(response),
    }, title: 'Notifications Page');
    return NotificationPage(
      items: items,
      unreadCount: _countOf(response),
      hasMore: response['has_more'] == true,
    );
  }

  /// Marks one notification read and returns the backend's updated record.
  ///
  /// Falls back to a local patch when the server answers with nothing usable,
  /// because the read state is already known locally and dropping it would make
  /// the badge flicker back on the next refresh.
  Future<NotificationItem> markAsRead(NotificationItem item) async {
    final response = await _service.post<Map<String, dynamic>>(
      ApiEndPoints.notificationRead(item.id),
    );
    final updated = NotificationItemModel.fromWire(response);
    return updated ?? item.copyWith(isRead: true);
  }

  /// Marks everything read in one call, returning how many were unread.
  Future<int> markAllAsRead() async {
    final response = await _service.post<Map<String, dynamic>>(
      ApiEndPoints.notificationReadAll,
    );
    return _countOf(response);
  }

  /// The unread count on its own, for refreshing the bell without the history.
  Future<int> fetchUnreadCount() async {
    final response = await _service.get<Map<String, dynamic>>(
      ApiEndPoints.notificationUnreadCount,
    );
    return _countOf(response);
  }

  /// Tells the backend which FCM token to push to for this account.
  ///
  /// Returns whether the backend accepted it. A rejected registration is not an
  /// error the resident should ever see: push simply stops arriving, and the
  /// app carries on. The token itself is never logged.
  Future<bool> registerDeviceToken(
    String token, {
    required String platform,
  }) async {
    try {
      await _service.post<void>(
        ApiEndPoints.notificationDevices,
        data: <String, Object?>{'fcm_token': token, 'platform': platform},
      );
      superPrint('Device token registered.', title: 'Notifications');
      return true;
    } on ApiException catch (error) {
      superPrint(
        'Device token registration refused: ${error.kind.name}',
        title: 'Notifications',
      );
      return false;
    }
  }

  /// Removes this device's token, so a signed-out device is not pushed to.
  Future<void> unregisterDeviceToken(String token) async {
    try {
      await _service.delete<void>(ApiEndPoints.notificationDevice(token));
      superPrint('Device token unregistered.', title: 'Notifications');
    } on ApiException catch (error) {
      superPrint(
        'Device token unregistration failed: ${error.kind.name}',
        title: 'Notifications',
      );
    }
  }

  /// The unread count, accepting the several spellings a response may use.
  static int _countOf(Map<String, dynamic> response) {
    for (final key in <String>['unread_count', 'unreadCount', 'unread']) {
      final value = response[key];
      if (value is num) {
        return value.toInt();
      }
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }
}
