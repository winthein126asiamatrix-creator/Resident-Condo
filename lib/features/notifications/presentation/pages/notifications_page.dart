import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../domain/entities/notification_item.dart';

import '../controllers/notification_controller.dart';

import '../widgets/notification_item_card.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/theme/app_theme_tokens.dart';

class NotificationsPage extends GetView<NotificationController> {
  NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Notifications',
        actions: [
          Obx(
            () => TextButton(
              onPressed:
                  controller.unreadCount == 0 || controller.isUpdating.value
                  ? null
                  : controller.markAllAsRead,
              child: Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.notifications.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.notifications.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load notifications',
            message: controller.errorMessage.value!,
            icon: Icons.notifications_none_rounded,
            actionLabel: 'Try again',
            onAction: controller.loadNotifications,
          );
        }
        if (controller.notifications.isEmpty) {
          return AppStateMessage(
            title: 'You are all caught up',
            message: 'New resident updates will appear here.',
            icon: Icons.notifications_none_rounded,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadNotifications,
          child: ListView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
              32,
            ),
            children: [
              Obx(
                () => controller.isShowingCachedData.value
                    ? const _OfflineNotice()
                    : const SizedBox.shrink(),
              ),
              _NotificationSummary(
                unreadCount: controller.unreadCount,
                totalCount: controller.notifications.length,
              ),
              22.h.heightBox(),
              for (final period in NotificationPeriod.values) ...[
                if (controller.notificationsFor(period).isNotEmpty) ...[
                  Text(
                    period.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.sp,
                    ),
                  ),
                  10.h.heightBox(),
                  ...controller
                      .notificationsFor(period)
                      .map(
                        (item) => Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: NotificationItemCard(
                            item: item,
                            onTap: () {
                              vibrateNow();
                              controller.markAsRead(item);
                            },
                          ),
                        ),
                      ),
                  12.h.heightBox(),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// Says the list on screen came from this device rather than the backend.
///
/// Without it a resident who is offline sees their notifications and cannot tell
/// them apart from current ones. Uses the same tokens as the rest of the screen
/// so it reads as part of the page rather than an alert bolted on.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18.r, color: tokens.muted),
            10.w.widthBox(),
            Expanded(
              child: Text(
                'Showing your saved notifications. Pull down to try again.',
                style: TextStyle(color: tokens.muted, fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  _NotificationSummary({required this.unreadCount, required this.totalCount});

  final int unreadCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: tokens.heroShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17.r),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: tokens.brandOnDark,
              size: 27,
            ),
          ),
          14.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your updates',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                6.h.heightBox(),
                Text(
                  unreadCount == 0
                      ? 'You are all caught up'
                      : '$unreadCount unread updates',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$totalCount total',
            style: TextStyle(color: tokens.brandOnDark, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}
