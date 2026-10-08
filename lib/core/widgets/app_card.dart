import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

/// Standard surface used by every list card in the app.
///
/// The colours come from [AppThemeTokens] rather than a fixed palette, so a card
/// picks up the resident's Light / Dark choice while its shape, padding and
/// spacing stay identical. Pass [color] or [borderColor] only to override the
/// theme, for the handful of cards that carry a status tint.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.borderRadius = 20,
    this.showShadow = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Defaults to the theme's card surface.
  final Color? color;

  /// Defaults to the theme's hairline border.
  final Color? borderColor;

  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final shape = BorderRadius.circular(borderRadius);
    return InkWell(
      onTap: onTap,
      borderRadius: shape,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? tokens.surface,
          borderRadius: shape,
          border: Border.all(color: borderColor ?? tokens.border),
          boxShadow: showShadow ? tokens.cardShadow : null,
        ),
        child: child,
      ),
    );
  }
}