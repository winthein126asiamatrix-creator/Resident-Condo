import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/complaint.dart';
import '../controllers/complaint_controller.dart';
import '../widgets/complaint_widgets.dart';

class ComplaintsPage extends GetView<ComplaintController> {
  const ComplaintsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        actions: [
          IconButton(
            onPressed: controller.loadComplaints,
            tooltip: 'Refresh complaints',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.complaints.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.complaints.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load complaints',
            message: controller.errorMessage.value!,
            icon: Icons.report_problem_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadComplaints,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadComplaints,
          child: ListView(
            key: const Key('complaints-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              AppHeroPanel(
                icon: Icons.support_agent_rounded,
                title: 'Complaints',
                subtitle: '${controller.openCount} open of '
                    '${controller.complaints.length} filed',
                footnote:
                    'Complaints are your reports to management. Rule breaks are '
                    'tracked separately under Rules & violations.',
                trailing: IconButton(
                  tooltip: 'Refresh complaints',
                  onPressed: controller.loadComplaints,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              AppSectionHeader(
                title: 'Open complaints',
                count: controller.openComplaints.length,
              ),
              const SizedBox(height: 10),
              if (controller.openComplaints.isEmpty)
                const AppStateMessage(
                  title: 'Nothing open',
                  message: 'You have no open complaints.',
                  icon: Icons.check_circle_outline_rounded,
                )
              else
                for (final complaint in controller.openComplaints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ComplaintCard(
                      controller: controller,
                      complaint: complaint,
                    ),
                  ),
              if (controller.closedComplaints.isNotEmpty) ...[
                const SizedBox(height: 16),
                AppSectionHeader(
                  title: 'Closed',
                  count: controller.closedComplaints.length,
                ),
                const SizedBox(height: 10),
                for (final complaint in controller.closedComplaints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ComplaintCard(
                      controller: controller,
                      complaint: complaint,
                    ),
                  ),
              ],
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('file-complaint'),
        onPressed: () => Get.toNamed(AppRoutes.complaintCreate),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('File complaint'),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.controller, required this.complaint});
  final ComplaintController controller;
  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        controller.selectComplaint(complaint);
        Get.toNamed(AppRoutes.complaintDetail, arguments: complaint);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconTile(
            icon: Icons.report_gmailerrorred_outlined,
            color: complaintStatusColor(complaint.status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.subject,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${complaint.reference} · ${complaint.category.label}',
                  style: const TextStyle(color: AppPalette.muted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ComplaintStatusPill(status: complaint.status),
                    const SizedBox(width: 8),
                    Text(
                      'Updated ${complaint.updatedOn}',
                      style: const TextStyle(
                        color: AppPalette.faint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppPalette.faint),
        ],
      ),
    );
  }
}
