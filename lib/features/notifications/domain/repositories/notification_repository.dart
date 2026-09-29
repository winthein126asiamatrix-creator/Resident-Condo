import '../../domain/entities/notification_item.dart';

abstract interface class NotificationRepository {
  Future<List<NotificationItem>> getNotifications();

  Future<NotificationItem> markAsRead(String id);
}
