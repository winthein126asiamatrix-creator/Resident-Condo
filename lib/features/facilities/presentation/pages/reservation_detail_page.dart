import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/entities/facility.dart';
import '../controllers/facility_controller.dart';
import '../widgets/facility_labels.dart';
import '../widgets/reservation_status_badge.dart';

/// Read only view of a single reservation.
///
/// Cancellation is deliberately absent: the repository has no cancel operation,
/// so offering the action would be a button that cannot work.
class ReservationDetailPage extends StatelessWidget {
  const ReservationDetailPage({required this.reservation, super.key});

  final FacilityReservation reservation;

  @override
  Widget build(BuildContext context) {
    final facility = Get.isRegistered<FacilityController>()
        ? Get.find<FacilityController>().facilityById(reservation.facilityId)
        : null;

    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Reservation Details',
        subtitle: 'Everything you booked',
        onBack: () => Get.back<void>(),
      ),
      body: ListView(
        key: const Key('reservation-detail-scroll'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _FacilityHero(facility: facility, reservation: reservation),
          const SizedBox(height: 18),
          AppCard(
            key: const Key('reservation-detail-summary'),
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
                if (reservation.createdAt.isNotEmpty)
                  AppLabelValueRow(
                    label: 'Booked on',
                    value: reservation.createdAt,
                  ),
              ],
            ),
          ),
          if (facility != null) ...[
            const SizedBox(height: 18),
            AppSectionCard(
              title: 'Good to know',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabelValueRow(label: 'Location', value: facility.location),
                  AppLabelValueRow(
                    label: 'Opening hours',
                    value: facility.openingHours,
                  ),
                  AppLabelValueRow(
                    label: 'Capacity',
                    value: '${facility.capacity} people',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FacilityHero extends StatelessWidget {
  const _FacilityHero({required this.reservation, this.facility});

  final FacilityReservation reservation;
  final Facility? facility;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final imagePath = facility?.imagePath;
    return Container(
      decoration: BoxDecoration(
        color: tokens.brandTint,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: imagePath == null
                ? ColoredBox(
                    color: tokens.brand,
                    child: Center(
                      child: Icon(
                        Icons.apartment_rounded,
                        color: tokens.brandOnDark,
                        size: 48,
                      ),
                    ),
                  )
                : Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: tokens.brand,
                      child: Center(
                        child: Icon(
                          Icons.apartment_rounded,
                          color: tokens.brandOnDark,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    displayFacilityName(reservation.facilityName),
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ReservationStatusBadge(reservation: reservation),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
