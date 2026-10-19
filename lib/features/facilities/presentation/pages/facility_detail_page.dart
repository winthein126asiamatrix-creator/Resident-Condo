import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../domain/entities/facility.dart';


import '../controllers/facility_controller.dart';


import '../widgets/facility_labels.dart';


import '../../../../core/widgets/app_detail_app_bar.dart';


import '../../../../core/theme/app_spacing.dart';


import '../../../../core/theme/app_theme_tokens.dart';

class FacilityDetailPage extends GetView<FacilityController> {
  FacilityDetailPage({required this.facility, super.key});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = _currentFacility();
      final tokens = AppThemeTokens.of(context);
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Facility details'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32,
          ),
          children: [
            _FacilityHero(facility: current),
            20.h.heightBox(),
            _Section(
              title: 'About this facility',
              child: Text(
                current.description,
                style: TextStyle(color: tokens.mutedStrong, height: 1.45),
              ),
            ),
            16.h.heightBox(),
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
            16.h.heightBox(),
            _Section(
              title: 'Available slots',
              child: current.availableSlots.isEmpty
                  ? Text(
                      'No slots available',
                      style: TextStyle(color: tokens.muted),
                    )
                  : Wrap(
                      spacing: 8,
                      children: current.availableSlots
                          .map(
                            (slot) => Chip(
                              label: Text(slot),
                              avatar: Icon(Icons.schedule_outlined, size: 16),
                            ),
                          )
                          .toList(),
                    ),
            ),
            20.h.heightBox(),
            FilledButton.icon(
              onPressed: current.availableSlots.isEmpty
                  ? null
                  : () {
                      vibrateNow();
                      controller.selectFacility(current);
                      Get.toNamed(AppRoutes.facilityReserve);
                    },
              icon: Icon(Icons.event_available_rounded, size: 18),
              label: Text('Reserve facility'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.brand,
                foregroundColor: tokens.onBrand,
                minimumSize: Size.fromHeight(52),
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
  _FacilityHero({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
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
                color: tokens.brand,
                child: Icon(
                  Icons.apartment_rounded,
                  color: Colors.white70,
                  size: 72,
                ),
              ),
            ),
            DecoratedBox(
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
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '${facility.capacity} capacity',
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 11.sp,
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  5.h.heightBox(),
                  Text(
                    '${facility.location} Â· ${facility.openingHours}',
                    style: TextStyle(color: Colors.white70, fontSize: 13.sp),
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
  _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
          ),
          8.h.heightBox(),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: tokens.muted)),
          ),
          12.w.widthBox(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
