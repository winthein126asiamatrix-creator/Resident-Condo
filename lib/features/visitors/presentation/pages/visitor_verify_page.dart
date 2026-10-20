import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/text_input_formatters.dart';

import '../../../../core/widgets/app_card.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_status_pill.dart';

import '../../domain/entities/visitor.dart';

import '../controllers/visitor_controller.dart';

import '../widgets/visitor_status_badge.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_form_field.dart';

/// Lobby desk screen: type the code the visitor reads out and confirm entry.
class VisitorVerifyPage extends GetView<VisitorController> {
  const VisitorVerifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Verify visitor'),
      body: Obx(
        () => ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.brand,
                borderRadius: BorderRadius.circular(22.r),
                boxShadow: tokens.heroShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ENTER ACCESS CODE',
                    style: TextStyle(
                      color: tokens.brandOnDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  12.h.heightBox(),
                  AppTextField(
                    fieldKey: Key('verify-code-field'),
                    label: 'Verification code',
                    hint: 'VIS ABC-123',
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    onChanged: controller.onVerificationChanged,
                    // Read as a code, so the spacing is wider than a prose field.
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  14.h.heightBox(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: Key('verify-code-submit'),
                      onPressed: controller.isVerifying.value
                          ? null
                          : controller.verifyCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.brand,
                        minimumSize: Size.fromHeight(50),
                      ),
                      icon: controller.isVerifying.value
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.onBrand,
                              ),
                            )
                          : Icon(Icons.verified_user_rounded, size: 18),
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
            16.h.heightBox(),
            if (controller.verification.value != null)
              _VerificationResult(controller: controller)
            else
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: tokens.muted),
                    10.w.widthBox(),
                    Expanded(
                      child: Text(
                        'The code is printed on the resident app and shared '
                        'with the visitor. Codes are alphanumeric â€” for example '
                        'VIS K7M-4QX.',
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            22.h.heightBox(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expected today',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.visitors),
                  icon: Icon(Icons.list_alt_rounded, size: 18),
                  label: Text('All visitors'),
                ),
              ],
            ),
            8.h.heightBox(),
            if (controller.visitors.isEmpty)
              Text(
                'No visitors registered.',
                style: TextStyle(color: tokens.muted),
              )
            else
              for (final visitor in controller.visitors)
                if (visitor.status == VisitorStatus.preRegistered ||
                    visitor.status == VisitorStatus.checkedIn)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _ExpectedTile(
                      controller: controller,
                      visitor: visitor,
                    ),
                  ),
            if (controller.errorMessage.value != null) ...[
              12.h.heightBox(),
              Text(
                controller.errorMessage.value!,
                style: TextStyle(color: AppPalette.danger),
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
    final tokens = AppThemeTokens.of(context);
    final result = controller.verification.value!;
    final visitor = result.visitor;
    final color = result.isValid ? AppPalette.success : AppPalette.danger;

    return Column(
      children: [
        AppCard(
          color: result.isValid ? tokens.brandTint : AppPalette.accentSoft,
          borderColor: result.isValid ? tokens.brandSoft : Color(0xFFF0C6C0),
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
                  12.w.widthBox(),
                  Expanded(
                    child: Text(
                      result.isValid ? 'Access granted' : 'Access denied',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17.sp,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              10.h.heightBox(),
              Text(
                result.message,
                style: TextStyle(
                  color: tokens.mutedStrong,
                  fontSize: 12.sp,
                  height: 1.4,
                ),
              ),
              if (visitor != null) ...[
                12.h.heightBox(),
                Divider(height: 1),
                12.h.heightBox(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visitor.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    VisitorStatusPill(status: visitor.status),
                  ],
                ),
                6.h.heightBox(),
                Text(
                  '${visitor.arrivalWindow} Â· ${visitor.purpose}',
                  style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                ),
                4.h.heightBox(),
                Text(
                  'Code ${visitor.accessCode} Â· unit ${visitor.registeredBy}\'s host',
                  style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                ),
              ],
            ],
          ),
        ),
        12.h.heightBox(),
        if (visitor != null && visitor.canCheckIn)
          FilledButton.icon(
            key: Key('verify-check-in'),
            onPressed: controller.isSubmitting.value
                ? null
                : () => _checkIn(context, visitor),
            icon: Icon(Icons.login_rounded, size: 18),
            label: Text('Check in visitor'),
            style: FilledButton.styleFrom(minimumSize: Size.fromHeight(50)),
          ),
        if (visitor != null && visitor.canCheckOut) ...[
          10.h.heightBox(),
          FilledButton.icon(
            onPressed: controller.isSubmitting.value
                ? null
                : () => _checkOut(context, visitor),
            icon: Icon(Icons.logout_rounded, size: 18),
            label: Text('Check out visitor'),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.brand,
              minimumSize: Size.fromHeight(50),
            ),
          ),
        ],
        10.h.heightBox(),
        TextButton.icon(
          onPressed: controller.clearVerification,
          icon: Icon(Icons.refresh_rounded, size: 18),
          label: Text('Verify another code'),
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
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      onTap: () {
        vibrateNow();
        controller.onVerificationChanged(visitor.accessCode);
        controller.verifyCode();
      },
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AppIconTile(
            icon: Icons.person_outline_rounded,
            color: visitorStatusColor(context, visitor.status),
            size: 38,
          ),
          12.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitor.name,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                3.h.heightBox(),
                Text(
                  visitor.arrivalWindow,
                  style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                ),
              ],
            ),
          ),
          Text(
            visitor.accessCode,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.sp,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
