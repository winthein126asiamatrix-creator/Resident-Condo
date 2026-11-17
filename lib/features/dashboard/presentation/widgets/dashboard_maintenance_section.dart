import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../maintenance/domain/entities/maintenance_request.dart';
import '../../../maintenance/presentation/controllers/maintenance_controller.dart';
import '../widgets/dashboard_maintenance_card.dart';
import 'section_header.dart';

class DashboardMaintenanceSection extends StatelessWidget {
  const DashboardMaintenanceSection({required this.onViewAll, super.key});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final maintenance = Get.isRegistered<MaintenanceController>()
        ? Get.find<MaintenanceController>()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          key: const Key('dashboard-maintenance-section'),
          title: 'Maintenance',
          actionLabel: 'View all',
          onAction: onViewAll,
        ),
        10.h.heightBox(),
        Obx(() {
          return DashboardMaintenanceCard(
            requests: maintenance?.requests ?? <MaintenanceRequest>[],
            inProgress: maintenance?.inProgressCount ?? 0,
            completed: maintenance?.completedCount ?? 0,
            isLoading: maintenance?.isLoading.value ?? false,
            isShowingCachedData:
                maintenance?.isShowingCachedData.value ?? false,
            errorMessage: maintenance?.errorMessage.value,
            onRetry: maintenance?.loadRequests,
            onRequestTap: maintenance == null
                ? null
                : (request) {
                    vibrateNow();
                    maintenance.selectRequest(request);
                    Get.toNamed(
                      AppRoutes.maintenanceDetail,
                      arguments: request,
                    );
                  },
          );
        }),
      ],
    );
  }
}
