enum NotificationType {
  paymentDue,
  paymentSuccessful,
  maintenanceUpdated,
  facilityBookingConfirmed,
  visitorArrival,
  newAnnouncement,
  complaintUpdated,
  leaseRenewal,
  violationIssued,
}

extension NotificationTypeLabel on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.paymentDue:
        return 'Payment due';
      case NotificationType.paymentSuccessful:
        return 'Payment successful';
      case NotificationType.maintenanceUpdated:
        return 'Maintenance updated';
      case NotificationType.facilityBookingConfirmed:
        return 'Facility booking confirmed';
      case NotificationType.visitorArrival:
        return 'Visitor arrival';
      case NotificationType.newAnnouncement:
        return 'New announcement';
      case NotificationType.complaintUpdated:
        return 'Complaint updated';
      case NotificationType.leaseRenewal:
        return 'Lease renewal';
      case NotificationType.violationIssued:
        return 'Rule violation issued';
    }
  }
}

enum NotificationPeriod { today, yesterday, earlier }

extension NotificationPeriodLabel on NotificationPeriod {
  String get label {
    switch (this) {
      case NotificationPeriod.today:
        return 'Today';
      case NotificationPeriod.yesterday:
        return 'Yesterday';
      case NotificationPeriod.earlier:
        return 'Earlier';
    }
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.period,
    required this.isRead,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final NotificationPeriod period;
  final bool isRead;

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      period: period,
      isRead: isRead ?? this.isRead,
    );
  }
}
