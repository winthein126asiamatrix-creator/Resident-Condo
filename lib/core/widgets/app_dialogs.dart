import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_palette.dart';

import '../theme/app_radius.dart';

import '../theme/app_theme_tokens.dart';

import 'app_primary_action.dart';

/// A label / value pair shown inside [showAppConfirmSummaryDialog].
class AppSummaryRow {
  AppSummaryRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;

  final bool emphasis;
}


class AppConfirmResult {
  AppConfirmResult.success() : error = null;

  AppConfirmResult.failure(this.error);

  final String? error;

  bool get isSuccess => error == null;
}


Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            vibrateNow();
            Navigator.pop(dialogContext, false);
          },
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Color(0xFFC2410C))
              : null,
          onPressed: () {
            vibrateNow();
            Navigator.pop(dialogContext, true);
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Consistent success / error toast for the new workflows.
void showAppFeedback(
  BuildContext context, {
  required String title,
  required String message,
  required bool isError,
  Color? backgroundColor,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final tokens = AppThemeTokens.of(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Color(0xFFC2410C)
            : backgroundColor ?? tokens.surface,
        content: Text(
          '$title: $message',
          style: TextStyle(color: tokens.ink), 
        ),
      ),
    );
}


Future<bool> showAppConfirmSummaryDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required List<AppSummaryRow> summary,
  required Future<AppConfirmResult> Function() onConfirm,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  String pendingLabel = 'Booking...',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AppConfirmSummaryDialog(
      title: title,
      message: message,
      icon: icon,
      summary: summary,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      pendingLabel: pendingLabel,
      onConfirm: onConfirm,
    ),
  );
  return confirmed ?? false;
}

class _AppConfirmSummaryDialog extends StatefulWidget {
  const _AppConfirmSummaryDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.summary,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.pendingLabel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final IconData icon;
  final List<AppSummaryRow> summary;
  final String confirmLabel;
  final String cancelLabel;
  final String pendingLabel;
  final Future<AppConfirmResult> Function() onConfirm;

  @override
  State<_AppConfirmSummaryDialog> createState() =>
      _AppConfirmSummaryDialogState();
}

class _AppConfirmSummaryDialogState extends State<_AppConfirmSummaryDialog> {
  bool _isSubmitting = false;
  String? _error;

  Future<void> _confirm() async {
    // A second tap while the action is running must not submit twice.
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await widget.onConfirm();
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420),
        // The whole dialog scrolls, so a long facility name or an error banner
        // can never overflow the dialog on a short screen.
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tokens.brandTint,
                  borderRadius: BorderRadius.circular(17.r),
                ),
                child: Icon(widget.icon, color: tokens.brand, size: 26),
              ),
              14.h.heightBox(),
              Text(
                widget.title,
                key: Key('app-confirm-dialog-title'),
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              6.h.heightBox(),
              Text(
                widget.message,
                key: Key('app-confirm-dialog-message'),
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 13.5.sp,
                  height: 1.35,
                ),
              ),
              18.h.heightBox(),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: [
                    for (final row in widget.summary)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                row.label,
                                style: TextStyle(
                                  color: tokens.muted,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                            12.w.widthBox(),
                            Flexible(
                              child: Text(
                                row.value,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: row.emphasis
                                      ? tokens.brand
                                      : tokens.ink,
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null) ...[
                14.h.heightBox(),
                Container(
                  key: Key('app-confirm-dialog-error'),
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: AppPalette.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: AppPalette.danger,
                      ),
                      8.w.widthBox(),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: AppPalette.danger,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              18.h.heightBox(),
              // Stacked full width actions: a long confirm label such as
              // "Confirm Reservation" fits on a small phone without clipping.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          vibrateNow();
                          Navigator.of(context).pop(false);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.mutedStrong,
                    side: BorderSide(color: tokens.border),
                    minimumSize: Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(widget.cancelLabel),
                ),
              ),
              10.h.heightBox(),
              AppPrimaryAction(
                key: Key('app-confirm-dialog-confirm'),
                onPressed: _isSubmitting ? null : _confirm,
                isLoading: _isSubmitting,
                label: _isSubmitting
                    ? widget.pendingLabel
                    : widget.confirmLabel,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog with a short form inside it, for actions such as changing a password.
///
/// Shares the shell, spacing and action buttons with
/// [showAppConfirmSummaryDialog] so every dialog in the app matches. The dialog
/// scrolls, so a form that grows with the keyboard or a long validation message
/// never overflows.
Future<bool> showAppFormDialog(
  BuildContext context, {
  required String title,
  required Widget child,
  String? message,
  IconData? icon,
  String confirmLabel = 'Save',
  String cancelLabel = 'Cancel',
  String pendingLabel = 'Saving...',
  Future<AppConfirmResult> Function()? onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    // An async form keeps the dialog open until the action settles, so tapping
    // outside must not hide a request that is still running.
    barrierDismissible: onConfirm == null,
    builder: (dialogContext) => _AppFormDialog(
      title: title,
      message: message,
      icon: icon,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      pendingLabel: pendingLabel,
      onConfirm: onConfirm,
      child: child,
    ),
  );
  return confirmed ?? false;
}

class _AppFormDialog extends StatefulWidget {
  const _AppFormDialog({
    required this.title,
    required this.child,
    required this.message,
    required this.icon,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.pendingLabel,
    required this.onConfirm,
  });

  final String title;
  final Widget child;
  final String? message;
  final IconData? icon;
  final String confirmLabel;
  final String cancelLabel;
  final String pendingLabel;
  final Future<AppConfirmResult> Function()? onConfirm;

  @override
  State<_AppFormDialog> createState() => _AppFormDialogState();
}

class _AppFormDialogState extends State<_AppFormDialog> {
  bool _isSubmitting = false;
  String? _error;

  Future<void> _confirm() async {
    if (_isSubmitting) {
      return;
    }
    final handler = widget.onConfirm;
    if (handler == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    AppConfirmResult result;
    try {
      result = await handler();
    } catch (_) {
      result = AppConfirmResult.failure(
        'Something went wrong. Please try again.',
      );
    }
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        backgroundColor: tokens.surface,
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.icon != null) ...[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tokens.brandTint,
                      borderRadius: BorderRadius.circular(17.r),
                    ),
                    child: Icon(widget.icon, color: tokens.brand, size: 26),
                  ),
                  14.h.heightBox(),
                ],
                Text(
                  widget.title,
                  key: Key('app-form-dialog-title'),
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.message != null) ...[
                  6.h.heightBox(),
                  Text(
                    widget.message!,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 13.5.sp,
                      height: 1.35,
                    ),
                  ),
                ],
                18.h.heightBox(),
                widget.child,
                if (_error != null && _error!.isNotEmpty) ...[
                  14.h.heightBox(),
                  Container(
                    key: Key('app-form-dialog-error'),
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: AppPalette.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 17,
                          color: AppPalette.danger,
                        ),
                        8.w.widthBox(),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: AppPalette.danger,
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                18.h.heightBox(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            vibrateNow();
                            Navigator.of(context).pop(false);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.mutedStrong,
                      side: BorderSide(color: tokens.border),
                      minimumSize: Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                10.h.heightBox(),
                AppPrimaryAction(
                  key: Key('app-form-dialog-confirm'),
                  onPressed: _isSubmitting ? null : _confirm,
                  isLoading: _isSubmitting,
                  label: _isSubmitting
                      ? widget.pendingLabel
                      : widget.confirmLabel,
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
