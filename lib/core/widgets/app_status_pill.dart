import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

/// Coloured pill used for statuses across the new modules.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tinted icon container used at the start of list rows.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    required this.color,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Primary green hero panel used at the top of the new feature pages.
class AppHeroPanel extends StatelessWidget {
  const AppHeroPanel({
    required this.title,
    required this.subtitle,
    this.icon,
    this.trailing,
    this.leading,
    this.footnote,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? leading;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(22),
        boxShadow: tokens.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: tokens.brandOnDark, size: 27),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.brandOnDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.brandOnDark,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (leading != null) ...[const SizedBox(height: 18), leading!],
          if (footnote != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: tokens.brandOnDark,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    footnote!,
                    style: TextStyle(
                      color: tokens.brandOnDarkMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
