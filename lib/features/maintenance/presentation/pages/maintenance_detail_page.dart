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
            // if (controller.isLoadingDetail.value) ...[
            //   LinearProgressIndicator(),
            //   12.h.heightBox(),
            // ],
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
                    value: current.technician ?? '',
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

  /// The happy path, in order. Cancelled is a terminal alternative rather than
  /// a fifth step, so it is never appended after Completed.
  static const List<MaintenanceStatus> _happyPath = <MaintenanceStatus>[
    MaintenanceStatus.submitted,
    MaintenanceStatus.assigned,
    MaintenanceStatus.inProgress,
    MaintenanceStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final status = request.status;
    final cancelled = status == MaintenanceStatus.cancelled;

    // The current status owns the step the user sees; history supplies the
    // date and time shown beside each status. The cancelled entry is kept
    // aside because cancellation is rendered as its own terminal state.
    MaintenanceProgressEntry? cancelledEntry;
    final history = <MaintenanceStatus, MaintenanceProgressEntry>{};
    for (final entry in request.progressHistory) {
      if (entry.status == MaintenanceStatus.cancelled) {
        cancelledEntry = entry;
      } else {
        history[entry.status] = entry;
      }
    }

    // `-1` leaves every happy-path step upcoming for a cancelled request.
    final currentIndex = cancelled ? -1 : _indexFor(status);

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
          for (var index = 0; index < _happyPath.length; index++)
            _ProgressStepRow(
              position: index,
              title: _happyPath[index].label,
              // A cancelled request has no reached happy-path step, so dated
              // subtitles would imply progress that did not happen.
              subtitle: cancelled
                  ? null
                  : _subtitleFor(_happyPath[index], history[_happyPath[index]]),
              state: _stateFor(index, currentIndex),
              isLast: index == _happyPath.length - 1,
            ),
          if (cancelled) ...[
            14.h.heightBox(),
            _CancelledNotice(
              subtitle:
                  cancelledEntry?.occurredAtDisplay ??
                  request.statusTimestampDisplay(MaintenanceStatus.cancelled),
            ),
          ],
        ],
      ),
    );
  }

  static int _indexFor(MaintenanceStatus status) {
    final index = _happyPath.indexOf(status);
    // An unexpected value renders the first step instead of throwing.
    return index < 0 ? 0 : index;
  }

  static _StepState _stateFor(int index, int currentIndex) {
    if (index < currentIndex) return _StepState.completed;
    if (index == currentIndex) return _StepState.current;
    return _StepState.upcoming;
  }

  String? _subtitleFor(
    MaintenanceStatus step,
    MaintenanceProgressEntry? entry,
  ) {
    // Prefer the progress history, then fall back to the workflow fields a
    // list response carries (`created_at`, `assigned_at`, ...). A missing or
    // unparseable timestamp leaves the line empty instead of guessing.
    final occurredAt =
        entry?.occurredAtDisplay ?? request.statusTimestampDisplay(step);
    if (occurredAt != null) return occurredAt;

    final note = entry?.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    return null;
  }
}

enum _StepState { completed, current, upcoming }

/// One row of the vertical progress timeline: a circle on the left, the status
/// label, and the date and time it happened on the right.
class _ProgressStepRow extends StatelessWidget {
  const _ProgressStepRow({
    required this.position,
    required this.title,
    required this.state,
    required this.subtitle,
    required this.isLast,
  });

  final int position;
  final String title;
  final _StepState state;
  final String? subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isDone = state == _StepState.completed;
    final isCurrent = state == _StepState.current;

    final background = isDone
        ? tokens.brand
        : isCurrent
        ? tokens.brandTint
        : tokens.surface;
    final foreground = isDone
        ? tokens.onBrand
        : isCurrent
        ? tokens.brand
        : tokens.mutedStrong;

    // State is spelled out for a screen reader as well as shown, so it never
    // depends on seeing the colour.
    final stateWord = switch (state) {
      _StepState.completed => 'completed',
      _StepState.current => 'current step',
      _StepState.upcoming => 'not started',
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Semantics(
                  label:
                      '${isDone ? 'Done' : 'Step ${position + 1}'}, $stateWord',
                  child: Container(
                    key: Key('progress-step-$position'),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone || isCurrent
                            ? tokens.brand
                            : tokens.border,
                        width: isCurrent ? 2 : 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: tokens.onBrand,
                          )
                        : Text(
                            '${position + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 12.sp,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone ? tokens.brand : tokens.border,
                        borderRadius: BorderRadius.circular(1.r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          12.w.widthBox(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isDone || isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: state == _StepState.upcoming
                            ? tokens.muted
                            : tokens.ink,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    12.w.widthBox(),
                    Flexible(
                      child: Text(
                        subtitle!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: tokens.faint,
                          fontSize: 12.sp,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice({this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_rounded, size: 18, color: AppPalette.danger),
          10.w.widthBox(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    MaintenanceStatus.cancelled.label,
                    style: TextStyle(
                      color: AppPalette.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  12.w.widthBox(),
                  Flexible(
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppPalette.danger.withValues(alpha: 0.8),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
