import '../../domain/entities/notification_item.dart';

abstract interface class NotificationRepository {
  Future<List<NotificationItem>> getNotifications();

  Future<NotificationItem> markAsRead(String id);

  /// Marks every notification read in one call.
  ///
  /// Separate from calling [markAsRead] repeatedly: the backend can do it
  /// atomically, and the list is usually longer than what is on screen.
  Future<void> markAllAsRead();

  /// How many are unread, from the server when it is reachable.
  Future<int> unreadCount();

  /// True when the last load was served from the device rather than the API.
  ///
  /// The UI says so rather than showing stale notifications as if they were
  /// current, and a resident can tell the difference between "nothing new" and
  /// "could not check".
  bool get isShowingCachedData;

  /// Drops the notifications kept on this device.
  ///
  /// Called on sign-out, so the next resident to sign in on this device cannot
  /// briefly see the previous one's history.
  Future<void> clearDeviceHistory();
}
