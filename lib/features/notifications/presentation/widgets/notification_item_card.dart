import 'package:flutter/material.dart';

import '../../domain/entities/notification_item.dart';

class NotificationItemCard extends StatelessWidget {
  const NotificationItemCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(item.type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : const Color(0xFFFBFEFD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isRead
                ? const Color(0xFFE6EEEB)
                : color.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_iconFor(item.type), color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE07A5F),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: Color(0xFF71807D),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.type.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.paymentDue:
        return const Color(0xFFC2410C);
      case NotificationType.paymentSuccessful:
        return const Color(0xFF087F5B);
      case NotificationType.maintenanceUpdated:
        return const Color(0xFFB45309);
      case NotificationType.facilityBookingConfirmed:
        return const Color(0xFF5B4CC4);
      case NotificationType.visitorArrival:
        return const Color(0xFF0F766E);
      case NotificationType.newAnnouncement:
        return const Color(0xFF52635F);
      case NotificationType.complaintUpdated:
        return const Color(0xFFB45309);
      case NotificationType.leaseRenewal:
        return const Color(0xFF5B4CC4);
      case NotificationType.violationIssued:
        return const Color(0xFFC2410C);
    }
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.paymentDue:
        return Icons.payments_outlined;
      case NotificationType.paymentSuccessful:
        return Icons.check_circle_outline_rounded;
      case NotificationType.maintenanceUpdated:
        return Icons.handyman_outlined;
      case NotificationType.facilityBookingConfirmed:
        return Icons.event_available_outlined;
      case NotificationType.visitorArrival:
        return Icons.person_pin_outlined;
      case NotificationType.newAnnouncement:
        return Icons.campaign_outlined;
      case NotificationType.complaintUpdated:
        return Icons.report_problem_outlined;
      case NotificationType.leaseRenewal:
        return Icons.autorenew_rounded;
      case NotificationType.violationIssued:
        return Icons.gavel_rounded;
    }
  }
}
