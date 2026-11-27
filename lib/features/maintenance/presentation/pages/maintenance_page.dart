import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:test/core/widgets/app_detail_app_bar.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/widgets/app_card.dart';

import '../../../../core/widgets/app_primary_action.dart';

import '../../../../core/widgets/app_section.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../../../core/widgets/app_status_pill.dart';

import '../../domain/entities/maintenance_request.dart';

import '../controllers/maintenance_controller.dart';

import '../widgets/maintenance_status_badge.dart';

class MaintenancePage extends GetView<MaintenanceController> {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold( 
      appBar: AppDetailAppBar(
        title: 'Maintenance',
        actions: [
          IconButton(
            onPressed: controller.refreshRequests,
            tooltip: 'Refresh Maintenance',
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(
          () => controller.isLoading.value && controller.requests.isEmpty
              ? Center(child: CircularProgressIndicator())
              // : controller.requests.isEmpty
              // ? AppStateMessage(
              //     title: 'No maintenance requests yet',
              //     message:
              //         'You haven’t submitted any maintenance requests. '
              //         'When you do, they’ll appear here.',
              //     icon: Icons.handyman_outlined,
              //     actionLabel: 'Try again',
              //     onAction: controller.loadRequests,
              //   )
              // : 
              :RefreshIndicator(
                  onRefresh: controller.refreshRequests,
                  child: ListView(
                    key: Key('maintenance-scroll'),
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      AppHeroPanel(
                        icon: Icons.handyman_rounded,
                        title: 'Maintenance summary',
                        subtitle:
                            '${controller.inProgressCount} in progress  '
                            '${controller.completedCount} completed',
                        footnote: 'Our team reviews every request and keeps you posted.',
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: tokens.brandOnDark,
                        ),
                      ),
                      18.h.heightBox(),
                      AppPrimaryAction(
                        key: Key('add-maintenance-request'),
                        onPressed: () =>
                            Get.toNamed(AppRoutes.maintenanceCreate),
                        label: 'New Maintenance Request',
                        icon: Icons.handyman_rounded,
                        trailingIcon: Icons.arrow_forward_rounded,
                        centerContent: false,
                      ),
                      25.h.heightBox(),
                      AppSectionHeader(
                        title: 'Your requests',
                        count: controller.requests.length,
                      ),
                      10.h.heightBox(),
                      if (controller.requests.isEmpty)
                        AppStateMessage(
                          title: 'No requests',
                          message: 'Create a request and our team will take it from there.',
                        )
                      else
                        ...controller.requests.map(
                          (request) => Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: _RequestCard(request: request),
                          ),
                        ),
                      if (controller.hasMore) ...[
                        12.h.heightBox(),
                        Center(
                          child: controller.isLoadingMore.value
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton(
                                  onPressed: controller.loadMore,
                                  child: Text('Load more requests'),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _MaintenanceHeader extends StatelessWidget {
  const _MaintenanceHeader({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintenance',
                style: TextStyle(
                  fontSize: 25.sp,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
              4.h.heightBox(),
              Text(
                'Keep your home running smoothly',
                style: TextStyle(color: tokens.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh maintenance requests',
          icon: Icon(Icons.refresh_rounded, color: tokens.muted),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      onTap: () {
        vibrateNow();
        Get.find<MaintenanceController>().selectRequest(request);
        Get.toNamed(AppRoutes.maintenanceDetail, arguments: request);
      },
      borderRadius: 18,
      child: Row(
        children: [
          AppIconTile(icon: Icons.build_circle_outlined, color: tokens.brand),
          12.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: TextStyle(
                    color: tokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                4.h.heightBox(),
                Text(
                  '${request.categoryDisplay}  ${request.priority.label}',
                  style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                ),
                4.h.heightBox(),
                Text(
                  request.createdAtDisplay,
                  style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                ),
                if (request.resolvedPhotoCount > 0) ...[
                  4.h.heightBox(),
                  Text(
                    request.resolvedPhotoCount == 1
                        ? '1 photo'
                        : '${request.resolvedPhotoCount} photos',
                    style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MaintenanceStatusBadge(status: request.status),
              8.h.heightBox(),
              Icon(Icons.chevron_right_rounded, color: tokens.faint),
            ],
          ),
        ],
      ),
    );
  }
}
