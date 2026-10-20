import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme_tokens.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = _colorFor(label, tokens);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _colorFor(String value, AppThemeTokens tokens) {
    final normalized = value.toLowerCase();
    if (normalized.contains('completed') || normalized.contains('confirmed')) {
      return Color(0xFF087F5B);
    }
    if (normalized.contains('progress') || normalized.contains('upcoming')) {
      return Color(0xFFB45309);
    }
    if (normalized.contains('urgent') || normalized.contains('overdue')) {
      return Color(0xFFC2410C);
    }
    return tokens.brand;
  }
}
