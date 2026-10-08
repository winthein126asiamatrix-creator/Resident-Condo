import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/complaint.dart';

Color complaintStatusColor(ComplaintStatus status, AppThemeTokens tokens) {
  switch (status) {
    case ComplaintStatus.submitted:
      return AppPalette.info;
    case ComplaintStatus.inReview:
      return AppPalette.warning;
    case ComplaintStatus.actionTaken:
      return tokens.brand;
    case ComplaintStatus.resolved:
      return AppPalette.success;
    case ComplaintStatus.withdrawn:
      return tokens.faint;
  }
}

class ComplaintStatusPill extends StatelessWidget {
  const ComplaintStatusPill({
    required this.status,
    this.dense = true,
    super.key,
  });

  final ComplaintStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: complaintStatusColor(status, AppThemeTokens.of(context)),
      dense: dense,
    );
  }
}
