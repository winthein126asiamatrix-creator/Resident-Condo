import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

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
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      // The same custom bar as the reservation and maintenance screens.
      appBar: AppDetailAppBar(
        title: 'Reservation Confirmed',
        subtitle: 'Your booking is complete',
        onBack: () => Get.offAllNamed(AppRoutes.home),
      ),
      body: ListView(
        key: Key('booking-confirmed-scroll'),
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
              decoration: BoxDecoration(
                color: tokens.brandTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: AppPalette.success,
                size: 48,
              ),
            ),
          ),
          22.h.heightBox(),
          Text(
            'Reservation Confirmed',
            key: Key('booking-confirmed-title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          8.h.heightBox(),
          Text(
            'Your facility reservation has been successfully confirmed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, height: 1.4),
          ),
          26.h.heightBox(),
          AppCard(
            key: Key('booking-confirmed-summary'),
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
          22.h.heightBox(),
          AppPrimaryAction(
            key: Key('booking-confirmed-done'),
            onPressed: () => Get.offAllNamed(AppRoutes.myReservations),
            label: 'Done',
            icon: Icons.check_rounded,
          ),
          12.h.heightBox(),
          Center(
            child: TextButton.icon(
              key: Key('booking-confirmed-facilities'),
              onPressed: () => Get.offAllNamed(AppRoutes.home),
              icon: Icon(Icons.event_available_rounded, size: 18),
              label: Text('Back to Facilities'),
              style: TextButton.styleFrom(foregroundColor: tokens.brand),
            ),
          ),
        ],
      ),
    );
  }
}
