import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/complaint.dart';
import '../controllers/complaint_controller.dart';
import '../widgets/complaint_widgets.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

class ComplaintsPage extends GetView<ComplaintController> {
  const ComplaintsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Complaints',
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
              96,
            ),
            children: [
              AppHeroPanel(
                icon: Icons.support_agent_rounded,
                title: 'Complaints',
                subtitle:
                    '${controller.openCount} open of '
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
      floatingActionButton: _FileComplaintFab(
        onPressed: () => Get.toNamed(AppRoutes.complaintCreate),
      ),
    );
  }
}

/// The floating call to action on the complaints list.
///
/// Filing a complaint is the one thing a resident comes here to do, so it gets a
/// branded pill that rises into place once and answers the finger with a small
/// dip. The widget underneath is still a [FloatingActionButton], so the tap
/// target, ripple and accessibility stay exactly as the platform defines them.
class _FileComplaintFab extends StatefulWidget {
  const _FileComplaintFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_FileComplaintFab> createState() => _FileComplaintFabState();
}

class _FileComplaintFabState extends State<_FileComplaintFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A gradient rather than a flat fill, so the button reads as raised off the
    // list instead of painted onto it.
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17A396), AppPalette.brandDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.brand.withValues(alpha: 0.34),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        key: const Key('file-complaint'),
        onPressed: widget.onPressed,
        // The wrapper draws the fill and the shadow, so the button itself only
        // needs to lay its content out and keep the ripple.
        backgroundColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.fromLTRB(18, 15, 22, 15),
        icon: const Icon(Icons.add_comment_rounded, size: 20),
        label: const Text(
          'File complaint',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0, 0.65, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
            ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(
            CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
          ),
          // Pointer events rather than a gesture, so the dip cannot fight the
          // button's own tap handling.
          child: Listener(
            onPointerDown: (_) => _setPressed(true),
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: AnimatedScale(
              scale: _pressed ? 0.95 : 1,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: pill,
            ),
          ),
        ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${complaint.reference} · ${complaint.category.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppPalette.muted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ComplaintStatusPill(status: complaint.status),
                    const SizedBox(width: 8),
                    // Flexible so a long date cannot push the row past the card.
                    Expanded(
                      child: Text(
                        'Updated ${complaint.updatedOn}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.faint,
                          fontSize: 10,
                        ),
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
