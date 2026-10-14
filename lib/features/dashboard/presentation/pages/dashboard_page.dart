import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../../../core/widgets/app_state_message.dart';


import '../../../../core/widgets/branded_loading_view.dart';


import '../../../notifications/presentation/controllers/notification_controller.dart';


import '../../../session/domain/entities/resident_session.dart';


import '../../../session/presentation/controllers/session_controller.dart';


import '../../domain/entities/dashboard.dart';


import '../controllers/dashboard_controller.dart';


import '../widgets/section_header.dart';


import '../widgets/status_badge.dart';


import '../../../../core/theme/app_theme_tokens.dart';

class DashboardPage extends GetView<DashboardController> {
  DashboardPage({required this.onSelectTab, super.key});

  final ValueChanged<int> onSelectTab;

  /// Reads the shared notification controller so the badge always matches the
  /// unread count instead of a hardcoded number.
  int get _unreadNotifications {
    if (!Get.isRegistered<NotificationController>()) {
      return 0;
    }
    return Get.find<NotificationController>().unreadCount;
  }

  /// The signed-in resident, so the greeting names the account behind the
  /// tokens rather than a sample name.
  ///
  /// Read from [SessionController] for the same reason the unread count is read
  /// from [NotificationController]: it is the one place the app already keeps
  /// the authenticated resident, and [AuthController.adoptIntoSession] writes
  /// it from `/auth/me` during login and Restore Session â€” before this page is
  /// ever mounted. No extra request is made.
  ///
  /// Null when no session controller is registered. That cannot happen on the
  /// real route (`/home` registers `SessionBinding` through `AppBinding`), but
  /// returning null rather than a placeholder keeps the greeting from showing
  /// a name that belongs to nobody.
  ResidentSession? get _residentSession {
    if (!Get.isRegistered<SessionController>()) {
      return null;
    }
    return Get.find<SessionController>().session.value;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.dashboard.value == null) {
        return BrandedLoadingView();
      }
      if (controller.errorMessage.value != null &&
          controller.dashboard.value == null) {
        return SafeArea(
          child: AppStateMessage(
            title: 'Unable to load dashboard',
            message: controller.errorMessage.value!,
            icon: Icons.cloud_off_rounded,
            actionLabel: 'Try again',
            onAction: controller.loadDashboard,
          ),
        );
      }

      final data = controller.dashboard.value!;
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _GreetingHeader(
                resident: _residentSession,
                unreadCount: _unreadNotifications,
                onNotifications: () => Get.toNamed(AppRoutes.notifications),
                onMore: () => Get.toNamed(AppRoutes.more),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.loadDashboard,
                child: ListView(
                  key: Key('dashboard-scroll'),
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _HomeCard(
                      unit: data.unit,
                      onViewDetails: () => Get.toNamed(AppRoutes.unit),
                    ),
                    22.h.heightBox(),
                    _BalanceCard(
                      balance: data.balance,
                      onPayNow: () => onSelectTab(1),
                    ),
                    26.h.heightBox(),
                    SectionHeader(title: 'Quick actions'),
                    12.h.heightBox(),
                    _QuickActions(onSelectTab: onSelectTab),
                    10.h.heightBox(),
                    OutlinedButton.icon(
                      key: Key('dashboard-all-services'),
                      onPressed: () => Get.toNamed(AppRoutes.more),
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                      label: Text('All resident services'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(46),
                      ),
                    ),
                    26.h.heightBox(),
                    SectionHeader(
                      title: 'Maintenance',
                      actionLabel: 'View all',
                      onAction: () => onSelectTab(2),
                    ),
                    10.h.heightBox(),
                    _MaintenanceCard(
                      requests: data.maintenance,
                      inProgress: data.inProgressMaintenance,
                      completed: data.completedMaintenance,
                    ),
                    26.h.heightBox(),
                    SectionHeader(
                      title: 'Reservations',
                      actionLabel: 'Book',
                      onAction: () => onSelectTab(3),
                    ),
                    10.h.heightBox(),
                    _ReservationsCard(reservations: data.reservations),
                    26.h.heightBox(),
                    SectionHeader(
                      title: 'Latest announcements',
                      actionLabel: 'View all',
                      onAction: () => Get.toNamed(AppRoutes.announcements),
                    ),
                    10.h.heightBox(),
                    ...data.announcements.map(
                      (announcement) => Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: _AnnouncementCard(announcement: announcement),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _GreetingHeader extends StatelessWidget {
  _GreetingHeader({
    required this.resident,
    required this.unreadCount,
    required this.onNotifications,
    required this.onMore,
  });

  final ResidentSession? resident;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onMore;

  /// The given name, or a neutral word rather than a blank greeting.
  ///
  /// [ResidentSession.name] is never blank in practice â€” the controller seeds
  /// it with a placeholder and [AuthController.adoptIntoSession] refuses to
  /// overwrite it with an empty string â€” but a blank greeting reads as a bug,
  /// so one is never painted. Splitting on whitespace rather than a single
  /// space also keeps a doubled space from yielding an empty first name.
  static String _firstName(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Resident';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

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
                'Good morning, ${_firstName(resident?.name)}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: tokens.ink),
              ),
              4.h.heightBox(),
              Text(
                "Here's what's happening with your condo today.",
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
        12.w.widthBox(),
        IconButton(
          key: Key('dashboard-all-services-icon'),
          onPressed: onMore,
          tooltip: 'All resident services',
          icon: Icon(Icons.grid_view_rounded, color: tokens.brand),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              key: Key('dashboard-notifications'),
              onTap: onNotifications,
              borderRadius: BorderRadius.circular(24.r),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: tokens.brandOnDark,
                child: Text(
                  resident?.initials ?? '?',
                  style: TextStyle(
                    color: tokens.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: TextStyle(
                        color: tokens.onBrand,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  _HomeCard({required this.unit, required this.onViewDetails});

  final UnitSummary unit;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return InkWell(
      onTap: onViewDetails,
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.brand,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: tokens.heroShadow,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Icon(
                Icons.apartment_rounded,
                size: 180,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'YOUR HOME',
                          style: TextStyle(
                            color: tokens.brandOnDark,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      StatusBadge(label: unit.occupancy),
                    ],
                  ),
                  18.h.heightBox(),
                  Text(
                    '${unit.tower} Â· Unit ${unit.unit}',
                    style: TextStyle(
                      color: tokens.brandOnDark,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  6.h.heightBox(),
                  Text(
                    '${unit.type} Â· ${unit.area} Â· ${unit.floor}',
                    style: TextStyle(
                      color: tokens.brandOnDarkMuted,
                      fontSize: 13.sp,
                    ),
                  ),
                  20.h.heightBox(),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: tokens.brandOnDark,
                        size: 17,
                      ),
                      6.w.widthBox(),
                      Flexible(
                        child: Text(
                          '${unit.ownership} Â· Parking ${unit.parkingSlot}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.brandOnDarkMuted,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ],
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

class _BalanceCard extends StatelessWidget {
  _BalanceCard({required this.balance, required this.onPayNow});

  final BalanceSummary balance;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Outstanding balance',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(label: 'Due ${balance.dueDate}'),
            ],
          ),
          8.h.heightBox(),
          Text(
            '\$${balance.outstanding.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w800),
          ),
          Text(
            'Across all open invoices',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.muted),
          ),
          16.h.heightBox(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last payment',
                      style: TextStyle(fontSize: 12.sp, color: tokens.muted),
                    ),
                    3.h.heightBox(),
                    Text(
                      '\$${balance.lastPayment.toStringAsFixed(2)} Â· ${balance.lastPaymentDate}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onPayNow,
                icon: Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('Pay now'),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.brand,
                  foregroundColor: tokens.onBrand,
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  _QuickActions({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  /// Six shortcuts, the ones used most often. Every other module is one tap
  /// away through "All resident services" below the grid.
  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.payments_outlined,
                label: 'Pay fees',
                color: tokens.brandTint,
                onTap: () => onSelectTab(1),
              ),
            ),
            10.w.widthBox(),
            Expanded(
              child: _QuickAction(
                icon: Icons.handyman_outlined,
                label: 'Maintenance',
                color: tokens.brandTint,
                onTap: () => onSelectTab(2),
              ),
            ),
          ],
        ),
        10.h.heightBox(),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Register visitor',
                color: Color(0xFFFFF1D6),
                onTap: () => Get.toNamed(AppRoutes.visitors),
              ),
            ),
            10.w.widthBox(),
            Expanded(
              child: _QuickAction(
                icon: Icons.event_available_outlined,
                label: 'Reserve',
                color: Color(0xFFEAE8FA),
                onTap: () => onSelectTab(3),
              ),
            ),
          ],
        ),
        10.h.heightBox(),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.storefront_outlined,
                label: 'Convenience Store',
                color: tokens.brandTint,
                onTap: () => Get.toNamed(AppRoutes.store),
              ),
            ),
            10.w.widthBox(),
            Expanded(
              child: _QuickAction(
                icon: Icons.room_service_outlined,
                label: 'Services',
                color: Color(0xFFEAE8FA),
                onTap: () => Get.toNamed(AppRoutes.services),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(icon, color: tokens.ink, size: 20),
            ),
            9.w.widthBox(),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  _MaintenanceCard({
    required this.requests,
    required this.inProgress,
    required this.completed,
  });

  final List<MaintenanceRequestSummary> requests;
  final int inProgress;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          ...requests.map(
            (request) => Padding(
              padding: EdgeInsets.fromLTRB(16, 15, 16, 15),
              child: Row(
                children: [
                  Icon(Icons.build_circle_outlined, color: tokens.brand),
                  12.w.widthBox(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        3.h.heightBox(),
                        Text(
                          '${request.category} Â· ${request.priority}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: tokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: request.status),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(19.r),
              ),
            ),
            child: Text(
              '$inProgress in progress  Â·  $completed completed',
              style: TextStyle(
                fontSize: 12.sp,
                color: tokens.mutedStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationsCard extends StatelessWidget {
  _ReservationsCard({required this.reservations});

  final List<ReservationSummary> reservations;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: reservations
            .map(
              (reservation) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFFEAE8FA),
                  child: Icon(
                    Icons.event_rounded,
                    size: 19,
                    color: Color(0xFF5B4CC4),
                  ),
                ),
                title: Text(
                  reservation.facility,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${reservation.date} Â· ${reservation.time}'),
                trailing: StatusBadge(label: reservation.status),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  _AnnouncementCard({required this.announcement});

  final AnnouncementSummary announcement;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.brandTint,
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(
              announcement.isUrgent
                  ? Icons.warning_amber_rounded
                  : Icons.campaign_outlined,
              color: announcement.isUrgent ? Color(0xFFC2410C) : tokens.brand,
              size: 20,
            ),
          ),
          12.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      announcement.date,
                      style: TextStyle(fontSize: 10.sp, color: tokens.muted),
                    ),
                  ],
                ),
                5.h.heightBox(),
                Text(
                  announcement.description,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.35,
                    color: tokens.muted,
                  ),
                ),
                8.h.heightBox(),
                StatusBadge(label: announcement.category),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
