import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_tokens.dart';

/// Read only field that looks like a form control and opens a picker.
///
/// Used for anything the resident picks rather than types: a date, a time, a
/// facility, a category. It matches [AppTextField] in height, radius and border
/// so a form mixing typed and picked fields still reads as one component.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
    this.fieldKey,
    this.trailingIcon = Icons.expand_more_rounded,
    this.helperText,
    this.enabled = true,
    super.key,
  });

  /// Label above the field. Pass null for a field that sits inside a row of
  /// equally labelled pickers, where the label would not fit.
  final String? label;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? fieldKey;
  final IconData trailingIcon;
  final String? helperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final field = Semantics(
      button: true,
      enabled: enabled,
      label: label == null ? value : '$label, $value',
      child: Material(
        color: enabled ? tokens.surface : tokens.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: AppSpacing.pickerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? tokens.muted : tokens.faint,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? tokens.ink : tokens.faint,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  trailingIcon,
                  size: 18,
                  color: enabled ? tokens.muted : tokens.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (label == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: AppTextStyles.of(context).fieldLabel),
        const SizedBox(height: AppSpacing.fieldLabelGap),
        field,
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
