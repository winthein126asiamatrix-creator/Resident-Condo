import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/super_print.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_local_data_source.dart';
import '../datasources/notification_remote_data_source.dart';
import '../models/notification_item_model.dart';

/// Notifications from the backend when it answers, from the device when it does
/// not.
///
/// The backend has no notification API yet ([NotificationRemoteDataSource] says
/// so), so every remote call currently fails. That is the reason for the order
/// below rather than an optimisation: the resident still sees a real list, from
/// the cache or the seed data, instead of an error screen.
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required NotificationRemoteDataSource remoteDataSource,
    required NotificationLocalDataSource localDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource;

  final NotificationRemoteDataSource _remote;
  final NotificationLocalDataSource _local;

  /// The server's unread count while it is reachable.
  int? _serverUnreadCount;

  bool _fromCache = false;

  @override
  bool get isShowingCachedData => _fromCache;

  @override
  Future<List<NotificationItem>> getNotifications() async {
    try {
      final page = await _remote.fetchNotifications();
      await _local.replaceAll(page.items, unreadCount: page.unreadCount);
      _serverUnreadCount = page.unreadCount;
      _fromCache = false;
      return List<NotificationItem>.of(page.items);
    } on ApiException catch (error) {
      return _fallback(error);
    } on AppException catch (error) {
      return _fallback(error);
    }
  }

  /// Serves the device's copy after a failed load.
  ///
  /// A network failure is the interesting case and is not surfaced: the list is
  /// simply older. A server that answered with an error is also served from the
  /// cache, but logged, so it does not pass unnoticed.
  Future<List<NotificationItem>> _fallback(Object error) async {
    _fromCache = true;
    if (error is! ApiException || !error.isRetryable) {
      superPrint(
        'Notifications came from the device, not the API: $error',
        title: 'Notifications',
      );
    }
    final cached = await _local.readCache();
    if (cached == null) {
      // Nothing cached yet: the seed list the data source starts with.
      return _local.getNotifications();
    }
    await _local.replaceAll(cached.items, unreadCount: cached.unreadCount);
    return List<NotificationItem>.of(cached.items);
  }

  @override
  Future<int> unreadCount() async {
    try {
      final count = await _remote.fetchUnreadCount();
      _serverUnreadCount = count;
      return count;
    } on ApiException {
      return await _localUnreadCount();
    } on AppException {
      return await _localUnreadCount();
    }
  }

  @override
  Future<NotificationItem> markAsRead(String id) async {
    try {
      final updated = await _remote.markAsRead(
        NotificationItemModel(
          id: id,
          type: NotificationType.unknown,
          title: '',
          message: '',
          period: NotificationPeriod.today,
          isRead: false,
        ),
      );
      await _local.applyReadState(id: id, isRead: true);
      _serverUnreadCount = null;
      return updated;
    } on ApiException catch (error) {
      if (error.isRetryable) {
        // Offline: the badge corrects and the state is cached, so the resident
        // is not asked to do anything about it.
        await _local.applyReadState(id: id, isRead: true);
        _serverUnreadCount = null;
        return _localItem(id);
      }
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _remote.markAllAsRead();
    } on ApiException catch (error) {
      if (!error.isRetryable) {
        rethrow;
      }
    }
    final items = await _local.getNotifications();
    for (final item in items) {
      await _local.applyReadState(id: item.id, isRead: true);
    }
    _serverUnreadCount = 0;
  }

  /// Drops every cached notification, so the next sign-in starts clean.
  @override
  Future<void> clearDeviceHistory() async {
    _serverUnreadCount = null;
    _fromCache = false;
    await _local.clearCache();
  }

  /// Unread counted from the device's list, for when the server cannot say.
  ///
  /// Falls short of the true total once the history is longer than one page,
  /// which is why it is only used on a path where the alternative is a wrong
  /// guess from the server's side.
  Future<int> _localUnreadCount() async {
    if (_serverUnreadCount != null) {
      return _serverUnreadCount!;
    }
    final items = await _local.getNotifications();
    return items.where((item) => !item.isRead).length;
  }

  Future<NotificationItem> _localItem(String id) async {
    final items = await _local.getNotifications();
    return items.firstWhere(
      (item) => item.id == id,
      orElse: () => NotificationItemModel(
        id: id,
        type: NotificationType.unknown,
        title: '',
        message: '',
        period: NotificationPeriod.today,
        isRead: true,
      ),
    );
  }
}
