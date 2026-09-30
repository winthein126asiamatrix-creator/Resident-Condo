import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

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

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, icon: multiline ? icon : null),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          cursorColor: AppPalette.brand,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: appFormFieldDecoration(
            hint: hint,
            icon: multiline ? null : icon,
            helperText: helperText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, icon: icon),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          key: fieldKey,
          initialValue: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
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
  String? hint,
  IconData? icon,
  String? helperText,
  bool isSelect = false,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppPalette.faint,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    helperText: helperText,
    helperMaxLines: 2,
    helperStyle: const TextStyle(color: AppPalette.muted, fontSize: 12),
    filled: true,
    fillColor: AppPalette.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    prefixIconColor: AppPalette.muted,
    prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 24),
    suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 24),
    border: border(AppPalette.border),
    enabledBorder: border(AppPalette.border),
    focusedBorder: border(AppPalette.brand, 1.6),
    errorBorder: border(AppPalette.danger, 1.2),
    focusedErrorBorder: border(AppPalette.danger, 1.6),
    disabledBorder: border(AppPalette.border),
    errorMaxLines: 2,
    errorStyle: const TextStyle(
      color: AppPalette.danger,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    // The select field already renders its own chevron.
    suffixIcon: isSelect
        ? const Icon(Icons.keyboard_arrow_down_rounded, color: AppPalette.muted)
        : null,
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppPalette.muted),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: AppPalette.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
