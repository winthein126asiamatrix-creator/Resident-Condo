import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/facility_reservation_status.dart';

/// Status badge for a facility reservation.
///
/// Each status carries an icon and a word as well as a colour, so the state is
/// still readable without relying on colour alone.
class ReservationStatusBadge extends StatelessWidget {
  const ReservationStatusBadge({
    required this.reservation,
    this.dense = false,
    super.key,
  });

  final FacilityReservation reservation;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final status = FacilityReservationStatus.fromLabel(reservation.status);
    final (label, color, icon) = switch (status) {
      FacilityReservationStatus.confirmed => (
        'Confirmed',
        AppPalette.success,
        Icons.check_circle_rounded,
      ),
      FacilityReservationStatus.pending => (
        'Pending',
        AppPalette.warning,
        Icons.schedule_rounded,
      ),
      FacilityReservationStatus.cancelled => (
        'Cancelled',
        AppPalette.danger,
        Icons.cancel_rounded,
      ),
      FacilityReservationStatus.completed => (
        'Completed',
        AppPalette.mutedStrong,
        Icons.task_alt_rounded,
      ),
      FacilityReservationStatus.upcoming => (
        'Upcoming',
        AppPalette.info,
        Icons.event_rounded,
      ),
      // An unknown value from a backend is shown verbatim rather than hidden.
      FacilityReservationStatus.other => (
        reservation.status,
        AppPalette.mutedStrong,
        Icons.help_outline_rounded,
      ),
    };

    return AppStatusPill(label: label, color: color, icon: icon, dense: dense);
  }
}
