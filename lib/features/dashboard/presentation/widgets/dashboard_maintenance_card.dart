import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../maintenance/domain/entities/maintenance_request.dart';
import '../../../maintenance/presentation/widgets/maintenance_status_badge.dart';

class DashboardMaintenanceCard extends StatelessWidget {
  const DashboardMaintenanceCard({
    required this.requests,
    required this.inProgress,
    required this.completed,
    this.isLoading = false,
    this.isShowingCachedData = false,
    this.errorMessage,
    this.onRetry,
    this.onRequestTap,
    super.key,
  });

  static const int maxRequests = 2;

  final List<MaintenanceRequest> requests;
  final int inProgress;
  final int completed;
  final bool isLoading;
  final bool isShowingCachedData;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<MaintenanceRequest>? onRequestTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final visible = requests.take(maxRequests).toList();
    return Container(
      key: const Key('dashboard-maintenance-card'),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isShowingCachedData && visible.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'Showing saved maintenance data. Pull to refresh.',
                style: TextStyle(fontSize: 11.sp, color: tokens.muted),
              ),
            ),
          if (isLoading && requests.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (errorMessage != null && requests.isEmpty)
            _Message(
              icon: Icons.cloud_off_rounded,
              message: errorMessage!,
              actionLabel: onRetry == null ? null : 'Try again',
              onAction: onRetry,
            )
          else if (requests.isEmpty)
            const _Message(
              icon: Icons.handyman_outlined,
              message: 'No maintenance requests yet',
            )
          else
            ...visible.map(
              (request) => GestureDetector(
                key: Key('dashboard-maintenance-request-${request.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onRequestTap == null ? null : () => onRequestTap!(request),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 15, 16, 15),
                  child: Row(
                    children: [
                      Icon(Icons.build_circle_outlined, color: tokens.brand),
                      12.w.widthBox(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.title,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            3.h.heightBox(),
                            Text(
                              '${request.categoryDisplay}  ${request.priority.label}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: tokens.muted,
                              ),
                            ),
                            if (request.reference.isNotEmpty ||
                                request.createdAtDisplay.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Text(
                                  [
                                    if (request.reference.isNotEmpty)
                                      request.reference,
                                    request.createdAtDisplay,
                                  ].where((part) => part.trim().isNotEmpty).join(
                                    '  ·  ',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: tokens.faint,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      MaintenanceStatusBadge(status: request.status),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(19.r),
              ),
            ),
            child: Text(
              '$inProgress in progress  ·  $completed completed',
              style: TextStyle(
                fontSize: 12.sp,
                color: tokens.mutedStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 28, color: tokens.muted),
          8.h.heightBox(),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: tokens.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            8.h.heightBox(),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
