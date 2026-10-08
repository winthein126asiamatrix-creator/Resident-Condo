import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/rules.dart';

Color violationStatusColor(ViolationStatus status) {
  switch (status) {
    case ViolationStatus.open:
      return AppPalette.danger;
    case ViolationStatus.appealed:
      return AppPalette.warning;
    case ViolationStatus.appealApproved:
      return AppPalette.success;
    case ViolationStatus.appealRejected:
      return AppPalette.danger;
    case ViolationStatus.paid:
      return AppPalette.success;
    case ViolationStatus.closed:
      return AppPalette.faint;
  }
}

class ViolationStatusPill extends StatelessWidget {
  const ViolationStatusPill({required this.status, this.dense = true, super.key});

  final ViolationStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: violationStatusColor(status),
      dense: dense,
    );
  }
}

Color appealStatusColor(AppealStatus status, AppThemeTokens tokens) {
  switch (status) {
    case AppealStatus.pending:
      return AppPalette.warning;
    case AppealStatus.underReview:
      return AppPalette.info;
    case AppealStatus.approved:
      return AppPalette.success;
    case AppealStatus.rejected:
      return AppPalette.danger;
    case AppealStatus.withdrawn:
      return tokens.faint;
  }
}

class AppealStatusPill extends StatelessWidget {
  const AppealStatusPill({required this.status, super.key});

  final AppealStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: appealStatusColor(status, AppThemeTokens.of(context)),
      dense: true,
    );
  }
}

IconData ruleCategoryIcon(RuleCategory category) {
  switch (category) {
    case RuleCategory.noise:
      return Icons.volume_up_outlined;
    case RuleCategory.parking:
      return Icons.local_parking_rounded;
    case RuleCategory.pets:
      return Icons.pets_outlined;
    case RuleCategory.appearance:
      return Icons.home_work_outlined;
    case RuleCategory.waste:
      return Icons.delete_outline_rounded;
    case RuleCategory.safety:
      return Icons.health_and_safety_outlined;
    case RuleCategory.commonAreas:
      return Icons.chair_outlined;
  }
}
