import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/visitor.dart';

Color visitorStatusColor(VisitorStatus status) {
  switch (status) {
    case VisitorStatus.preRegistered:
      return AppPalette.info;
    case VisitorStatus.checkedIn:
      return AppPalette.success;
    case VisitorStatus.checkedOut:
      return AppPalette.mutedStrong;
    case VisitorStatus.cancelled:
      return AppPalette.danger;
    case VisitorStatus.expired:
      return AppPalette.faint;
  }
}

class VisitorStatusPill extends StatelessWidget {
  const VisitorStatusPill({required this.status, super.key});

  final VisitorStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: visitorStatusColor(status),
    );
  }
}
