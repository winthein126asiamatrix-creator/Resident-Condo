import '../../domain/entities/notification_item.dart';

class NotificationItemModel extends NotificationItem {
  const NotificationItemModel({
    required super.id,
    required super.type,
    required super.title,
    required super.message,
    required super.period,
    required super.isRead,
  });
}
