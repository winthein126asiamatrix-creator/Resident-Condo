import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
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
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: SafeArea(
        child: Obx(
          () => controller.isLoading.value && controller.requests.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : controller.errorMessage.value != null &&
                    controller.requests.isEmpty
              ? AppStateMessage(
                  title: 'Unable to load maintenance',
                  message: controller.errorMessage.value!,
                  icon: Icons.handyman_outlined,
                  actionLabel: 'Try again',
                  onAction: controller.loadRequests,
                )
              : RefreshIndicator(
                  onRefresh: controller.loadRequests,
                  child: ListView(
                    key: const Key('maintenance-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      _MaintenanceHeader(onRefresh: controller.loadRequests),
                      const SizedBox(height: 20),
                      AppHeroPanel(
                        icon: Icons.handyman_rounded,
                        title: 'Maintenance summary',
                        subtitle:
                            '${controller.inProgressCount} in progress  ·  '
                            '${controller.completedCount} completed',
                        footnote: 'Our team reviews every request and keeps you posted.',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppPalette.brandOnDark,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppPrimaryAction(
                        key: const Key('add-maintenance-request'),
                        onPressed: () =>
                            Get.toNamed(AppRoutes.maintenanceCreate),
                        label: 'New Maintenance Request',
                        icon: Icons.handyman_rounded,
                        trailingIcon: Icons.arrow_forward_rounded,
                        centerContent: false,
                      ),
                      const SizedBox(height: 25),
                      AppSectionHeader(
                        title: 'Your requests',
                        count: controller.requests.length,
                      ),
                      const SizedBox(height: 10),
                      if (controller.requests.isEmpty)
                        const AppStateMessage(
                          title: 'No requests',
                          message: 'Create a request and our team will take it from there.',
                          icon: Icons.handyman_outlined,
                        )
                      else
                        ...controller.requests.map(
                          (request) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RequestCard(request: request),
                          ),
                        ),
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
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintenance',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Keep your home running smoothly',
                style: TextStyle(color: AppPalette.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh maintenance requests',
          icon: const Icon(Icons.refresh_rounded, color: AppPalette.muted),
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
    return AppCard(
      onTap: () => Get.toNamed(AppRoutes.maintenanceDetail, arguments: request),
      borderRadius: 18,
      child: Row(
        children: [
          const AppIconTile(
            icon: Icons.build_circle_outlined,
            color: AppPalette.brand,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${request.category.label} · ${request.priority.label}',
                  style: const TextStyle(color: AppPalette.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  request.createdAt,
                  style: const TextStyle(color: AppPalette.faint, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MaintenanceStatusBadge(status: request.status),
              const SizedBox(height: 8),
              const Icon(Icons.chevron_right_rounded, color: AppPalette.faint),
            ],
          ),
        ],
      ),
    );
  }
}
