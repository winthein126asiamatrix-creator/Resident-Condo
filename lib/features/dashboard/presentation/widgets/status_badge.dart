import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _colorFor(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('completed') || normalized.contains('confirmed')) {
      return const Color(0xFF087F5B);
    }
    if (normalized.contains('progress') || normalized.contains('upcoming')) {
      return const Color(0xFFB45309);
    }
    if (normalized.contains('urgent') || normalized.contains('overdue')) {
      return const Color(0xFFC2410C);
    }
    return const Color(0xFF0F766E);
  }
}
