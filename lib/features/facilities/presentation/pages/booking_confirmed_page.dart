import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/entities/facility.dart';
import '../widgets/facility_labels.dart';
import '../widgets/reservation_status_badge.dart';

/// Success state shown once a reservation has actually been created.
class BookingConfirmedPage extends StatelessWidget {
  const BookingConfirmedPage({required this.reservation, super.key});

  final FacilityReservation reservation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The same custom bar as the reservation and maintenance screens.
      appBar: AppDetailAppBar(
        title: 'Reservation Confirmed',
        subtitle: 'Your booking is complete',
        onBack: () => Get.offAllNamed(AppRoutes.home),
      ),
      body: ListView(
        key: const Key('booking-confirmed-scroll'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          26,
          AppSpacing.gutter,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: AppPalette.brandTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppPalette.success,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Reservation Confirmed',
            key: Key('booking-confirmed-title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your facility reservation has been successfully confirmed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.muted, height: 1.4),
          ),
          const SizedBox(height: 26),
          AppCard(
            key: const Key('booking-confirmed-summary'),
            child: Column(
              children: [
                AppLabelValueRow(
                  label: 'Facility',
                  value: displayFacilityName(reservation.facilityName),
                  emphasize: true,
                ),
                AppLabelValueRow(
                  label: 'Date',
                  value: AppDates.formatLong(AppDates.parse(reservation.date)),
                ),
                AppLabelValueRow(label: 'Time', value: reservation.time),
                AppLabelValueRow(
                  label: 'Status',
                  valueWidget: Align(
                    alignment: Alignment.centerRight,
                    child: ReservationStatusBadge(reservation: reservation),
                  ),
                ),
                if (reservation.id.isNotEmpty)
                  AppLabelValueRow(
                    label: 'Reservation',
                    value: '#${reservation.id}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AppPrimaryAction(
            key: const Key('booking-confirmed-done'),
            onPressed: () => Get.offAllNamed(AppRoutes.myReservations),
            label: 'Done',
            icon: Icons.check_rounded,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              key: const Key('booking-confirmed-facilities'),
              onPressed: () => Get.offAllNamed(AppRoutes.home),
              icon: const Icon(Icons.event_available_rounded, size: 18),
              label: const Text('Back to Facilities'),
              style: TextButton.styleFrom(foregroundColor: AppPalette.brand),
            ),
          ),
        ],
      ),
    );
  }
}
