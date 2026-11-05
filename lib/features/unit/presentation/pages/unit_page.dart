import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

import '../../domain/entities/unit.dart';

import '../controllers/unit_controller.dart';
import '../widgets/unit_info_tile.dart';
import '../widgets/unit_person_tile.dart';

class UnitPage extends StatefulWidget {
  const UnitPage({super.key});

  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> {
  late final UnitController controller = Get.find<UnitController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadMyUnit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          appBar: AppDetailAppBar(
            title: 'My Unit',
          ),
          body: _buildBody(context),
        ));
  }

  Widget _buildBody(BuildContext context) {
    if (controller.isLoading.value && controller.unit.value == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage.value != null &&
        controller.unit.value == null) {
      return AppStateMessage(
        title: 'Unable to load unit',
        message: controller.errorMessage.value!,
        icon: Icons.home_work_outlined,
        actionLabel: 'Try again',
        onAction: () => controller.loadMyUnit(force: true),
      );
    }

    final data = controller.unit.value;
    if (data == null) {
      return AppStateMessage(
        title: 'No unit information',
        message: 'Your unit details are not available right now.',
        icon: Icons.home_work_outlined,
        actionLabel: 'Try again',
        onAction: () => controller.loadMyUnit(force: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.loadMyUnit(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          _UnitHero(unit: data),
          24.h.heightBox(),
          _SectionTitle(title: 'Unit information'),
          11.h.heightBox(),
          _UnitInformationCard(unit: data),
          24.h.heightBox(),
          _SectionTitle(title: 'People'),
          11.h.heightBox(),
          _PeopleCard(unit: data),
          24.h.heightBox(),
          _SectionTitle(title: 'Vehicles'),
          11.h.heightBox(),
          _VehiclesCard(vehicles: data.vehicles),
          24.h.heightBox(),
          if (data.unit.parkingSlot != null) ...[
            _SectionTitle(title: 'Parking'),
            11.h.heightBox(),
            _ParkingCard(slot: data.unit.parkingSlot!),
            24.h.heightBox(),
          ],
        ],
      ),
    );
  }
}

class _UnitHero extends StatelessWidget {
  const _UnitHero({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final u = unit.unit;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: tokens.heroShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            bottom: -45,
            child: Icon(
              Icons.apartment_rounded,
              size: 190,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'MY HOME',
                        style: TextStyle(
                          color: tokens.brandOnDark,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    _StatusBadge(
                      label: u.occupancy ?? '',
                      color: tokens.brandOnDark,
                    ),
                  ],
                ),
                20.h.heightBox(),
                Text(
                  u.label,
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                6.h.heightBox(),
                Text(
                  '${u.unitType?.name ?? ''} · ${u.areaM2 ?? ''} m² · ${u.floorLabel ?? ''}',
                  style: TextStyle(
                    color: tokens.brandOnDarkMuted,
                    fontSize: 13.sp,
                  ),
                ),
                18.h.heightBox(),
                Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: tokens.brandOnDark,
                      size: 17,
                    ),
                    6.w.widthBox(),
                    Text(
                      '${(unit.myRole ?? u.myRole ?? '').capitalizeFirst} · Parking ${u.parkingSlot ?? 'N/A'}',
                      style: TextStyle(
                        color: tokens.brandOnDarkMuted,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitInformationCard extends StatelessWidget {
  const _UnitInformationCard({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final u = unit.unit;
    return _UnitCard(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.35,
        children: [
          _tile('Unit number', u.number, Icons.tag_rounded),
          _tile('Tower', u.tower?.name ?? '', Icons.apartment_rounded),
          _tile('Floor', u.floorLabel ?? '', Icons.layers_outlined),
          _tile('Unit type', u.unitType?.name ?? '', Icons.bed_outlined),
          _tile('Area', '${u.areaM2 ?? ''}', Icons.square_foot_rounded),
          _tile('Bedrooms', '${u.bedrooms ?? ''}', Icons.king_bed_outlined),
          _tile('Bathrooms', '${u.bathrooms ?? ''}', Icons.bathtub_outlined),
          _tile('Occupancy', u.occupancy ?? '', Icons.check_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon) {
    return UnitInfoTile(label: label, value: value, icon: icon);
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final people = unit.people;
    return _UnitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Owner', style: TextStyle(fontSize: 12.sp, color: tokens.muted, fontWeight: FontWeight.w700)),
          2.h.heightBox(),
          if (people.owner != null)
            UnitPersonTile(person: people.owner!)
          else
            const Text('No owner'),
          const Divider(height: 24),
          Text('Residents', style: TextStyle(fontSize: 12.sp, color: tokens.muted, fontWeight: FontWeight.w700)),
          2.h.heightBox(),
          if (people.residents.isEmpty)
            const Text('No residents')
          else
            ...people.residents.map((r) => UnitPersonTile(person: r)),
          if (people.tenant != null) ...[
            const Divider(height: 24),
            Text('Tenant', style: TextStyle(fontSize: 12.sp, color: tokens.muted, fontWeight: FontWeight.w700)),
            UnitPersonTile(person: people.tenant!),
          ],
        ],
      ),
    );
  }
}

class _VehiclesCard extends StatelessWidget {
  const _VehiclesCard({required this.vehicles});

  final List<UnitVehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return _UnitCard(child: const Text('No vehicles registered.'));
    }
    return _UnitCard(
      child: Column(
        children: vehicles.map((v) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.directions_car_filled_outlined),
              12.w.widthBox(),
              Expanded(child: Text('${v.model} · ${v.plate}')),
              Text(v.slot ?? ''),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _ParkingCard extends StatelessWidget {
  const _ParkingCard({required this.slot});

  final String slot;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _UnitCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: const Icon(Icons.directions_car_filled_outlined, color: Color(0xFFB45309)),
          ),
          12.w.widthBox(),
          const Expanded(child: Text('Registered vehicle', style: TextStyle(fontWeight: FontWeight.w800))),
          Text(slot, style: TextStyle(color: tokens.brand, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.child});

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
        boxShadow: tokens.cardShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: tokens.ink),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.w800),
      ),
    );
  }
}
