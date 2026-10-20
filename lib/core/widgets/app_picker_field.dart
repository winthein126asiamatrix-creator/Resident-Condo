import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
          onTap: enabled
              ? () {
                  vibrateNow();
                  onPressed();
                }
              : null,
          child: Container(
            height: AppSpacing.pickerHeight,
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? tokens.muted : tokens.faint,
                ),
                9.w.widthBox(),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? tokens.ink : tokens.faint,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                6.w.widthBox(),
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
        AppSpacing.fieldLabelGap.heightBox(),
        field,
        if (helperText != null) ...[
          6.h.heightBox(),
          Text(
            helperText!,
            style: TextStyle(color: tokens.muted, fontSize: 12.sp),
          ),
        ],
      ],
    );
  }
}
