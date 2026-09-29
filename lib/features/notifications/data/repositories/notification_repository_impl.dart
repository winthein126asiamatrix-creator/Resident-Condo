import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_local_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this.localDataSource);

  final NotificationLocalDataSource localDataSource;

  @override
  Future<List<NotificationItem>> getNotifications() async {
    final notifications = await localDataSource.getNotifications();
    return List<NotificationItem>.of(notifications);
  }

  @override
  Future<NotificationItem> markAsRead(String id) {
    return localDataSource.markAsRead(id);
  }
}
