import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/unit.dart';
import '../controllers/unit_controller.dart';
import '../widgets/unit_info_tile.dart';
import '../widgets/unit_person_tile.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

class UnitPage extends GetView<UnitController> {
  const UnitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppDetailAppBar(
          title: 'My Unit',
          actions: [
            IconButton(
              onPressed: controller.loadMyUnit,
              tooltip: 'Refresh unit information',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _buildBody(context),
      ),
    );
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
        onAction: controller.loadMyUnit,
      );
    }

    final unit = controller.unit.value;
    if (unit == null) {
      return const AppStateMessage(
        title: 'No unit information',
        message: 'Your unit details are not available right now.',
        icon: Icons.home_work_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadMyUnit,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.pageTop, AppSpacing.gutter, 32),
        children: [
          _UnitHero(unit: unit),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Unit information'),
          const SizedBox(height: 11),
          _UnitInformationCard(unit: unit),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'People'),
          const SizedBox(height: 11),
          _PeopleCard(unit: unit),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Parking'),
          const SizedBox(height: 11),
          _ParkingCard(parking: unit.parking),
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(24),
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
            padding: const EdgeInsets.all(20),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    _StatusBadge(
                      label: unit.occupancyStatus,
                      color: tokens.brandOnDark,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${unit.tower} · Unit ${unit.unitNumber}',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${unit.unitType} · ${unit.area} · ${unit.floor}',
                  style: TextStyle(
                    color: tokens.brandOnDarkMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: tokens.brandOnDark,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${unit.ownershipStatus} · Parking ${unit.parking.slot}',
                      style: TextStyle(
                        color: tokens.brandOnDarkMuted,
                        fontSize: 12,
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
    return _UnitCard(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.35,
        children: [
          UnitInfoTile(
            label: 'Unit number',
            value: unit.unitNumber,
            icon: Icons.tag_rounded,
          ),
          UnitInfoTile(
            label: 'Tower',
            value: unit.tower,
            icon: Icons.apartment_rounded,
          ),
          UnitInfoTile(
            label: 'Floor',
            value: unit.floor,
            icon: Icons.layers_outlined,
          ),
          UnitInfoTile(
            label: 'Unit type',
            value: unit.unitType,
            icon: Icons.bed_outlined,
          ),
          UnitInfoTile(
            label: 'Area',
            value: unit.area,
            icon: Icons.square_foot_rounded,
          ),
          UnitInfoTile(
            label: 'Bedrooms',
            value: '${unit.bedrooms}',
            icon: Icons.king_bed_outlined,
          ),
          UnitInfoTile(
            label: 'Bathrooms',
            value: '${unit.bathrooms}',
            icon: Icons.bathtub_outlined,
          ),
          UnitInfoTile(
            label: 'Occupancy',
            value: unit.occupancyStatus,
            icon: Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _UnitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Owner',
            style: TextStyle(
              fontSize: 12,
              color: tokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          UnitPersonTile(person: unit.owner),
          const Divider(height: 24),
          Text(
            'Residents',
            style: TextStyle(
              fontSize: 12,
              color: tokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          ...unit.residents.map((resident) => UnitPersonTile(person: resident)),
          if (unit.tenant != null) ...[
            const Divider(height: 24),
            Text(
              'Tenant',
              style: TextStyle(
                fontSize: 12,
                color: tokens.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            UnitPersonTile(person: unit.tenant!),
          ],
        ],
      ),
    );
  }
}

class _ParkingCard extends StatelessWidget {
  const _ParkingCard({required this.parking});

  final ParkingInfo parking;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return _UnitCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1D6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_filled_outlined,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registered vehicle',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                parking.slot,
                style: TextStyle(
                  color: tokens.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _ParkingValue(label: 'Vehicle', value: parking.vehicle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ParkingValue(
                  label: 'License plate',
                  value: parking.licensePlate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParkingValue extends StatelessWidget {
  const _ParkingValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.muted),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: tokens.ink,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
