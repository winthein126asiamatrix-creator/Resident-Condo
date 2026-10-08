import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme_tokens.dart';
import 'app_primary_action.dart';

/// A label / value pair shown inside [showAppConfirmSummaryDialog].
class AppSummaryRow {
  const AppSummaryRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;

  /// Rendered in the brand colour, for the line that matters most.
  final bool emphasis;
}

/// Outcome of a dialog's confirm action. A failure keeps the dialog open with
/// the message, so the resident can retry without losing their place.
class AppConfirmResult {
  const AppConfirmResult.success() : error = null;

  const AppConfirmResult.failure(this.error);

  final String? error;

  bool get isSuccess => error == null;
}

/// Confirmation dialog used for every destructive or irreversible action
/// (cancel a reservation, delete a visitor, withdraw a renewal, logout...).
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFC2410C))
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
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
  Color? backgroundColor
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
            ? const Color(0xFFC2410C)
            : backgroundColor ?? tokens.surface,
        content: Text('$title: $message'),
      ),
    );
}

/// Confirmation dialog for an action that needs the details reviewed first,
/// such as booking a facility.
///
/// It is a custom dialog rather than an [AlertDialog] so the summary can be
/// shown as a proper block, and the confirm button can hold a loading state
/// while the action runs. Repeated taps are ignored while it is in flight, and a
/// failed action leaves the dialog open with the reason so it can be retried.
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        // The whole dialog scrolls, so a long facility name or an error banner
        // can never overflow the dialog on a short screen.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tokens.brandTint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(widget.icon, color: tokens.brand, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                key: const Key('app-confirm-dialog-title'),
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.message,
                key: const Key('app-confirm-dialog-message'),
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: [
                    for (final row in widget.summary)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                row.label,
                                style: TextStyle(
                                  color: tokens.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                row.value,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: row.emphasis
                                      ? tokens.brand
                                      : tokens.ink,
                                  fontSize: 13.5,
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
                const SizedBox(height: 14),
                Container(
                  key: const Key('app-confirm-dialog-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppPalette.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: AppPalette.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppPalette.danger,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              // Stacked full width actions: a long confirm label such as
              // "Confirm Reservation" fits on a small phone without clipping.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.mutedStrong,
                    side: BorderSide(color: tokens.border),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(widget.cancelLabel),
                ),
              ),
              const SizedBox(height: 10),
              AppPrimaryAction(
                key: const Key('app-confirm-dialog-confirm'),
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
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final tokens = AppThemeTokens.of(dialogContext);
      return Dialog(
        backgroundColor: tokens.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tokens.brandTint,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(icon, color: tokens.brand, size: 26),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  title,
                  key: const Key('app-form-dialog-title'),
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                child,
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.mutedStrong,
                      side: BorderSide(color: tokens.border),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(height: 10),
                AppPrimaryAction(
                  key: const Key('app-form-dialog-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  label: confirmLabel,
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
