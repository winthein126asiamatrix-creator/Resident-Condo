import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:test/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:test/features/notifications/domain/entities/notification_item.dart';
import 'package:test/features/notifications/domain/repositories/notification_repository.dart';
import 'package:test/features/notifications/domain/usecases/notification_usecases.dart';
import 'package:test/features/notifications/presentation/bindings/notification_binding.dart';
import 'package:test/features/notifications/presentation/controllers/notification_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('loads notifications grouped by period', () async {
    final repository = NotificationRepositoryImpl(
      NotificationLocalDataSource(),
    );
    final controller = NotificationController(NotificationUseCases(repository));

    await controller.loadNotifications();

    expect(controller.notifications, hasLength(8));
    expect(controller.unreadCount, 5);
    expect(controller.notificationsFor(NotificationPeriod.today), hasLength(4));
    expect(
      controller.notificationsFor(NotificationPeriod.yesterday),
      hasLength(2),
    );
    expect(
      controller.notificationsFor(NotificationPeriod.earlier),
      hasLength(2),
    );
  });

  test('marks individual and all notifications as read', () async {
    final repository = NotificationRepositoryImpl(
      NotificationLocalDataSource(),
    );
    final controller = NotificationController(NotificationUseCases(repository));
    await controller.loadNotifications();

    await controller.markAsRead(controller.notifications.first);
    expect(controller.unreadCount, 4);

    await controller.markAllAsRead();
    expect(controller.unreadCount, 0);
  });

  test('binding provides the notification dependency graph', () {
    NotificationBinding().dependencies();

    expect(
      Get.find<NotificationRepository>(),
      isA<NotificationRepositoryImpl>(),
    );
    expect(Get.find<NotificationUseCases>(), isA<NotificationUseCases>());
    expect(Get.find<NotificationController>(), isA<NotificationController>());
    expect(
      Get.find<NotificationController>().useCases.repository,
      isA<NotificationRepositoryImpl>(),
    );
  });
}
