import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/rules.dart';
import '../controllers/rules_controller.dart';
import '../widgets/rules_widgets.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';

class ViolationDetailPage extends GetView<RulesController> {
  const ViolationDetailPage({required this.violation, super.key});

  final Violation violation;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = _current();
      final appeal = controller.appealFor(current);
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Violation'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AppHeroPanel(
              icon: Icons.report_rounded,
              title: current.reference,
              subtitle: current.ruleTitle,
              footnote: 'Issued ${current.issuedOn} · due ${current.dueDate}',
              trailing: ViolationStatusPill(
                status: current.status,
                dense: false,
              ),
              leading: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'FINE',
                      style: TextStyle(
                        color: AppPalette.brandOnDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    AppFormatters.currency(current.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              title: 'What happened',
              child: Text(
                current.description,
                style: const TextStyle(
                  color: AppPalette.mutedStrong,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              title: 'Record',
              child: Column(
                children: [
                  AppLabelValueRow(label: 'Rule', value: current.ruleTitle),
                  AppLabelValueRow(
                    label: 'Category',
                    value: current.category.label,
                  ),
                  AppLabelValueRow(label: 'Location', value: current.location),
                  AppLabelValueRow(label: 'Issued on', value: current.issuedOn),
                  AppLabelValueRow(
                    label: 'Payment due',
                    value: current.dueDate,
                  ),
                  if (current.evidenceNote.isNotEmpty)
                    AppLabelValueRow(
                      label: 'Evidence',
                      value: current.evidenceNote,
                    ),
                ],
              ),
            ),
            if (appeal != null) ...[
              const SizedBox(height: 18),
              AppSectionHeader(title: 'Appeal'),
              const SizedBox(height: 10),
              _AppealCard(controller: controller, appeal: appeal),
            ],
            const SizedBox(height: 20),
            if (current.canAppeal && appeal == null)
              FilledButton.icon(
                key: const Key('appeal-violation'),
                onPressed: () {
                  controller.selectViolation(current);
                  Get.toNamed(AppRoutes.violationAppeal);
                },
                icon: const Icon(Icons.balance_rounded, size: 18),
                label: const Text('Appeal this violation'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            if (appeal != null && appeal.isOpen)
              OutlinedButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _withdrawAppeal(context, appeal),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Withdraw appeal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.danger,
                  side: const BorderSide(color: Color(0xFFF0C6C0)),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            if (current.status == ViolationStatus.paid)
              AppCard(
                color: AppPalette.brandTint,
                borderColor: AppPalette.brandSoft,
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppPalette.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This fine is already settled. It is shown as a Violation '
                        'Fine line on your statement.',
                        style: TextStyle(
                          color: AppPalette.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Violation _current() {
    return controller.violations.firstWhere(
      (item) => item.id == violation.id,
      orElse: () => violation,
    );
  }

  Future<void> _withdrawAppeal(
    BuildContext context,
    ViolationAppeal appeal,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Withdraw appeal?',
      message:
          'The appeal on ${violation.reference} will be closed and the fine '
          'becomes payable again.',
      confirmLabel: 'Withdraw appeal',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.withdrawAppeal(appeal);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to withdraw' : 'Appeal withdrawn',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'The fine is back in the open state.',
      isError: updated == null,
    );
  }
}

class _AppealCard extends StatelessWidget {
  const _AppealCard({required this.controller, required this.appeal});
  final RulesController controller;
  final ViolationAppeal appeal;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Your appeal',
      subtitle: 'Submitted ${appeal.submittedOn}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Requested: ${appeal.requestedOutcome}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              AppealStatusPill(status: appeal.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            appeal.reason,
            style: const TextStyle(
              color: AppPalette.mutedStrong,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (appeal.decisionNote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                appeal.decisionNote!,
                style: const TextStyle(
                  color: AppPalette.mutedStrong,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
