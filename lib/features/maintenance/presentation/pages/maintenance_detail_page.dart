import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../domain/entities/maintenance_request.dart';

import '../controllers/maintenance_controller.dart';

import '../widgets/maintenance_status_badge.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_image_preview.dart';

import '../../../../core/widgets/app_step_progress.dart';

class MaintenanceDetailPage extends GetView<MaintenanceController> {
  const MaintenanceDetailPage({required this.request, super.key});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = _currentRequest();
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
            _DetailHero(request: current),
            20.h.heightBox(),
            _Section(
              title: 'Request information',
              child: Column(
                children: [
                  _Line(label: 'Category', value: current.category.label),
                  _Line(label: 'Location', value: current.location),
                  _Line(label: 'Priority', value: current.priority.label),
                  _Line(label: 'Submitted', value: current.createdAt),
                  _Line(
                    label: 'Preferred time',
                    value:
                        '${current.preferredDate} Â· ${current.preferredTime}',
                  ),
                  _Line(
                    label: 'Assigned technician',
                    value: current.technician ?? 'Awaiting assignment',
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
              title: current.photoPaths.isEmpty ? 'Attachments' : 'Attachment',
              child: current.photoPaths.isEmpty
                  ? Text(
                      'No photos attached',
                      style: TextStyle(color: tokens.muted),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < current.photoPaths.length;
                          index++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == current.photoPaths.length - 1
                                  ? 0
                                  : 12,
                            ),
                            child: AppImagePreview(
                              key: Key('request-photo-$index'),
                              path: current.photoPaths[index],
                              caption: _photoCaption(current, index),
                            ),
                          ),
                      ],
                    ),
            ),
            20.h.heightBox(),
            _StatusProgress(request: current),
            // if (current.status.next != null) ...[
            //   20.h.heightBox(),
            //   AppPrimaryAction(
            //     key: Key('advance-maintenance-request'),
            //     onPressed: () => controller.advanceRequest(current),
            //     label: 'Move to ${current.status.next!.label}',
            //     icon: Icons.arrow_forward_rounded,
            //     backgroundColor: AppThemeTokens.of(context).brand,
            //   ),
            // ],
          ],
        ),
      );
    });
  }

  MaintenanceRequest _currentRequest() {
    return controller.requests.firstWhere(
      (item) => item.id == request.id,
      orElse: () => request,
    );
  }

  /// File name when the request knows it, otherwise something honest rather
  /// than a blank box.
  String _photoCaption(MaintenanceRequest request, int index) {
    if (index < request.photoNames.length) {
      return request.photoNames[index];
    }
    return 'Attached photo ${index + 1}';
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
            '${request.category.label} Â· ${request.priority.label}',
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

/// Renders the request's real status as a vertical timeline.
///
/// The step the request has reached comes from [MaintenanceRequest.status], so
/// nothing here is hardcoded: moving the request forward moves the timeline.
class _StatusProgress extends StatelessWidget {
  const _StatusProgress({required this.request});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final status = request.status;
    // The submitted step carries the request's own timestamp; the rest are
    // shown without a date because the mock data does not track one per step.
    final steps = <AppProgressStep>[
      for (final step in MaintenanceStatus.values)
        AppProgressStep(
          title: step.label,
          subtitle: step == MaintenanceStatus.submitted
              ? request.createdAt
              : (step.index < status.index ? 'Completed' : null),
        ),
    ];

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
          AppStepProgress(
            steps: steps,
            // A completed request has finished every step, so push the index
            // past the last one to render them all as completed.
            currentIndex: status == MaintenanceStatus.completed
                ? steps.length
                : status.index,
          ),
        ],
      ),
    );
  }
}
