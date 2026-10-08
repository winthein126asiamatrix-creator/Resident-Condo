import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_tokens.dart';

/// Rounded, filled input used by every resident facing form.
///
/// The label always sits above the field so it stays readable, the icon is
/// rendered inside the box for single line fields and next to the label for
/// multi line ones. Focus and error states are handled by the decoration
/// itself, which keeps the native validation behaviour untouched.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.fieldKey,
    this.controller,
    this.hint,
    this.icon,
    this.helperText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.obscureText = false,
    this.suffixIconLabel,
    this.onSuffixTap,
    this.inputFormatters,
    this.style,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final Key? fieldKey;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final String? helperText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;

  /// Hides the entered text, for a password or a code.
  final bool obscureText;

  /// Adds a clear button on the trailing edge, e.g. to empty a search field.
  final String? suffixIconLabel;
  final VoidCallback? onSuffixTap;

  /// Masks applied while typing, e.g. digits only for a card number.
  final List<TextInputFormatter>? inputFormatters;

  /// Overrides the default field typography, for a field that is read as a
  /// code rather than as prose.
  final TextStyle? style;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final multiline = maxLines > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, icon: multiline ? icon : null),
        const SizedBox(height: AppSpacing.fieldLabelGap),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          obscureText: obscureText,
          autofocus: autofocus,
          cursorColor: tokens.brand,
          style: style ?? AppTextStyles.of(context).fieldValue,
          decoration: appFormFieldDecoration(
            context: context,
            hint: hint,
            icon: multiline ? null : icon,
            helperText: helperText,
            suffixIconLabel: suffixIconLabel,
            onSuffixTap: onSuffixTap,
            enabled: enabled,
          ),
        ),
      ],
    );
  }
}

/// Rounded dropdown that matches [AppTextField] down to the border radius.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.fieldKey,
    this.hint,
    this.icon,
    this.helperText,
    this.itemBuilder,
    super.key,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final Key? fieldKey;
  final String? hint;
  final IconData? icon;
  final String? helperText;
  final String Function(T value)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, icon: icon),
        const SizedBox(height: AppSpacing.fieldLabelGap),
        DropdownButtonFormField<T>(
          key: fieldKey,
          initialValue: value,
          isExpanded: true,
          dropdownColor: tokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          style: AppTextStyles.of(context).fieldValue,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemBuilder?.call(item) ?? '$item'),
                ),
              )
              .toList(),
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
          decoration: appFormFieldDecoration(
            context: context,
            hint: hint,
            icon: null,
            helperText: helperText,
            isSelect: true,
          ),
        ),
      ],
    );
  }
}

/// Shared decoration for [AppTextField] and [AppSelectField].
///
/// Keeping it in one place is what makes every field in the app share the same
/// radius, border, focus colour and error colour.
InputDecoration appFormFieldDecoration({
  BuildContext? context,
  String? hint,
  IconData? icon,
  String? helperText,
  String? suffixIconLabel,
  VoidCallback? onSuffixTap,
  bool isSelect = false,
  bool enabled = true,
}) {
  final tokens = context == null
      ? AppThemeTokens.fallback()
      : AppThemeTokens.of(context);

  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: enabled ? tokens.faint : tokens.muted,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    helperText: helperText,
    helperMaxLines: 2,
    helperStyle: TextStyle(color: tokens.muted, fontSize: 12),
    filled: true,
    fillColor: enabled ? tokens.surface : tokens.surfaceMuted,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    prefixIcon: icon == null
        ? null
        : Icon(
            icon,
            size: 20,
            color: enabled ? tokens.muted : tokens.faint,
          ),
    prefixIconColor: tokens.muted,
    prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 24),
    suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 24),
    border: border(tokens.border),
    enabledBorder: border(tokens.border),
    // The focus ring is the only emphasis a field gets, which is enough to
    // show it is active without shouting.
    focusedBorder: border(tokens.brand, 1.6),
    errorBorder: border(AppPalette.danger, 1.2),
    focusedErrorBorder: border(AppPalette.danger, 1.6),
    disabledBorder: border(tokens.border),
    // Two lines of room keeps the field from jumping when an error appears.
    errorMaxLines: 2,
    errorStyle: const TextStyle(
      color: AppPalette.danger,
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    // The select field already renders its own chevron.
    suffixIcon: isSelect
        ? Icon(Icons.keyboard_arrow_down_rounded, color: tokens.muted)
        : suffixIconLabel == null
        ? null
        : IconButton(
            onPressed: onSuffixTap,
            tooltip: suffixIconLabel,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: tokens.muted,
          ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: tokens.muted),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label, style: AppTextStyles.of(context).fieldLabel),
        ),
      ],
    );
  }
}
