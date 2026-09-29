import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/complaint.dart';

Color complaintStatusColor(ComplaintStatus status) {
  switch (status) {
    case ComplaintStatus.submitted:
      return AppPalette.info;
    case ComplaintStatus.inReview:
      return AppPalette.warning;
    case ComplaintStatus.actionTaken:
      return AppPalette.brand;
    case ComplaintStatus.resolved:
      return AppPalette.success;
    case ComplaintStatus.withdrawn:
      return AppPalette.faint;
  }
}

class ComplaintStatusPill extends StatelessWidget {
  const ComplaintStatusPill({required this.status, this.dense = true, super.key});

  final ComplaintStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: complaintStatusColor(status),
      dense: dense,
    );
  }
}
