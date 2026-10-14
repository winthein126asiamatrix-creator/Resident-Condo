import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../../../core/models/resident_role.dart';


import '../../../../core/theme/app_palette.dart';


import '../../../../core/theme/app_theme_tokens.dart';


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


import '../../../../core/widgets/app_detail_app_bar.dart';

/// Hub for every resident module that is not part of the bottom navigation.
class MoreServicesPage extends StatelessWidget {
  MoreServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'More services'),
      body: SafeArea(
        child: Obx(
          () => ListView(
            key: Key('more-scroll'),
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AppHeroPanel(
                icon: Icons.grid_view_rounded,
                title: 'Resident services',
                subtitle:
                    'Everything for ${session.session.value?.unitLabel ?? ''}',
                footnote:
                    'You are signed in as ${session.session.value?.role.label ?? 'Resident'}. '
                    'Some screens change with your role.',
              ),
              20.h.heightBox(),
              AppSectionHeader(title: 'Home & living'),
              10.h.heightBox(),
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
                color: tokens.brand,
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
              18.h.heightBox(),
              AppSectionHeader(title: 'Building services'),
              10.h.heightBox(),
              _ModuleTile(
                route: AppRoutes.store,
                icon: Icons.storefront_rounded,
                color: tokens.brand,
                title: 'Convenience Store',
                subtitle: 'Groceries, snacks and drinks to your door',
              ),
              _ModuleTile(
                route: AppRoutes.services,
                icon: Icons.room_service_rounded,
                color: tokens.brand,
                title: 'Condo services',
                subtitle: 'Cleaning, laundry, pest control and more',
                badge: _serviceBadge(),
              ),
              _ModuleTile(
                route: AppRoutes.complaints,
                icon: Icons.support_agent_rounded,
                color: tokens.brand,
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
              18.h.heightBox(),
              AppSectionHeader(title: 'Account'),
              10.h.heightBox(),
              _ModuleTile(
                route: AppRoutes.unit,
                icon: Icons.home_work_rounded,
                color: tokens.mutedStrong,
                title: 'My unit',
                subtitle: 'Owner, tenant, residents and parking details',
              ),
              _ModuleTile(
                route: AppRoutes.announcements,
                icon: Icons.campaign_rounded,
                color: tokens.brand,
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
              18.h.heightBox(),
              AppCard(
                color: tokens.surface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_off_rounded, color: tokens.muted),
                    10.w.widthBox(),
                    Expanded(
                      child: Text(
                        'All data in this build is mocked locally. Every module '
                        'follows the same repository structure that the Odoo API '
                        'will plug into.',
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 11.sp,
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
  _ModuleTile({
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
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Get.toNamed(route),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            AppIconTile(icon: icon, color: color, size: 42),
            12.w.widthBox(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
                  3.h.heightBox(),
                  Text(
                    subtitle,
                    style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
            if (badge != null)
              AppStatusPill(label: badge!, color: color, dense: true)
            else
              Icon(Icons.chevron_right_rounded, color: tokens.faint),
          ],
        ),
      ),
    );
  }
}
