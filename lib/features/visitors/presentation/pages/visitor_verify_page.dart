import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/text_input_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/visitor.dart';
import '../controllers/visitor_controller.dart';
import '../widgets/visitor_status_badge.dart';

/// Lobby desk screen: type the code the visitor reads out and confirm entry.
class VisitorVerifyPage extends GetView<VisitorController> {
  const VisitorVerifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify visitor')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppPalette.brand,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppPalette.heroShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ENTER ACCESS CODE',
                    style: TextStyle(
                      color: AppPalette.brandOnDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('verify-code-field'),
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      const UpperCaseTextFormatter(),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    onChanged: controller.onVerificationChanged,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'VIS ABC-123',
                      hintStyle: TextStyle(
                        fontSize: 20,
                        letterSpacing: 2,
                        color: AppPalette.faint,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('verify-code-submit'),
                      onPressed: controller.isVerifying.value
                          ? null
                          : controller.verifyCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.accent,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: controller.isVerifying.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_user_rounded, size: 18),
                      label: Text(
                        controller.isVerifying.value
                            ? 'Checking...'
                            : 'Verify code',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (controller.verification.value != null)
              _VerificationResult(controller: controller)
            else
              const AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppPalette.muted),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The code is printed on the resident app and shared '
                        'with the visitor. Codes are alphanumeric — for example '
                        'VIS K7M-4QX.',
                        style: TextStyle(
                          color: AppPalette.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Expected today',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.visitors),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('All visitors'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (controller.visitors.isEmpty)
              const Text(
                'No visitors registered.',
                style: TextStyle(color: AppPalette.muted),
              )
            else
              for (final visitor in controller.visitors)
                if (visitor.status == VisitorStatus.preRegistered ||
                    visitor.status == VisitorStatus.checkedIn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExpectedTile(controller: controller, visitor: visitor),
                  ),
            if (controller.errorMessage.value != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.errorMessage.value!,
                style: const TextStyle(color: AppPalette.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationResult extends StatelessWidget {
  const _VerificationResult({required this.controller});
  final VisitorController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.verification.value!;
    final visitor = result.visitor;
    final color = result.isValid ? AppPalette.success : AppPalette.danger;

    return Column(
      children: [
        AppCard(
          color: result.isValid ? AppPalette.brandTint : AppPalette.accentSoft,
          borderColor: result.isValid ? AppPalette.brandSoft : const Color(0xFFF0C6C0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIconTile(
                    icon: result.isValid
                        ? Icons.verified_rounded
                        : Icons.gpp_bad_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.isValid ? 'Access granted' : 'Access denied',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result.message,
                style: const TextStyle(
                  color: AppPalette.mutedStrong,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (visitor != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visitor.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    VisitorStatusPill(status: visitor.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${visitor.arrivalWindow} · ${visitor.purpose}',
                  style: const TextStyle(color: AppPalette.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Code ${visitor.accessCode} · unit ${visitor.registeredBy}\'s host',
                  style: const TextStyle(color: AppPalette.faint, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visitor != null && visitor.canCheckIn)
          FilledButton.icon(
            key: const Key('verify-check-in'),
            onPressed: controller.isSubmitting.value
                ? null
                : () => _checkIn(context, visitor),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Check in visitor'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        if (visitor != null && visitor.canCheckOut) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: controller.isSubmitting.value
                ? null
                : () => _checkOut(context, visitor),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Check out visitor'),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.accent,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: controller.clearVerification,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Verify another code'),
        ),
      ],
    );
  }

  Future<void> _checkIn(BuildContext context, Visitor visitor) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Check in ${visitor.name}?',
      message: 'Arrival will be logged against ${visitor.accessCode}.',
      confirmLabel: 'Check in',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.checkIn(visitor);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to check in' : 'Checked in',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : '${updated.name} is now on site.',
      isError: updated == null,
    );
  }

  Future<void> _checkOut(BuildContext context, Visitor visitor) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Check out ${visitor.name}?',
      message: 'The access code will stop working immediately.',
      confirmLabel: 'Check out',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.checkOut(visitor);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to check out' : 'Checked out',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'Access code closed.',
      isError: updated == null,
    );
  }
}

class _ExpectedTile extends StatelessWidget {
  const _ExpectedTile({required this.controller, required this.visitor});
  final VisitorController controller;
  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        controller.onVerificationChanged(visitor.accessCode);
        controller.verifyCode();
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AppIconTile(
            icon: Icons.person_outline_rounded,
            color: visitorStatusColor(visitor.status),
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitor.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  visitor.arrivalWindow,
                  style: const TextStyle(color: AppPalette.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            visitor.accessCode,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
