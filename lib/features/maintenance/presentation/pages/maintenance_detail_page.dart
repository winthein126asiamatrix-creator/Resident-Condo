import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/maintenance_request.dart';
import '../controllers/maintenance_controller.dart';
import '../widgets/maintenance_status_badge.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_image_preview.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../../core/widgets/app_step_progress.dart';

class MaintenanceDetailPage extends GetView<MaintenanceController> {
  const MaintenanceDetailPage({required this.request, super.key});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = _currentRequest();
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Request details'),
        body: ListView(
          key: const Key('maintenance-detail-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32,
          ),
          children: [
            _DetailHero(request: current),
            const SizedBox(height: 20),
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
                        '${current.preferredDate} · ${current.preferredTime}',
                  ),
                  _Line(
                    label: 'Assigned technician',
                    value: current.technician ?? 'Awaiting assignment',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Description',
              child: Text(
                current.description,
                style: const TextStyle(color: Color(0xFF52635F), height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: current.photoPaths.isEmpty ? 'Attachments' : 'Attachment',
              child: current.photoPaths.isEmpty
                  ? const Text(
                      'No photos attached',
                      style: TextStyle(color: AppPalette.muted),
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
            const SizedBox(height: 20),
            _StatusProgress(request: current),
            if (current.status.next != null) ...[
              const SizedBox(height: 20),
              AppPrimaryAction(
                key: const Key('advance-maintenance-request'),
                onPressed: () => controller.advanceRequest(current),
                label: 'Move to ${current.status.next!.label}',
                icon: Icons.arrow_forward_rounded,
                backgroundColor: AppPalette.accent,
              ),
            ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'MAINTENANCE REQUEST',
                  style: TextStyle(
                    color: Color(0xFFBFE8DF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              MaintenanceStatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            request.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${request.category.label} · ${request.priority.label}',
            style: const TextStyle(color: Color(0xFFD8F3EC), fontSize: 13),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EEEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF71807D)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request progress',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 16),
          AppStepProgress(steps: steps, currentIndex: status.index),
        ],
      ),
    );
  }
}
