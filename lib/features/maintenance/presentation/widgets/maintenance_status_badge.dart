import 'package:flutter/material.dart';

import '../../domain/entities/maintenance_request.dart';

class MaintenanceStatusBadge extends StatelessWidget {
  const MaintenanceStatusBadge({required this.status, super.key});

  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MaintenanceStatus.submitted => ('Submitted', const Color(0xFF52635F)),
      MaintenanceStatus.assigned => ('Assigned', const Color(0xFF5B4CC4)),
      MaintenanceStatus.inProgress => ('In Progress', const Color(0xFFB45309)),
      MaintenanceStatus.completed => ('Completed', const Color(0xFF087F5B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
