import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';
import 'app_card.dart';

/// Section title with optional count chip and trailing action.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: tokens.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.brandTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: tokens.brand,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Two column label / value row reused by the detail pages.
class AppLabelValueRow extends StatelessWidget {
  const AppLabelValueRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.emphasize = false,
    super.key,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasize ? tokens.ink : tokens.muted,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          valueWidget ??
              Flexible(
                child: Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: emphasize ? tokens.brand : tokens.ink,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Titled card wrapper: `AppSectionCard(title: ..., child: ...)`.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: tokens.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
