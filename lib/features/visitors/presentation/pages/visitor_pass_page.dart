import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/entities/visitor.dart';
import '../controllers/visitor_controller.dart';
import '../widgets/visitor_status_badge.dart';

class VisitorPassPage extends GetView<VisitorController> {
  const VisitorPassPage({required this.visitor, super.key});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = _current();
      final color = visitorStatusColor(current.status);
      return Scaffold(
        appBar: AppBar(title: const Text('Visitor pass')),
        body: ListView(
          key: const Key('visitor-pass-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _CodeCard(visitor: current, color: color),
            const SizedBox(height: 18),
            AppSectionCard(
              title: 'Visit details',
              child: Column(
                children: [
                  AppLabelValueRow(label: 'Name', value: current.name),
                  AppLabelValueRow(label: 'Phone', value: current.phone),
                  AppLabelValueRow(label: 'Relation', value: current.relation.label),
                  AppLabelValueRow(label: 'Purpose', value: current.purpose),
                  AppLabelValueRow(label: 'Date', value: current.date),
                  AppLabelValueRow(
                    label: 'Arrival window',
                    value: current.arrivalWindow,
                  ),
                  if (current.vehiclePlate != null)
                    AppLabelValueRow(
                      label: 'Vehicle plate',
                      value: current.vehiclePlate!,
                    ),
                  AppLabelValueRow(
                    label: 'Status',
                    valueWidget: VisitorStatusPill(status: current.status),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              title: 'Lobby log',
              child: Column(
                children: [
                  AppLabelValueRow(
                    label: 'Registered by',
                    value: current.registeredBy,
                  ),
                  AppLabelValueRow(
                    label: 'Registered on',
                    value: current.registeredOn,
                  ),
                  AppLabelValueRow(
                    label: 'Checked in',
                    value: current.checkedInAt ?? 'Not yet',
                  ),
                  AppLabelValueRow(
                    label: 'Checked out',
                    value: current.checkedOutAt ?? '—',
                  ),
                ],
              ),
            ),
            if (current.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppSectionCard(
                title: 'Notes',
                child: Text(
                  current.notes,
                  style: const TextStyle(
                    color: AppPalette.mutedStrong,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _copy(context, current),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy access code'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 10),
            if (current.canCheckIn)
              FilledButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _checkIn(context, current),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Mark as checked in'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              )
            else if (current.canCheckOut)
              FilledButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _checkOut(context, current),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Mark as checked out'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: controller.isSubmitting.value
                  ? null
                  : () => _cancel(context, current),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel this pass'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.danger,
                side: const BorderSide(color: Color(0xFFF0C6C0)),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      );
    });
  }

  Visitor _current() {
    return controller.visitors.firstWhere(
      (item) => item.id == visitor.id,
      orElse: () => visitor,
    );
  }

  Future<void> _copy(BuildContext context, Visitor current) async {
    await Clipboard.setData(ClipboardData(text: current.accessCode));
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: 'Access code copied',
      message: 'Send ${current.accessCode} to ${current.name}.',
      isError: false,
    );
  }

  Future<void> _checkIn(BuildContext context, Visitor current) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Check in ${current.name}?',
      message: 'Arrival will be logged for access code ${current.accessCode}.',
      confirmLabel: 'Check in',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.checkIn(current);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to check in' : 'Visitor checked in',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : '${updated.name} is on site.',
      isError: updated == null,
    );
  }

  Future<void> _checkOut(BuildContext context, Visitor current) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Check out ${current.name}?',
      message: 'The access code will stop working once the visitor leaves.',
      confirmLabel: 'Check out',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.checkOut(current);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to check out' : 'Visitor checked out',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'Thanks for hosting ${updated.name}.',
      isError: updated == null,
    );
  }

  Future<void> _cancel(BuildContext context, Visitor current) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel this pass?',
      message:
          'The access code ${current.accessCode} will stop working and the '
          'lobby will reject it. This cannot be undone.',
      confirmLabel: 'Cancel pass',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.cancelVisitor(current);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to cancel' : 'Pass cancelled',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'Access code ${updated.accessCode} is no longer valid.',
      isError: updated == null,
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.visitor, required this.color});
  final Visitor visitor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppPalette.brand,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppPalette.heroShadow,
      ),
      child: Column(
        children: [
          const Text(
            'VISITOR ACCESS CODE',
            style: TextStyle(
              color: AppPalette.brandOnDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            visitor.accessCode,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Text(
            visitor.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${visitor.date} · ${visitor.arrivalWindow}',
            style: const TextStyle(
              color: AppPalette.brandOnDarkMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          VisitorStatusPill(status: visitor.status),
        ],
      ),
    );
  }
}
