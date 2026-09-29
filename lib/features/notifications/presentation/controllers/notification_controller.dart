import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/usecases/notification_usecases.dart';

class NotificationController extends GetxController {
  NotificationController(this.useCases);

  final NotificationUseCases useCases;
  final notifications = <NotificationItem>[].obs;
  final isLoading = false.obs;
  final isUpdating = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  List<NotificationItem> notificationsFor(NotificationPeriod period) {
    return notifications.where((item) => item.period == period).toList();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      notifications.assignAll(await useCases.getNotifications());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load notifications.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(NotificationItem item) async {
    if (item.isRead) {
      return;
    }
    isUpdating.value = true;
    try {
      final updated = await useCases.markAsRead(item.id);
      final index = notifications.indexWhere(
        (notification) => notification.id == item.id,
      );
      if (index != -1) {
        notifications[index] = updated;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to update the notification.';
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> markAllAsRead() async {
    if (unreadCount == 0) {
      return;
    }
    isUpdating.value = true;
    try {
      for (final item in notifications.where(
        (notification) => !notification.isRead,
      )) {
        await markAsRead(item);
      }
    } finally {
      isUpdating.value = false;
    }
  }
}
