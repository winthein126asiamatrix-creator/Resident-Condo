import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../domain/entities/facility.dart';
import '../controllers/facility_controller.dart';
import '../widgets/facility_labels.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

class FacilityDetailPage extends GetView<FacilityController> {
  const FacilityDetailPage({required this.facility, super.key});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = _currentFacility();
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Facility details'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.pageTop, AppSpacing.gutter, 32),
          children: [
            _FacilityHero(facility: current),
            const SizedBox(height: 20),
            _Section(
              title: 'About this facility',
              child: Text(
                current.description,
                style: const TextStyle(color: Color(0xFF52635F), height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Good to know',
              child: Column(
                children: [
                  _Line(label: 'Location', value: current.location),
                  _Line(label: 'Opening hours', value: current.openingHours),
                  _Line(label: 'Capacity', value: '${current.capacity} people'),
                  _Line(label: 'Rules', value: current.rules),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Available slots',
              child: current.availableSlots.isEmpty
                  ? const Text(
                      'No slots available',
                      style: TextStyle(color: Color(0xFF71807D)),
                    )
                  : Wrap(
                      spacing: 8,
                      children: current.availableSlots
                          .map(
                            (slot) => Chip(
                              label: Text(slot),
                              avatar: const Icon(
                                Icons.schedule_outlined,
                                size: 16,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: current.availableSlots.isEmpty
                  ? null
                  : () {
                      controller.selectFacility(current);
                      Get.toNamed(AppRoutes.facilityReserve);
                    },
              icon: const Icon(Icons.event_available_rounded, size: 18),
              label: const Text('Reserve facility'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE07A5F),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      );
    });
  }

  Facility _currentFacility() {
    return controller.facilities.firstWhere(
      (item) => item.id == facility.id,
      orElse: () => facility,
    );
  }
}

class _FacilityHero extends StatelessWidget {
  const _FacilityHero({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 230,
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
                  size: 72,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x11000000), Color(0xAA000000)],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${facility.capacity} capacity',
                  style: const TextStyle(
                    color: Color(0xFF1D2B2A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayFacilityName(facility.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${facility.location} · ${facility.openingHours}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EEEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF71807D)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
