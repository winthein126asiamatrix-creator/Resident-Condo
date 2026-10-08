import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../controllers/rules_controller.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_form_field.dart';

class AppealViolationPage extends StatefulWidget {
  const AppealViolationPage({super.key});

  @override
  State<AppealViolationPage> createState() => _AppealViolationPageState();
}

class _AppealViolationPageState extends State<AppealViolationPage> {
  final RulesController controller = Get.find<RulesController>();
  final TextEditingController _reasonController = TextEditingController();

  String _outcome = 'Waive the fine';
  String _error = '';

  static const _outcomes = [
    'Waive the fine',
    'Reduce the fine',
    'Postpone payment',
    'Request a warning only',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Obx(() {
      final violation = controller.selectedViolation.value;
      if (violation == null) {
        return Scaffold(
          appBar: AppDetailAppBar(title: 'Appeal violation'),
          body: AppStateMessage(
            title: 'No violation selected',
            message: 'Open a violation before submitting an appeal.',
            icon: Icons.balance_rounded,
            actionLabel: 'Back',
            onAction: () => Get.offNamed(AppRoutes.rules),
          ),
        );
      }
      if (!violation.canAppeal) {
        return Scaffold(
          appBar: AppDetailAppBar(title: 'Appeal violation'),
          body: AppStateMessage(
            title: 'Not eligible for appeal',
            message:
                'This violation has already been settled or an appeal is open.',
            icon: Icons.block_rounded,
            actionLabel: 'Back to violations',
            onAction: () => Get.offNamed(AppRoutes.rules),
          ),
        );
      }

      return Scaffold(
        appBar: AppDetailAppBar(title: 'Appeal violation'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            AppStateMessage(
              title: violation.reference,
              message:
                  '${violation.ruleTitle} · fine '
                  '${AppFormatters.currency(violation.amount)}',
              icon: Icons.report_rounded,
            ),
            const SizedBox(height: 12),
            const Text(
              'Requested outcome',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outcomes
                  .map(
                    (outcome) => ChoiceChip(
                      label: Text(outcome),
                      selected: outcome == _outcome,
                      onSelected: (_) => setState(() => _outcome = outcome),
                      selectedColor: tokens.brandSoft,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Why should this be reviewed?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            AppTextField(
              fieldKey: const Key('appeal-reason-field'),
              label: 'Why should this be reviewed?',
              controller: _reasonController,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              hint:
                  'Explain the circumstances. Add dates, witness names or '
                  'evidence that support your appeal.',
            ),
            const SizedBox(height: 10),
            Text(
              'Minimum 20 characters. The management committee reviews every '
              'appeal within 14 days.',
              style: TextStyle(color: tokens.faint, fontSize: 11),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('submit-appeal'),
              onPressed: controller.isSubmitting.value ? null : _submit,
              icon: controller.isSubmitting.value
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.onBrand,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                controller.isSubmitting.value
                    ? 'Submitting...'
                    : 'Submit appeal',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: AppPalette.danger)),
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

  Future<void> _submit() async {
    _error = '';
    final violation = controller.selectedViolation.value;
    if (violation == null) {
      return;
    }
    if (_reasonController.text.trim().length < 20) {
      setState(
        () => _error = 'Please explain your appeal in at least 20 characters.',
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Submit appeal?',
      message:
          'Your appeal on ${violation.reference} for '
          '${AppFormatters.currency(violation.amount)} will be reviewed by the '
          'management committee.',
      confirmLabel: 'Submit appeal',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final appeal = await controller.submitAppeal(
      violation: violation,
      reason: _reasonController.text,
      requestedOutcome: _outcome,
    );
    if (!mounted) {
      return;
    }
    if (appeal == null) {
      setState(() {
        _error = controller.errorMessage.value ?? 'Appeal failed.';
      });
      return;
    }
    Get.offNamed(AppRoutes.violationDetail, arguments: violation);
  }
}
