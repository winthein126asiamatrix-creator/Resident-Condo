import '../entities/notification_item.dart';
import '../repositories/notification_repository.dart';

class NotificationUseCases {
  const NotificationUseCases(this.repository);

  final NotificationRepository repository;

  Future<List<NotificationItem>> getNotifications() {
    return repository.getNotifications();
  }

  Future<NotificationItem> markAsRead(String id) {
    return repository.markAsRead(id);
  }
}
