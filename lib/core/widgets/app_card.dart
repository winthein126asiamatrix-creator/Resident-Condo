import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Standard white surface used by every list card in the app.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.borderColor = AppPalette.border,
    this.borderRadius = 20,
    this.showShadow = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(borderRadius);
    return InkWell(
      onTap: onTap,
      borderRadius: shape,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: shape,
          border: Border.all(color: borderColor),
          boxShadow: showShadow ? AppPalette.cardShadow : null,
        ),
        child: child,
      ),
    );
  }
}
