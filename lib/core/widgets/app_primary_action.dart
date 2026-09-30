import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The resident facing primary call to action.
///
/// It is a full width brand filled card with a comfortable touch target, a
/// leading icon and an optional trailing affordance. Disabled and loading
/// states are handled here so every CTA in the app looks and behaves the same.
class AppPrimaryAction extends StatelessWidget {
  const AppPrimaryAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.height = 56,
    this.backgroundColor = AppPalette.brand,
    this.centerContent = true,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final double height;
  final Color backgroundColor;

  /// Centres the icon and label. Set to false to left align them and push the
  /// [trailingIcon] to the far edge.
  final bool centerContent;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(18);
    final background = enabled ? backgroundColor : AppPalette.surfaceMuted;
    final foreground = enabled ? Colors.white : AppPalette.faint;

    final content = SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            )
          else if (icon != null) ...[
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 15.5,
                letterSpacing: 0.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!centerContent && expand) const Spacer(),
          if (trailingIcon != null && !isLoading) ...[
            const SizedBox(width: 10),
            Icon(trailingIcon, size: 20, color: foreground),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.26),
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
            color: enabled ? Colors.transparent : AppPalette.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: content,
          ),
        ),
      ),
    );
  }
}
