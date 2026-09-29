import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/models/resident_role.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../complaints/presentation/controllers/complaint_controller.dart';
import '../../../lease/domain/entities/lease.dart';
import '../../../lease/presentation/controllers/lease_controller.dart';
import '../../../parking/presentation/controllers/parking_controller.dart';
import '../../../rules/presentation/controllers/rules_controller.dart';
import '../../../services/presentation/controllers/condo_service_controller.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../../visitors/presentation/controllers/visitor_controller.dart';

/// Hub for every resident module that is not part of the bottom navigation.
class MoreServicesPage extends StatelessWidget {
  const MoreServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    return Scaffold(
      appBar: AppBar(title: const Text('More services')),
      body: SafeArea(
        child: Obx(
          () => ListView(
            key: const Key('more-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
            AppHeroPanel(
              icon: Icons.grid_view_rounded,
              title: 'Resident services',
              subtitle: 'Everything for ${session.session.value.unitLabel}',
              footnote:
                  'You are signed in as ${session.session.value.role.label}. '
                  'Some screens change with your role.',
            ),
            const SizedBox(height: 20),
            const AppSectionHeader(title: 'Home & living'),
            const SizedBox(height: 10),
            _ModuleTile(
              route: AppRoutes.lease,
              icon: Icons.description_rounded,
              color: AppPalette.info,
              title: 'Rental & lease',
              subtitle: 'Term progress, expiry and renewal',
              badge: _leaseSubtitle(),
            ),
            _ModuleTile(
              route: AppRoutes.visitors,
              icon: Icons.people_alt_rounded,
              color: AppPalette.brand,
              title: 'Visitors',
              subtitle: 'Access codes, check-in and check-out',
              badge: _visitorBadge(),
            ),
            _ModuleTile(
              route: AppRoutes.parking,
              icon: Icons.directions_car_rounded,
              color: AppPalette.warning,
              title: 'Parking',
              subtitle: 'Your bay, access log and guest parking',
              badge: _parkingBadge(),
            ),
            const SizedBox(height: 18),
            const AppSectionHeader(title: 'Building services'),
            const SizedBox(height: 10),
            _ModuleTile(
              route: AppRoutes.services,
              icon: Icons.room_service_rounded,
              color: AppPalette.brand,
              title: 'Condo services',
              subtitle: 'Cleaning, laundry, pest control and more',
              badge: _serviceBadge(),
            ),
            _ModuleTile(
              route: AppRoutes.complaints,
              icon: Icons.support_agent_rounded,
              color: AppPalette.accent,
              title: 'Complaints',
              subtitle: 'Report an issue to the community team',
              badge: _complaintBadge(),
            ),
            _ModuleTile(
              route: AppRoutes.rules,
              icon: Icons.gavel_rounded,
              color: AppPalette.danger,
              title: 'Rules & violations',
              subtitle: 'Community rules, fines and appeals',
              badge: _violationBadge(),
            ),
            const SizedBox(height: 18),
            const AppSectionHeader(title: 'Account'),
            const SizedBox(height: 10),
            _ModuleTile(
              route: AppRoutes.unit,
              icon: Icons.home_work_rounded,
              color: AppPalette.mutedStrong,
              title: 'My unit',
              subtitle: 'Owner, tenant, residents and parking details',
            ),
            _ModuleTile(
              route: AppRoutes.announcements,
              icon: Icons.campaign_rounded,
              color: AppPalette.brand,
              title: 'Announcements',
              subtitle: 'Notices from the management team',
            ),
            _ModuleTile(
              route: AppRoutes.notifications,
              icon: Icons.notifications_none_rounded,
              color: AppPalette.info,
              title: 'Notifications',
              subtitle: 'All your resident updates',
            ),
            const SizedBox(height: 18),
            AppCard(
              color: AppPalette.surface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppPalette.muted),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'All data in this build is mocked locally. Every module '
                      'follows the same repository structure that the Odoo API '
                      'will plug into.',
                      style: TextStyle(
                        color: AppPalette.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  String? _leaseSubtitle() {
    if (!Get.isRegistered<LeaseController>()) return null;
    final controller = Get.find<LeaseController>();
    final lease = controller.activeLease;
    if (lease == null) return null;
    return lease.isExpiringSoon
        ? 'Expires in ${lease.daysRemaining} days'
        : lease.status.label;
  }

  String? _visitorBadge() {
    if (!Get.isRegistered<VisitorController>()) return null;
    final controller = Get.find<VisitorController>();
    return '${controller.activeCount} active';
  }

  String? _parkingBadge() {
    if (!Get.isRegistered<ParkingController>()) return null;
    final controller = Get.find<ParkingController>();
    final space = controller.mySpace.value;
    return space == null ? null : 'Slot ${space.slot}';
  }

  String? _serviceBadge() {
    if (!Get.isRegistered<CondoServiceController>()) return null;
    return '${Get.find<CondoServiceController>().openRequestCount} open';
  }

  String? _complaintBadge() {
    if (!Get.isRegistered<ComplaintController>()) return null;
    return '${Get.find<ComplaintController>().openCount} open';
  }

  String? _violationBadge() {
    if (!Get.isRegistered<RulesController>()) return null;
    return '${Get.find<RulesController>().openViolationCount} open';
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.route,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final String route;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Get.toNamed(route),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            AppIconTile(icon: icon, color: color, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              AppStatusPill(label: badge!, color: color, dense: true)
            else
              const Icon(Icons.chevron_right_rounded, color: AppPalette.faint),
          ],
        ),
      ),
    );
  }
}
