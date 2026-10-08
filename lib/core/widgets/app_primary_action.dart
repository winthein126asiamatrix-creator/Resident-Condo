import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

/// The resident facing primary call to action.
///
/// It is a full width brand filled card with a comfortable touch target, a
/// leading icon and an optional trailing affordance. Disabled and loading
/// states are handled here so every CTA in the app looks and behaves the same.
///
/// The fill defaults to the theme's brand colour, so every primary button in the
/// app follows the resident's choice. Pass [backgroundColor] only to override it
/// for a genuinely different action.
class AppPrimaryAction extends StatelessWidget {
  const AppPrimaryAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.height = 56,
    this.backgroundColor,
    this.foregroundColor,
    this.centerContent = true,
    this.expand = true,
    this.padding,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final double height;

  /// Overrides the brand fill, for an action that must not read as the primary
  /// one (a destructive confirm, for example).
  final Color? backgroundColor;

  /// Overrides the label and icon colour drawn on [backgroundColor].
  final Color? foregroundColor;

  /// Centres the icon and label. Set to false to left align them and push the
  /// [trailingIcon] to the far edge.
  final bool centerContent;
  final bool expand;

  /// Overrides the default horizontal padding, for a compact button that sits
  /// inside a card rather than at the foot of a form.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(18);
    final fill = backgroundColor ?? tokens.brand;
    final background = enabled ? fill : tokens.surfaceMuted;
    final foreground =
        enabled ? (foregroundColor ?? tokens.onBrand) : tokens.faint;

    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: foreground,
        fontSize: 15.5,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w800,
      ),
    );

    final hasLeading = isLoading || icon != null;
    final hasTrailing = trailingIcon != null && !isLoading;

    Widget leading() {
      if (isLoading) {
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(foreground),
          ),
        );
      }
      if (icon == null) {
        return const SizedBox.shrink();
      }
      return Icon(icon, size: 20, color: foreground);
    }

    Widget trailing() {
      if (trailingIcon == null || isLoading) {
        return const SizedBox.shrink();
      }
      return Icon(trailingIcon, size: 20, color: foreground);
    }

    /// Width an icon occupies next to the label, gap included.
    double iconSlot() => isLoading ? 28 : 30;

    // Centred mode reserves the same space on both sides, so an icon sitting in
    // the left slot cannot drag the label off centre: the text stays in the
    // middle of the button and the icon fills the gap beside it.
    final content = SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: centerContent
          ? Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasLeading)
                  SizedBox(
                    width: iconSlot(),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: leading(),
                    ),
                  ),
                Flexible(child: labelText),
                if (hasTrailing || hasLeading)
                  SizedBox(
                    width: iconSlot(),
                    child: hasTrailing
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: trailing(),
                          )
                        : null,
                  ),
              ],
            )
          : Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (hasLeading) ...[leading(), const SizedBox(width: 10)],
                Flexible(child: labelText),
                if (expand) const Spacer(),
                if (hasTrailing) ...[const SizedBox(width: 10), trailing()],
              ],
            ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: fill.withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: enabled ? Colors.transparent : tokens.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding:
                padding ?? const EdgeInsets.symmetric(horizontal: 20),
            child: content,
          ),
        ),
      ),
    );
  }
}
