import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/notification_item.dart';
import '../models/notification_item_model.dart';

class NotificationLocalDataSource {
  NotificationLocalDataSource()
    : _notifications = List<NotificationItemModel>.of(_initialNotifications);

  final List<NotificationItemModel> _notifications;

  static final List<NotificationItemModel> _initialNotifications = [
    const NotificationItemModel(
      id: 'notification-001',
      type: NotificationType.paymentDue,
      title: 'Payment due soon',
      message: 'Your September condo fee of \$135.00 is due on Sep 30, 2026.',
      period: NotificationPeriod.today,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-002',
      type: NotificationType.maintenanceUpdated,
      title: 'Maintenance request updated',
      message: 'Carlos M. is now working on “Leaking kitchen sink”.',
      period: NotificationPeriod.today,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-003',
      type: NotificationType.visitorArrival,
      title: 'Visitor arriving today',
      message:
          'Jamie Johnson is expected to arrive between 2:00 PM and 3:00 PM.',
      period: NotificationPeriod.today,
      isRead: true,
    ),
    const NotificationItemModel(
      id: 'notification-004',
      type: NotificationType.facilityBookingConfirmed,
      title: 'Gym booking confirmed',
      message:
          'Your Fitness Centre reservation for Sep 24 at 6:00 PM is confirmed.',
      period: NotificationPeriod.yesterday,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-005',
      type: NotificationType.newAnnouncement,
      title: 'New community announcement',
      message: 'Rooftop BBQ weekend is coming up this Saturday.',
      period: NotificationPeriod.earlier,
      isRead: true,
    ),
    const NotificationItemModel(
      id: 'notification-007',
      type: NotificationType.violationIssued,
      title: 'Rule violation issued',
      message:
          'A quiet hours violation of \$80.00 was issued on Sep 12, 2026. You can appeal it from Rules & violations.',
      period: NotificationPeriod.yesterday,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-008',
      type: NotificationType.leaseRenewal,
      title: 'Lease ends in 36 days',
      message:
          'Your rental agreement for Tower A · 1205 ends on Oct 31, 2026. Submit a renewal request from the lease screen.',
      period: NotificationPeriod.today,
      isRead: false,
    ),
    const NotificationItemModel(
      id: 'notification-006',
      type: NotificationType.paymentSuccessful,
      title: 'Payment successful',
      message: 'Your August condo fee payment was processed successfully.',
      period: NotificationPeriod.earlier,
      isRead: true,
    ),
  ];

  Future<List<NotificationItemModel>> getNotifications() async {
    return List<NotificationItemModel>.unmodifiable(_notifications);
  }

  Future<NotificationItemModel> markAsRead(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw const AppException('Notification could not be found.');
    }
    final item = _notifications[index];
    _notifications[index] = NotificationItemModel(
      id: item.id,
      type: item.type,
      title: item.title,
      message: item.message,
      period: item.period,
      isRead: true,
    );
    return _notifications[index];
  }
}
