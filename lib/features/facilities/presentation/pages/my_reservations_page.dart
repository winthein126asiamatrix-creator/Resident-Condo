import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/utils/app_dates.dart';

import '../../../../core/widgets/app_card.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_section.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../domain/entities/facility.dart';

import '../controllers/facility_controller.dart';

import '../widgets/facility_labels.dart';

import '../widgets/reservation_status_badge.dart';

/// Every reservation the resident has made, split into what is still ahead and
/// what has already happened.
class MyReservationsPage extends StatefulWidget {
  const MyReservationsPage({super.key});

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  // A stateful page rather than a GetView so the list is refreshed when the
  // screen is opened, which is what makes a brand new reservation show up here
  // straight after booking it.
  final FacilityController controller = Get.find<FacilityController>();

  @override
  void initState() {
    super.initState();
    controller.loadReservations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'My Reservations',
        subtitle: 'Your bookings and past visits',
        onBack: () {
          // Reached from the facilities tab this pops; reached from the success
          // page it is the only route left, so it returns to the app shell.
          if (Get.key.currentState?.canPop() ?? false) {
            Get.back<void>();
          } else {
            Get.offAllNamed(AppRoutes.home);
          }
        },
      ),
      body: Obx(() {
        if (controller.isReservationsLoading.value &&
            controller.reservations.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        final error = controller.reservationsError.value;
        if (error != null && controller.reservations.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load reservations',
            message: error,
            icon: Icons.event_busy_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadReservations,
          );
        }
        if (controller.reservations.isEmpty) {
          return AppStateMessage(
            key: Key('my-reservations-empty'),
            title: 'No Reservations Yet',
            message: "You haven't reserved any facilities yet.",
            icon: Icons.event_available_outlined,
            actionLabel: 'Explore Facilities',
            onAction: () => Get.offAllNamed(AppRoutes.home),
          );
        }

        final upcoming = controller.upcomingReservations;
        final past = controller.pastReservations;

        return RefreshIndicator(
          onRefresh: controller.loadReservations,
          child: ListView(
            key: Key('my-reservations-scroll'),
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (upcoming.isNotEmpty) ...[
                AppSectionHeader(title: 'Upcoming', count: upcoming.length),
                10.h.heightBox(),
                for (final reservation in upcoming)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _ReservationCard(
                      reservation: reservation,
                      facility: controller.facilityById(reservation.facilityId),
                    ),
                  ),
              ],
              if (past.isNotEmpty) ...[
                (upcoming.isEmpty ? 0 : 16.h).heightBox(),
                AppSectionHeader(title: 'Past', count: past.length),
                10.h.heightBox(),
                for (final reservation in past)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _ReservationCard(
                      reservation: reservation,
                      facility: controller.facilityById(reservation.facilityId),
                    ),
                  ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, this.facility});

  final FacilityReservation reservation;

  /// Used for the photo when the facility is still loaded; the card falls back
  /// to an icon when it is not.
  final Facility? facility;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      key: Key('reservation-card-${reservation.id}'),
      padding: EdgeInsets.all(14),
      onTap: () {
        vibrateNow();
        Get.toNamed(AppRoutes.reservationDetail, arguments: reservation);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FacilityThumb(facility: facility),
          13.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayFacilityName(reservation.facilityName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.ink,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    8.w.widthBox(),
                    ReservationStatusBadge(
                      reservation: reservation,
                      dense: true,
                    ),
                  ],
                ),
                8.h.heightBox(),
                _MetaLine(
                  icon: Icons.calendar_today_rounded,
                  label: AppDates.formatLong(AppDates.parse(reservation.date)),
                ),
                4.h.heightBox(),
                _MetaLine(
                  icon: Icons.schedule_rounded,
                  label: reservation.time,
                ),
                if (reservation.id.isNotEmpty) ...[
                  8.h.heightBox(),
                  Text(
                    '#${reservation.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.faint,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Icon(icon, size: 13, color: tokens.muted),
        6.w.widthBox(),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.muted, fontSize: 12.5.sp),
          ),
        ),
      ],
    );
  }
}

/// Small square facility photo with the same fallback the amenities grid uses.
class _FacilityThumb extends StatelessWidget {
  const _FacilityThumb({this.facility});

  final Facility? facility;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final imagePath = facility?.imagePath;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(16.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? Icon(Icons.apartment_rounded, color: tokens.brandOnDark, size: 26)
          : Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.apartment_rounded,
                color: tokens.brandOnDark,
                size: 26,
              ),
            ),
    );
  }
}
