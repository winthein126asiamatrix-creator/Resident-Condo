import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../../../core/theme/app_theme_tokens.dart';


import '../../../../core/widgets/app_state_message.dart';


import '../../domain/entities/facility.dart';


import '../controllers/facility_controller.dart';


import '../widgets/facility_labels.dart';

class FacilitiesPage extends GetView<FacilityController> {
  FacilitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Obx(
          () => controller.isLoading.value && controller.facilities.isEmpty
              ? Center(child: CircularProgressIndicator())
              : controller.errorMessage.value != null &&
                    controller.facilities.isEmpty
              ? AppStateMessage(
                  title: 'Unable to load facilities',
                  message: controller.errorMessage.value!,
                  icon: Icons.event_available_outlined,
                  actionLabel: 'Try again',
                  onAction: controller.loadFacilities,
                )
              : RefreshIndicator(
                  onRefresh: controller.loadFacilities,
                  child: ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      _FacilitiesHeader(onRefresh: controller.loadFacilities),
                      20.h.heightBox(),
                      _FacilitySummary(
                        facilityCount: controller.facilities.length,
                        reservationCount: controller.reservations.length,
                      ),
                      14.h.heightBox(),
                      // Secondary entry point, kept out of the way of browsing.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: Key('facilities-my-reservations'),
                          onPressed: () =>
                              Get.toNamed(AppRoutes.myReservations),
                          icon: Icon(Icons.event_note_rounded, size: 18),
                          label: Text('My Reservations'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.brand,
                            backgroundColor: tokens.surface,
                            side: BorderSide(color: tokens.border),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                        ),
                      ),
                      22.h.heightBox(),
                      _SectionHeader(
                        title: 'Amenities',
                        count: controller.facilities.length,
                      ),
                      10.h.heightBox(),
                      if (controller.facilities.isEmpty)
                        AppStateMessage(
                          title: 'No facilities',
                          message: 'Amenities will appear here when available.',
                          icon: Icons.event_available_outlined,
                        )
                      else
                        _ResponsiveFacilityGrid(
                          facilities: controller.facilities,
                          onReserve: _reserveFacility,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _reserveFacility(Facility facility) {
    controller.selectFacility(facility);
    Get.toNamed(AppRoutes.facilityReserve);
  }
}

class _FacilitiesHeader extends StatelessWidget {
  _FacilitiesHeader({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Facilities',
                style: TextStyle(
                  fontSize: 25.sp,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
              4.h.heightBox(),
              Text(
                'Find your next place to unwind',
                style: TextStyle(color: tokens.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh facilities',
          icon: Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _FacilitySummary extends StatelessWidget {
  _FacilitySummary({
    required this.facilityCount,
    required this.reservationCount,
  });

  final int facilityCount;
  final int reservationCount;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: tokens.heroShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17.r),
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: tokens.brandOnDark,
              size: 27,
            ),
          ),
          14.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your amenities',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                6.h.heightBox(),
                Text(
                  '$facilityCount facilities Â· $reservationCount reservations',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tokens.brandOnDark),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: tokens.ink),
        ),
        7.w.widthBox(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.brandTint,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: tokens.brand,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFacilityGrid extends StatelessWidget {
  _ResponsiveFacilityGrid({required this.facilities, required this.onReserve});

  final List<Facility> facilities;
  final ValueChanged<Facility> onReserve;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: facilities
              .map(
                (facility) => SizedBox(
                  width: cardWidth,
                  child: _FacilityCard(
                    facility: facility,
                    onReserve: onReserve,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _FacilityCard extends StatelessWidget {
  _FacilityCard({required this.facility, required this.onReserve});

  final Facility facility;
  final ValueChanged<Facility> onReserve;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final available = facility.availableSlots.isNotEmpty;
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.facilityDetail, arguments: facility),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: tokens.border),
          boxShadow: tokens.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    facility.imagePath,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => Container(
                      color: tokens.brand,
                      child: Icon(
                        Icons.apartment_rounded,
                        color: Colors.white70,
                        size: 54,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x66000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            facility.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _AvailabilityBadge(available: available),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 15, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayFacilityName(facility.name),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17.sp,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: tokens.brand,
                        size: 20,
                      ),
                    ],
                  ),
                  7.h.heightBox(),
                  Text(
                    facility.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 12.sp,
                      height: 1.35,
                    ),
                  ),
                  12.h.heightBox(),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: tokens.muted,
                      ),
                      5.w.widthBox(),
                      Expanded(
                        child: Text(
                          facility.openingHours,
                          style: TextStyle(
                            color: tokens.mutedStrong,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  8.h.heightBox(),
                  Row(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 16,
                        color: tokens.muted,
                      ),
                      5.w.widthBox(),
                      Text(
                        '${facility.capacity} capacity',
                        style: TextStyle(
                          color: tokens.mutedStrong,
                          fontSize: 11.sp,
                        ),
                      ),
                      Spacer(),
                      Text(
                        available ? 'Available' : 'Fully booked',
                        style: TextStyle(
                          color: available
                              ? Color(0xFF087F5B)
                              : Color(0xFFC2410C),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  14.h.heightBox(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: Key('reserve-facility-${facility.id}'),
                      onPressed: () => onReserve(facility),
                      icon: Icon(Icons.event_available_rounded, size: 18),
                      label: Text('Reserve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.brand,
                        foregroundColor: tokens.onBrand,
                        minimumSize: Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  _AvailabilityBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.brandTint.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        available ? 'Available' : 'Fully booked',
        style: TextStyle(
          color: available ? Color(0xFF087F5B) : Color(0xFFC2410C),
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
