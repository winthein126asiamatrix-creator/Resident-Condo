import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/notification_item.dart';
import '../controllers/notification_controller.dart';
import '../widgets/notification_item_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';

class NotificationsPage extends GetView<NotificationController> {
  const NotificationsPage({super.key});

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
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
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
          return const AppStateMessage(
            title: 'You are all caught up',
            message: 'New resident updates will appear here.',
            icon: Icons.notifications_none_rounded,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadNotifications,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.pageTop, AppSpacing.gutter, 32),
            children: [
              _NotificationSummary(
                unreadCount: controller.unreadCount,
                totalCount: controller.notifications.length,
              ),
              const SizedBox(height: 22),
              for (final period in NotificationPeriod.values) ...[
                if (controller.notificationsFor(period).isNotEmpty) ...[
                  Text(
                    period.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...controller
                      .notificationsFor(period)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NotificationItemCard(
                            item: item,
                            onTap: () => controller.markAsRead(item),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.unreadCount,
    required this.totalCount,
  });

  final int unreadCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(22),
        boxShadow: tokens.heroShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: tokens.brandOnDark,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your updates',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  unreadCount == 0
                      ? 'You are all caught up'
                      : '$unreadCount unread updates',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$totalCount total',
            style: TextStyle(color: tokens.brandOnDark, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
