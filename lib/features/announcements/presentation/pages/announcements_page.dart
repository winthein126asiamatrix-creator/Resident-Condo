import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/announcement.dart';
import '../controllers/announcement_controller.dart';
import '../widgets/announcement_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';

class AnnouncementsPage extends GetView<AnnouncementController> {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Announcements',
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
        if (controller.isLoading.value && controller.announcements.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.announcements.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load announcements',
            message: controller.errorMessage.value!,
            icon: Icons.campaign_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadAnnouncements,
          );
        }
        final visible = controller.visibleAnnouncements;
        return RefreshIndicator(
          onRefresh: controller.loadAnnouncements,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.pageTop, AppSpacing.gutter, 32),
            children: [
              _AnnouncementSummary(
                unreadCount: controller.unreadCount,
                totalCount: controller.announcements.length,
              ),
              const SizedBox(height: 18),
              const Text(
                'Filter by category',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 9),
              _CategoryFilters(controller: controller),
              const SizedBox(height: 20),
              if (visible.isEmpty)
                const AppStateMessage(
                  title: 'No announcements',
                  message: 'There are no announcements in this category.',
                  icon: Icons.campaign_outlined,
                )
              else
                ...visible.map(
                  (announcement) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnnouncementCard(
                      announcement: announcement,
                      onTap: () => controller.markAsRead(announcement),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _AnnouncementSummary extends StatelessWidget {
  const _AnnouncementSummary({
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
              Icons.campaign_rounded,
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
                  'Stay in the loop',
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
                      : '$unreadCount unread announcements',
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

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({required this.controller});

  final AnnouncementController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: controller.selectedCategory.value == null,
            onSelected: (_) => controller.selectCategory(null),
                selectedColor: tokens.brandOnDark,
          ),
          const SizedBox(width: 8),
          ...AnnouncementCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.label),
                selected: controller.selectedCategory.value == category,
                onSelected: (_) => controller.selectCategory(category),
            selectedColor: tokens.brandOnDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
