import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


import '../../domain/entities/announcement.dart';


import '../../../../core/theme/app_theme_tokens.dart';

class AnnouncementCard extends StatelessWidget {
  AnnouncementCard({
    required this.announcement,
    required this.onTap,
    super.key,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = _colorFor(announcement.category, tokens);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: announcement.isRead
                ? tokens.border
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
                borderRadius: BorderRadius.circular(13.r),
              ),
              child: Icon(
                _iconFor(announcement.category),
                color: color,
                size: 21,
              ),
            ),
            12.w.widthBox(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!announcement.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tokens.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  6.h.heightBox(),
                  Text(
                    announcement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 12.sp,
                      height: 1.35,
                    ),
                  ),
                  10.h.heightBox(),
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
                  8.h.heightBox(),
                  Text(
                    announcement.date,
                    style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(AnnouncementCategory category, AppThemeTokens tokens) {
    switch (category) {
      case AnnouncementCategory.maintenance:
        return Color(0xFFB45309);
      case AnnouncementCategory.security:
        return Color(0xFF5B4CC4);
      case AnnouncementCategory.community:
        return tokens.brand;
      case AnnouncementCategory.emergency:
        return Color(0xFFC2410C);
      case AnnouncementCategory.general:
        return tokens.mutedStrong;
    }
  }

  Color _urgencyColor(AnnouncementUrgency urgency) {
    return urgency == AnnouncementUrgency.emergency
        ? Color(0xFFC2410C)
        : Color(0xFFB45309);
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
  _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
