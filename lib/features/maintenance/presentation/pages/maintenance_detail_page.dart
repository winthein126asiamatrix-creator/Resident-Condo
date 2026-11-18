import 'dart:async';

import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../domain/entities/maintenance_request.dart';
import '../controllers/maintenance_controller.dart';
import '../widgets/maintenance_status_badge.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_image_preview.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../../core/widgets/app_step_progress.dart';

class MaintenanceDetailPage extends StatefulWidget {
  const MaintenanceDetailPage({required this.request, super.key});

  final MaintenanceRequest request;

  @override
  State<MaintenanceDetailPage> createState() => _MaintenanceDetailPageState();
}

class _MaintenanceDetailPageState extends State<MaintenanceDetailPage> {
  MaintenanceController get controller => Get.find<MaintenanceController>();
  Timer? _cancelEligibilityTimer;

  @override
  void initState() {
    super.initState();
    controller.selectRequest(widget.request);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadSelectedRequestDetail();
    });
    _cancelEligibilityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cancelEligibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.selectedRequest.value ?? widget.request;
      final tokens = AppThemeTokens.of(context);

      return Scaffold(
        appBar: AppDetailAppBar(title: 'Request details'),
        body: ListView(
          key: Key('maintenance-detail-scroll'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32,
          ),
          children: [
            if (controller.isLoadingDetail.value) ...[
              LinearProgressIndicator(),
              12.h.heightBox(),
            ],
            if (controller.detailError.value != null) ...[
              Text(
                controller.detailError.value!,
                style: TextStyle(color: AppPalette.danger),
              ),
              12.h.heightBox(),
            ],
            _DetailHero(request: current),
            20.h.heightBox(),
            _Section(
              title: 'Request information',
              child: Column(
                children: [
                  if (current.reference.isNotEmpty)
                    _Line(label: 'Reference', value: current.reference),
                  _Line(label: 'Category', value: current.categoryDisplay),
                  _Line(label: 'Location', value: current.location),
                  if (current.unit.isNotEmpty)
                    _Line(label: 'Unit', value: current.unit),
                  _Line(label: 'Priority', value: current.priority.label),
                  _Line(label: 'Submitted', value: current.createdAtDisplay),
                  _Line(
                    label: 'Preferred time',
                    value:
                        '${current.preferredDateDisplay} '
                        '${current.preferredTimeDisplay}',
                  ),
                  _Line(
                    label: 'Assigned technician',
                    value: current.technician ?? 'Awaiting assignment',
                  ),
                  if (current.completedAtDisplay != null)
                    _Line(
                      label: 'Completed',
                      value: current.completedAtDisplay!,
                    ),
                  if (current.cancelledAtDisplay != null)
                    _Line(
                      label: 'Cancelled',
                      value: current.cancelledAtDisplay!,
                    ),
                ],
              ),
            ),
            16.h.heightBox(),
            _Section(
              title: 'Description',
              child: Text(
                current.description,
                style: TextStyle(color: tokens.mutedStrong, height: 1.4),
              ),
            ),
            16.h.heightBox(),
            _Section(
              title: current.photos.isEmpty ? 'Attachments' : 'Attachment',
              child: current.photos.isEmpty
                  ? Text(
                      'No photos attached',
                      style: TextStyle(color: tokens.muted),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < current.photos.length;
                          index++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == current.photos.length - 1
                                  ? 0
                                  : 12,
                            ),
                            child: AppImagePreview(
                              key: Key('request-photo-$index'),
                              path: current.photos[index].url,
                              caption: _photoCaption(current, index),
                            ),
                          ),
                      ],
                    ),
            ),
            20.h.heightBox(),
            _StatusProgress(request: current),
            if (controller.canCancelRequest(current)) ...[
              20.h.heightBox(),
              AppPrimaryAction(
                key: Key('cancel-maintenance-request'),
                onPressed: controller.isCancelling.value
                    ? null
                    : () => _cancelRequest(current),
                isLoading: controller.isCancelling.value,
                label: 'Cancel request',
                icon: Icons.cancel_outlined,
                backgroundColor: AppPalette.danger,
              ),
            ],
          ],
        ),
      );
    });
  }

  String _photoCaption(MaintenanceRequest request, int index) {
    final caption = request.photos[index].caption.trim();
    return caption.isEmpty ? 'Attached photo ${index + 1}' : caption;
  }

  Future<void> _cancelRequest(MaintenanceRequest request) async {
    if (controller.isCancelling.value) return;
    if (!controller.canCancelRequest(request)) {
      Get.snackbar(
        'Cannot cancel',
        'This request can no longer be cancelled.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _CancelReasonDialog(requestTitle: request.title),
    );

    if (reason == null) return;
    if (reason.isEmpty) {
      Get.snackbar(
        'Reason required',
        'Please tell us why the request should be cancelled.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final cancelled = await controller.cancelRequest(request, reason);
    if (!cancelled) return;
    if (!mounted) return;
    Get.snackbar(
      'Request cancelled',
      'The maintenance team has been notified.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.request});

  final MaintenanceRequest request;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MAINTENANCE REQUEST',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              MaintenanceStatusBadge(status: request.status),
            ],
          ),
          16.h.heightBox(),
          Text(
            request.title,
            style: TextStyle(
              color: tokens.brandOnDark,
              fontSize: 21.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          6.h.heightBox(),
          Text(
            '${request.categoryDisplay}  ${request.priority.label}',
            style: TextStyle(color: tokens.brandOnDarkMuted, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
          ),
          8.h.heightBox(),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: tokens.muted)),
          ),
          12.w.widthBox(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusProgress extends StatelessWidget {
  const _StatusProgress({required this.request});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final status = request.status;
    final history = request.progressHistory;

    late final List<AppProgressStep> steps;
    late final int currentIndex;

    if (status == MaintenanceStatus.cancelled) {
      steps = history
          .where((entry) => entry.status != MaintenanceStatus.cancelled)
          .map(
            (entry) => AppProgressStep(
              title: entry.displayLabel,
              subtitle: entry.note?.trim().isNotEmpty == true
                  ? entry.note
                  : entry.createdAt,
            ),
          )
          .toList();
      if (steps.isEmpty) {
        steps.add(
          AppProgressStep(
            title: MaintenanceStatus.submitted.label,
            subtitle: request.createdAtDisplay,
          ),
        );
      }
      steps.add(
        AppProgressStep(
          title: MaintenanceStatus.cancelled.label,
          subtitle: request.cancelledAtDisplay,
        ),
      );
      currentIndex = steps.length - 1;
    } else if (history.isNotEmpty) {
      steps = history
          .map(
            (entry) => AppProgressStep(
              title: entry.displayLabel,
              subtitle: entry.note?.trim().isNotEmpty == true
                  ? entry.note
                  : entry.createdAt,
            ),
          )
          .toList();
      currentIndex = steps.length;
    } else {
      steps = <AppProgressStep>[
        for (final step in MaintenanceStatus.values)
          if (step != MaintenanceStatus.cancelled)
            AppProgressStep(
              title: step.label,
              subtitle: step == MaintenanceStatus.submitted
                  ? request.createdAtDisplay
                  : (step.index < status.index ? 'Completed' : null),
            ),
      ];
      currentIndex = status == MaintenanceStatus.completed
          ? steps.length
          : status.index;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request progress',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
          ),
          16.h.heightBox(),
          AppStepProgress(steps: steps, currentIndex: currentIndex),
        ],
      ),
    );
  }
}

class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog({required this.requestTitle});

  final String requestTitle;

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel this request?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are cancelling "${widget.requestTitle}". '
            'Tell us why it is no longer needed.',
          ),
          12.h.heightBox(),
          TextField(
            controller: _reasonController,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Tell us why this request is no longer needed.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep request'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_reasonController.text.trim()),
          child: const Text('Cancel request'),
        ),
      ],
    );
  }
}
