import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../domain/entities/maintenance_request.dart';

class MaintenanceStatusBadge extends StatelessWidget {
  const MaintenanceStatusBadge({required this.status, super.key});

  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    // Assigned, in progress and completed carry meaning, so those colours stay
    // fixed. Submitted has no colour of its own, so it borrows the neutral one.
    final (label, color) = switch (status) {
      MaintenanceStatus.submitted => ('Submitted', tokens.mutedStrong),
      MaintenanceStatus.assigned => ('Assigned', Color(0xFF5B4CC4)),
      MaintenanceStatus.inProgress => ('In Progress', Color(0xFFB45309)),
      MaintenanceStatus.completed => ('Completed', Color(0xFF087F5B)),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
