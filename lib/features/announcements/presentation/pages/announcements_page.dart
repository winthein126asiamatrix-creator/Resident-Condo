import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/announcement.dart';
import '../controllers/announcement_controller.dart';
import '../widgets/announcement_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';

class AnnouncementsPage extends GetView<AnnouncementController> {
  AnnouncementsPage({super.key});

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
              child: Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.announcements.isEmpty) {
          return Center(child: CircularProgressIndicator());
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
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.pageTop, AppSpacing.gutter, 32),
            children: [
              _AnnouncementSummary(
                unreadCount: controller.unreadCount,
                totalCount: controller.announcements.length,
              ),
              SizedBox(height: 18.h),
              Text(
                'Filter by category',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
              ),
              SizedBox(height: 9.h),
              _CategoryFilters(controller: controller),
              SizedBox(height: 20.h),
              if (visible.isEmpty)
                AppStateMessage(
                  title: 'No announcements',
                  message: 'There are no announcements in this category.',
                  icon: Icons.campaign_outlined,
                )
              else
                ...visible.map(
                  (announcement) => Padding(
                    padding: EdgeInsets.only(bottom: 10),
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
  _AnnouncementSummary({
    required this.unreadCount,
    required this.totalCount,
  });

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
              Icons.campaign_rounded,
              color: tokens.brandOnDark,
              size: 27,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay in the loop',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  unreadCount == 0
                      ? 'You are all caught up'
                      : '$unreadCount unread announcements',
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

class _CategoryFilters extends StatelessWidget {
  _CategoryFilters({required this.controller});

  final AnnouncementController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All'),
            selected: controller.selectedCategory.value == null,
            onSelected: (_) => controller.selectCategory(null),
                selectedColor: tokens.brandOnDark,
          ),
          SizedBox(width: 8.w),
          ...AnnouncementCategory.values.map(
            (category) => Padding(
              padding: EdgeInsets.only(right: 8),
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
