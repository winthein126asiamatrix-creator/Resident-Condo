import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/condo_service.dart';
import '../controllers/condo_service_controller.dart';
import '../widgets/service_widgets.dart';
import '../../../../core/widgets/app_card.dart';

class ServiceRequestDetailPage extends GetView<CondoServiceController> {
  const ServiceRequestDetailPage({required this.request, super.key});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = _current();
      return Scaffold(
        appBar: AppBar(title: const Text('Service request')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AppHeroPanel(
              icon: serviceIcon(current.category),
              title: current.serviceName,
              subtitle:
                  '${current.scheduledDate} · ${current.scheduledSlot}',
              footnote: 'Provider: ${current.provider}',
              trailing: ServiceStatusPill(status: current.status, dense: false),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              title: 'Request details',
              child: Column(
                children: [
                  AppLabelValueRow(
                    label: 'Category',
                    value: current.category.label,
                  ),
                  AppLabelValueRow(label: 'Scheduled', value: current.scheduledDate),
                  AppLabelValueRow(label: 'Slot', value: current.scheduledSlot),
                  AppLabelValueRow(
                    label: 'Service fee',
                    value: AppFormatters.currency(current.price),
                  ),
                  AppLabelValueRow(
                    label: 'Requested on',
                    value: current.requestedOn,
                  ),
                ],
              ),
            ),
            if (current.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppSectionCard(
                title: 'Your notes',
                child: Text(
                  current.notes,
                  style: const TextStyle(
                    color: AppPalette.mutedStrong,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const AppSectionHeader(title: 'Progress'),
            const SizedBox(height: 10),
            _Timeline(status: current.status),
            if (current.rating != null) ...[
              const SizedBox(height: 18),
              AppSectionCard(
                title: 'Your rating',
                child: Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= current.rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppPalette.warning,
                        size: 22,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        current.feedback ?? '',
                        style: const TextStyle(
                          color: AppPalette.mutedStrong,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (current.canCancel)
              OutlinedButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _cancel(context, current),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.danger,
                  side: const BorderSide(color: Color(0xFFF0C6C0)),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            if (current.canRate) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _rate(context, current),
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Rate this service'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
            if (controller.errorMessage.value != null) ...[
              const SizedBox(height: 10),
              Text(
                controller.errorMessage.value!,
                style: const TextStyle(color: AppPalette.danger),
              ),
            ],
          ],
        ),
      );
    });
  }

  ServiceRequest _current() {
    return controller.requests.firstWhere(
      (item) => item.id == request.id,
      orElse: () => request,
    );
  }

  Future<void> _cancel(BuildContext context, ServiceRequest current) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel this service?',
      message:
          '${current.serviceName} on ${current.scheduledDate} will be cancelled '
          'and the slot released.',
      confirmLabel: 'Cancel service',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.cancelRequest(current);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to cancel' : 'Service cancelled',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'The booking slot has been released.',
      isError: updated == null,
    );
  }

  Future<void> _rate(BuildContext context, ServiceRequest current) async {
    final result = await showDialog<({int rating, String feedback})>(
      context: context,
      builder: (dialogContext) => _RatingDialog(serviceName: current.serviceName),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final updated = await controller.rateRequest(
      current,
      result.rating,
      result.feedback,
    );
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to save rating' : 'Thanks for the feedback',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'Your rating was saved.',
      isError: updated == null,
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final ServiceRequestStatus status;

  static const _steps = [
    ServiceRequestStatus.requested,
    ServiceRequestStatus.scheduled,
    ServiceRequestStatus.inProgress,
    ServiceRequestStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexOf(status);
    final cancelled = status == ServiceRequestStatus.cancelled;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: !cancelled && i <= currentIndex
                            ? AppPalette.brand
                            : AppPalette.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: !cancelled && i <= currentIndex
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (i < _steps.length - 1)
                      Container(
                        width: 2,
                        height: 26,
                        color: !cancelled && i < currentIndex
                            ? AppPalette.brand
                            : AppPalette.surfaceMuted,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _steps[i].label,
                    style: TextStyle(
                      fontWeight: !cancelled && i <= currentIndex
                          ? FontWeight.w800
                          : FontWeight.w400,
                      color: !cancelled && i <= currentIndex
                          ? AppPalette.ink
                          : AppPalette.faint,
                    ),
                  ),
                ),
              ],
            ),
          if (cancelled)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.cancel_rounded, size: 18, color: AppPalette.danger),
                  SizedBox(width: 10),
                  Text(
                    'Cancelled',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppPalette.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.serviceName});
  final String serviceName;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 5;
  final TextEditingController _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Rate ${widget.serviceName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppPalette.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feedback,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Optional comment'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (rating: _rating, feedback: _feedback.text),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
