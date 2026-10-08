import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/condo_service.dart';

IconData serviceIcon(ServiceCategory category) {
  switch (category) {
    case ServiceCategory.cleaning:
      return Icons.cleaning_services_outlined;
    case ServiceCategory.laundry:
      return Icons.local_laundry_service_outlined;
    case ServiceCategory.pestControl:
      return Icons.pest_control_outlined;
    case ServiceCategory.waste:
      return Icons.delete_outline_rounded;
    case ServiceCategory.aircon:
      return Icons.ac_unit_rounded;
    case ServiceCategory.catering:
      return Icons.restaurant_outlined;
    case ServiceCategory.moving:
      return Icons.local_shipping_outlined;
    case ServiceCategory.other:
      return Icons.handyman_outlined;
  }
}

Color serviceStatusColor(ServiceRequestStatus status, AppThemeTokens tokens) {
  switch (status) {
    case ServiceRequestStatus.requested:
      return AppPalette.info;
    case ServiceRequestStatus.scheduled:
      return AppPalette.warning;
    case ServiceRequestStatus.inProgress:
      return tokens.brand;
    case ServiceRequestStatus.completed:
      return AppPalette.success;
    case ServiceRequestStatus.cancelled:
      return AppPalette.danger;
  }
}

class ServiceStatusPill extends StatelessWidget {
  const ServiceStatusPill({required this.status, this.dense = true, super.key});

  final ServiceRequestStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: serviceStatusColor(status, AppThemeTokens.of(context)),
      dense: dense,
    );
  }
}
