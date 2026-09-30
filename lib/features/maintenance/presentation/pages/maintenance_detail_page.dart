import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/maintenance_request.dart';
import '../controllers/maintenance_controller.dart';
import '../widgets/maintenance_status_badge.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

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
              title: 'Photos',
              child: current.photoNames.isEmpty
                  ? const Text(
                      'No photos attached',
                      style: TextStyle(color: Color(0xFF71807D)),
                    )
                  : Wrap(
                      spacing: 8,
                      children: current.photoNames
                          .map(
                            (photo) => Chip(
                              avatar: const Icon(
                                Icons.photo_outlined,
                                size: 17,
                              ),
                              label: Text(photo),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 20),
            _StatusProgress(status: current.status),
            if (current.status.next != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => controller.advanceRequest(current),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('Move to ${current.status.next!.label}'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE07A5F),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
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

class _StatusProgress extends StatelessWidget {
  const _StatusProgress({required this.status});

  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    const steps = MaintenanceStatus.values;
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
          const Text(
            'Request progress',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Expanded(
                  child: _ProgressStep(
                    step: steps[index],
                    index: index,
                    status: status,
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: steps[index + 1].index <= status.index
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFE6EEEB),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.step,
    required this.index,
    required this.status,
  });

  final MaintenanceStatus step;
  final int index;
  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    final completed = step.index <= status.index;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: completed
                ? const Color(0xFF0F766E)
                : const Color(0xFFE6EEEB),
            shape: BoxShape.circle,
          ),
          child: completed
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF71807D),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 7),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: completed
                ? const Color(0xFF0F766E)
                : const Color(0xFF71807D),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
