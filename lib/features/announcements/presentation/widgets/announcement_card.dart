import 'package:flutter/material.dart';

import '../../domain/entities/announcement.dart';

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    required this.announcement,
    required this.onTap,
    super.key,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(announcement.category);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: announcement.isRead ? Colors.white : const Color(0xFFFBFEFD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: announcement.isRead
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
              child: Icon(
                _iconFor(announcement.category),
                color: color,
                size: 21,
              ),
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
                          announcement.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!announcement.isRead)
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
                    announcement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71807D),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(label: announcement.category.label, color: color),
                      if (announcement.urgency != AnnouncementUrgency.normal)
                        _Badge(
                          label: announcement.urgency.label,
                          color: _urgencyColor(announcement.urgency),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    announcement.date,
                    style: const TextStyle(
                      color: Color(0xFF9AA9A5),
                      fontSize: 11,
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

  Color _colorFor(AnnouncementCategory category) {
    switch (category) {
      case AnnouncementCategory.maintenance:
        return const Color(0xFFB45309);
      case AnnouncementCategory.security:
        return const Color(0xFF5B4CC4);
      case AnnouncementCategory.community:
        return const Color(0xFF0F766E);
      case AnnouncementCategory.emergency:
        return const Color(0xFFC2410C);
      case AnnouncementCategory.general:
        return const Color(0xFF52635F);
    }
  }

  Color _urgencyColor(AnnouncementUrgency urgency) {
    return urgency == AnnouncementUrgency.emergency
        ? const Color(0xFFC2410C)
        : const Color(0xFFB45309);
  }

  IconData _iconFor(AnnouncementCategory category) {
    switch (category) {
      case AnnouncementCategory.maintenance:
        return Icons.build_outlined;
      case AnnouncementCategory.security:
        return Icons.shield_outlined;
      case AnnouncementCategory.community:
        return Icons.groups_outlined;
      case AnnouncementCategory.emergency:
        return Icons.warning_amber_rounded;
      case AnnouncementCategory.general:
        return Icons.info_outline_rounded;
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
