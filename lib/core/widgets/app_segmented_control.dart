import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Segmented choice control, used where a resident picks one of a few options
/// such as a priority or a role.
///
/// A row of tappable cards is far easier to hit on a phone than a dropdown, and
/// it keeps every option visible at once. Each option carries a check when it is
/// active, so the selection does not rely on colour alone.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    this.label,
    this.icons,
    this.colors,
    this.optionKey,
    this.height = 56,
    super.key,
  });

  /// Option value to its label. A [Map] keeps the order the options appear in.
  final Map<T, String> segments;

  final T value;
  final ValueChanged<T> onChanged;

  /// Label above the control. Optional, for use next to an existing heading.
  final String? label;

  /// Optional icon per option, aligned with [segments].
  final Map<T, IconData>? icons;

  /// Optional active colour per option. Used where the colour carries meaning,
  /// such as a severity, so the choice is still readable at a glance.
  final Map<T, Color>? colors;

  /// Builds the widget key for an option, so screens and tests can address it.
  final String Function(T value)? optionKey;

  final double height;

  @override
  Widget build(BuildContext context) {
    final options = segments.entries.toList();
    final control = Row(
      children: [
        for (final entry in options) ...[
          Expanded(
            child: _SegmentOption(
              key: optionKey == null ? null : ValueKey(optionKey!(entry.key)),
              label: entry.value,
              icon: icons?[entry.key],
              activeColor: colors?[entry.key] ?? AppPalette.brand,
              selected: entry.key == value,
              onTap: () => onChanged(entry.key),
            ),
          ),
          if (entry.key != options.last.key) const SizedBox(width: 10),
        ],
      ],
    );

    if (label == null) {
      return control;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppSpacing.fieldLabelGap),
        SizedBox(height: height, child: control),
      ],
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeColor,
    this.icon,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  /// Colour used for the border, tint and label while this option is active.
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final active = activeColor;
    return Material(
      color: selected ? active.withValues(alpha: 0.1) : AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: selected ? active : AppPalette.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? active : AppPalette.muted,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? active : AppPalette.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // A tick as well as the tint, so the choice is not colour only.
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_rounded, size: 15, color: active),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
