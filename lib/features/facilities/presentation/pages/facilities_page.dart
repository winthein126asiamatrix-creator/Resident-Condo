import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/facility.dart';
import '../controllers/facility_controller.dart';

class FacilitiesPage extends GetView<FacilityController> {
  const FacilitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: Obx(
          () => controller.isLoading.value && controller.facilities.isEmpty
              ? const Center(child: CircularProgressIndicator())
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      _FacilitiesHeader(onRefresh: controller.loadFacilities),
                      const SizedBox(height: 20),
                      _FacilitySummary(
                        facilityCount: controller.facilities.length,
                        reservationCount: controller.reservations.length,
                      ),
                      const SizedBox(height: 25),
                      _SectionHeader(
                        title: 'Amenities',
                        count: controller.facilities.length,
                      ),
                      const SizedBox(height: 10),
                      if (controller.facilities.isEmpty)
                        const AppStateMessage(
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
  const _FacilitiesHeader({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Facilities',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2B2A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Find your next place to unwind',
                style: TextStyle(color: Color(0xFF71807D)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh facilities',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _FacilitySummary extends StatelessWidget {
  const _FacilitySummary({
    required this.facilityCount,
    required this.reservationCount,
  });

  final int facilityCount;
  final int reservationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F766E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Color(0xFFBFE8DF),
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your amenities',
                  style: TextStyle(
                    color: Color(0xFFBFE8DF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$facilityCount facilities · $reservationCount reservations',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFBFE8DF)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1D2B2A),
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F3EF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFacilityGrid extends StatelessWidget {
  const _ResponsiveFacilityGrid({
    required this.facilities,
    required this.onReserve,
  });

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
        const spacing = 12.0;
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
  const _FacilityCard({required this.facility, required this.onReserve});

  final Facility facility;
  final ValueChanged<Facility> onReserve;

  @override
  Widget build(BuildContext context) {
    final available = facility.availableSlots.isNotEmpty;
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.facilityDetail, arguments: facility),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6EEEB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A163A36),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
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
                      color: const Color(0xFF0F766E),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white70,
                        size: 54,
                      ),
                    ),
                  ),
                  const DecoratedBox(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _displayName(facility.name),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Color(0xFF1D2B2A),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF0F766E),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    facility.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71807D),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: Color(0xFF71807D),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          facility.openingHours,
                          style: const TextStyle(
                            color: Color(0xFF52635F),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        size: 16,
                        color: Color(0xFF71807D),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${facility.capacity} capacity',
                        style: const TextStyle(
                          color: Color(0xFF52635F),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        available ? 'Available' : 'Fully booked',
                        style: TextStyle(
                          color: available
                              ? const Color(0xFF087F5B)
                              : const Color(0xFFC2410C),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: Key('reserve-facility-${facility.id}'),
                      onPressed: () => onReserve(facility),
                      icon: const Icon(Icons.event_available_rounded, size: 18),
                      label: const Text('Reserve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
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
  const _AvailabilityBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: available
            ? const Color(0xFFE6F3EF).withValues(alpha: 0.94)
            : const Color(0xFFFCE8DF).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        available ? 'Available' : 'Fully booked',
        style: TextStyle(
          color: available ? const Color(0xFF087F5B) : const Color(0xFFC2410C),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _displayName(String name) {
  if (name == 'Fitness Centre') {
    return 'Gym';
  }
  if (name == 'Rooftop BBQ') {
    return 'BBQ Area';
  }
  return name;
}
