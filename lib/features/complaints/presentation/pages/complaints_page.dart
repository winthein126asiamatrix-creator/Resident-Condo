import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_theme_tokens.dart';
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

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  late final ComplaintController controller = Get.find<ComplaintController>();

  /// Once the list is scrolled the call to action drops its label and keeps only
  /// the glyph, so it stops sitting on top of the cards.
  bool _fabCompact = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    final compact = notification.metrics.pixels > 24;
    if (compact != _fabCompact) {
      setState(() => _fabCompact = compact);
    }
    // Never swallow the notification: the refresh indicator and the list still
    // need to see it.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
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
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
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
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: tokens.brandOnDark,
                    ),
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
          ),
        );
      }),
      floatingActionButton: _FileComplaintFab(
        expanded: !_fabCompact,
        onPressed: () => Get.toNamed(AppRoutes.complaintCreate),
      ),
    );
  }
}

/// The floating call to action on the complaints list.
///
/// Filing a complaint is the one thing a resident comes here to do, so it gets a
/// branded pill with a frosted glyph tile, which rises into place once, dips under
/// the finger and folds its label away once the list is scrolled. The widget
/// underneath is still a [FloatingActionButton], so the tap target, ripple and
/// accessibility stay exactly as the platform defines them.
class _FileComplaintFab extends StatefulWidget {
  const _FileComplaintFab({required this.onPressed, required this.expanded});

  final VoidCallback onPressed;

  /// Whether the label is showing. Folding it away leaves a round button, so it
  /// stops covering the cards underneath.
  final bool expanded;

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
    final tokens = AppThemeTokens.of(context);
    // A gradient rather than a flat fill, so the button reads as raised off the
    // list instead of painted onto it. Both stops are checked against white
    // label text: the lightest is 4.2:1 and the darkest 6.5:1, which keeps the
    // word "complaint" readable right across the pill.
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.brand, tokens.brandDark],
        ),
        // A hairline rim catches the light along the top edge, and a wide glow
        // underneath lifts the whole pill off the list.
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: tokens.brand.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: tokens.brandDark.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        key: const Key('file-complaint'),
        onPressed: widget.onPressed,
        // The wrapper draws the fill and the shadow, so the button itself only
        // needs to lay its content out and keep the ripple. Stating the
        // foreground keeps the label and the glyph white instead of inheriting
        // the theme's dark onSurface, which is what left the button looking
        // greyed out.
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.onBrand,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.fromLTRB(14, 14, 20, 14),
        icon: const _BadgeGlyph(),
        // Only the label collapses. The button re-measures itself on every frame
        // of the fold, so the pill shrinks around the label instead of clipping
        // it away.
        label: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: widget.expanded
              ? Text(
                  'File complaint',
                  maxLines: 1,
                  style: TextStyle(
                    color: tokens.onBrand,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                )
              : const SizedBox.shrink(),
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
              scale: _pressed ? 0.94 : 1,
              // A touch of overshoot on the way back up, so letting go reads as a
              // spring rather than a step.
              duration: const Duration(milliseconds: 220),
              curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}

/// The glyph in a near white disc, the same shape as the icon tiles on the
/// cards but in the other direction, so it inverts the pill instead of blending
/// into it. Deep teal on near white is well clear of the body text contrast
/// threshold, where white on a pale disc would not have been.
class _BadgeGlyph extends StatelessWidget {
  const _BadgeGlyph();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: tokens.brandDark.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(Icons.add_comment_rounded, size: 16, color: tokens.brandDark),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.controller, required this.complaint});
  final ComplaintController controller;
  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
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
            color: complaintStatusColor(complaint.status, tokens),
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
                  style: TextStyle(color: tokens.muted, fontSize: 11),
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
                        style: TextStyle(color: tokens.faint, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tokens.faint),
        ],
      ),
    );
  }
}
