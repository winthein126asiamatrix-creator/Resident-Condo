import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/maintenance_request.dart';
import '../controllers/maintenance_controller.dart';
import '../widgets/maintenance_status_badge.dart';

class MaintenancePage extends GetView<MaintenanceController> {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                    children: [
                      _MaintenanceHeader(onRefresh: controller.loadRequests),
                      const SizedBox(height: 20),
                      _MaintenanceSummary(
                        inProgress: controller.inProgressCount,
                        completed: controller.completedCount,
                      ),
                      const SizedBox(height: 25),
                      _SectionHeader(
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-maintenance-request'),
        onPressed: () => Get.toNamed(AppRoutes.maintenanceCreate),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
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
                  color: Color(0xFF1D2B2A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Keep your home running smoothly',
                style: TextStyle(color: Color(0xFF71807D)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh maintenance requests',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _MaintenanceSummary extends StatelessWidget {
  const _MaintenanceSummary({
    required this.inProgress,
    required this.completed,
  });
  final int inProgress;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F766E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
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
            child: const Icon(
              Icons.handyman_rounded,
              color: Color(0xFFBFE8DF),
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Maintenance summary',
                  style: TextStyle(
                    color: Color(0xFFBFE8DF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$inProgress in progress  ·  $completed completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFBFE8DF)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1D2B2A),
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F3EF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
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
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.maintenanceDetail, arguments: request),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EEEB)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F3EF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.build_circle_outlined,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${request.category.label} · ${request.priority.label}',
                    style: const TextStyle(
                      color: Color(0xFF71807D),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.createdAt,
                    style: const TextStyle(
                      color: Color(0xFF9AA9A5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MaintenanceStatusBadge(status: request.status),
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9AA9A5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
