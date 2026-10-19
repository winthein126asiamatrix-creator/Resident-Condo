import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/refresh_registry.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/usecases/notification_usecases.dart';

class NotificationController extends GetxController {
  NotificationController(this.useCases);

  /// The registry key this controller re-fetches under.
  static const String screen = 'notifications';

  final NotificationUseCases useCases;
  final notifications = <NotificationItem>[].obs;
  final isLoading = false.obs;
  final isUpdating = false.obs;
  final errorMessage = RxnString();

  /// True while the list on screen came from the device rather than the API.
  ///
  /// Read by the page to say so. A resident who cannot reach the backend should
  /// be able to tell that their notifications are simply older, not that
  /// nothing arrived.
  final isShowingCachedData = false.obs;

  /// The connectivity layer's registry, when it is registered.
  ///
  /// Nullable so the controller still works in a test that pumps the page
  /// without the full app graph, matching [DashboardController].
  RefreshRegistry? get _registry =>
      Get.isRegistered<RefreshRegistry>() ? Get.find<RefreshRegistry>() : null;

  @override
  void onInit() {
    super.onInit();
    _registry?.register(screen, loadNotifications);
    loadNotifications();
  }

  @override
  void onClose() {
    _registry?.unregister(screen);
    super.onClose();
  }

  /// How many are unread, from the server when it could say.
  ///
  /// Server-backed rather than counted from [notifications]: the list is
  /// paginated, so counting what happens to be on screen under-reports.
  int _serverUnreadCount = 0;

  int get unreadCount => _serverUnreadCount;

  List<NotificationItem> notificationsFor(NotificationPeriod period) {
    return notifications.where((item) => item.period == period).toList();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      notifications.assignAll(await useCases.getNotifications());
      _serverUnreadCount = await useCases.unreadCount();
      isShowingCachedData.value = useCases.isShowingCachedData;
      _registry?.markFresh(screen);
    } on AppException catch (error) {
      // A cached list is not a failure the resident has to act on, so the
      // message is only surfaced when there is nothing on screen to fall back
      // to. Either way the screen is marked stale so a reconnect retries.
      _registry?.markStale(screen);
      isShowingCachedData.value = true;
      if (notifications.isEmpty) {
        errorMessage.value = error.message;
      }
    } catch (_) {
      _registry?.markStale(screen);
      isShowingCachedData.value = true;
      if (notifications.isEmpty) {
        errorMessage.value = 'Unable to load notifications.';
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Marks one read, correcting the badge immediately.
  ///
  /// Optimistic on purpose: the unread dot disappearing should not wait on a
  /// round trip. A failure that is the server's own doing rolls the row back
  /// and says so; an offline failure keeps the change, because the repository
  /// has already cached it and the resident is not in a position to retry.
  Future<void> markAsRead(NotificationItem item) async {
    if (item.isRead) {
      return;
    }
    final index = notifications.indexWhere(
      (notification) => notification.id == item.id,
    );
    final previous = index == -1 ? item : notifications[index];
    if (index != -1) {
      notifications[index] = previous.copyWith(isRead: true);
      _serverUnreadCount = (_serverUnreadCount - 1).clamp(0, 1 << 31);
    }
    isUpdating.value = true;
    try {
      final updated = await useCases.markAsRead(item.id);
      final current = notifications.indexWhere(
        (notification) => notification.id == item.id,
      );
      if (current != -1) {
        notifications[current] = updated.copyWith(isRead: true);
      }
      errorMessage.value = null;
    } on AppException catch (error) {
      final current = notifications.indexWhere(
        (notification) => notification.id == item.id,
      );
      if (current != -1) {
        notifications[current] = previous;
        _serverUnreadCount += 1;
      }
      errorMessage.value = error.message;
    } catch (_) {
      final current = notifications.indexWhere(
        (notification) => notification.id == item.id,
      );
      if (current != -1) {
        notifications[current] = previous;
        _serverUnreadCount += 1;
      }
      errorMessage.value = 'Unable to update the notification.';
    } finally {
      isUpdating.value = false;
    }
  }

  /// Marks everything read.
  ///
  /// One call rather than one per row: the list is longer than the screen, and
  /// the backend can do it atomically.
  Future<void> markAllAsRead() async {
    if (unreadCount == 0) {
      return;
    }
    isUpdating.value = true;
    try {
      await useCases.markAllAsRead();
      notifications.assignAll(
        notifications.map((item) => item.copyWith(isRead: true)),
      );
      _serverUnreadCount = 0;
      errorMessage.value = null;
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to update the notifications.';
    } finally {
      isUpdating.value = false;
    }
  }

  /// Drops the device's copy, called when the session ends.
  Future<void> clearDeviceHistory() => useCases.clearDeviceHistory();
}
