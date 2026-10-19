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

  /// A type this build does not recognise.
  ///
  /// The backend is free to add a type before the app ships support for it. A
  /// notification carrying one is still shown and still marks as read; it simply
  /// gets a neutral label and no type-specific destination, instead of the app
  /// failing to parse the list or throwing on an exhaustive switch.
  unknown,
}

/// Reads the wire spelling of a [NotificationType] sent by the backend.
///
/// Returns null rather than a default, so the caller decides how to show an
/// unrecognised value; see [NotificationType.unknown]. Both the enum spelling
/// (`newAnnouncement`) and the snake_case spelling are accepted, because the
/// provisional contract in `ApiEndPoints` has not been confirmed with the
/// backend team yet and either may end up being the one that ships.
extension NotificationTypeWire on NotificationType {
  static NotificationType? fromWire(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    for (final type in NotificationType.values) {
      if (type == NotificationType.unknown) {
        continue;
      }
      if (type.name == value) {
        return type;
      }
      final snake = type.name.replaceAllMapped(
        RegExp('([A-Z])'),
        (match) => '_${match.group(1)}'.toLowerCase(),
      );
      if (snake == value) {
        return type;
      }
    }
    return null;
  }
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
      case NotificationType.unknown:
        return 'Update';
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
