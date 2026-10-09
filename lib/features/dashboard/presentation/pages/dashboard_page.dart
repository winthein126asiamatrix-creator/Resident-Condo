import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/branded_loading_view.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';
import '../../domain/entities/dashboard.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';
import '../../../../core/theme/app_theme_tokens.dart';

class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({required this.onSelectTab, super.key});

  final ValueChanged<int> onSelectTab;

  /// Reads the shared notification controller so the badge always matches the
  /// unread count instead of a hardcoded number.
  int get _unreadNotifications {
    if (!Get.isRegistered<NotificationController>()) {
      return 0;
    }
    return Get.find<NotificationController>().unreadCount;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.dashboard.value == null) {
        return const BrandedLoadingView();
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _GreetingHeader(
                resident: data.resident,
                unreadCount: _unreadNotifications,
                onNotifications: () => Get.toNamed(AppRoutes.notifications),
                onMore: () => Get.toNamed(AppRoutes.more),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.loadDashboard,
                child: ListView(
                  key: const Key('dashboard-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _HomeCard(
                      unit: data.unit,
                      onViewDetails: () => Get.toNamed(AppRoutes.unit),
                    ),
                    const SizedBox(height: 22),
                    _BalanceCard(
                      balance: data.balance,
                      onPayNow: () => onSelectTab(1),
                    ),
                    const SizedBox(height: 26),
                    const SectionHeader(title: 'Quick actions'),
                    const SizedBox(height: 12),
                    _QuickActions(onSelectTab: onSelectTab),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('dashboard-all-services'),
                      onPressed: () => Get.toNamed(AppRoutes.more),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text('All resident services'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SectionHeader(
                      title: 'Maintenance',
                      actionLabel: 'View all',
                      onAction: () => onSelectTab(2),
                    ),
                    const SizedBox(height: 10),
                    _MaintenanceCard(
                      requests: data.maintenance,
                      inProgress: data.inProgressMaintenance,
                      completed: data.completedMaintenance,
                    ),
                    const SizedBox(height: 26),
                    SectionHeader(
                      title: 'Reservations',
                      actionLabel: 'Book',
                      onAction: () => onSelectTab(3),
                    ),
                    const SizedBox(height: 10),
                    _ReservationsCard(reservations: data.reservations),
                    const SizedBox(height: 26),
                    SectionHeader(
                      title: 'Latest announcements',
                      actionLabel: 'View all',
                      onAction: () => Get.toNamed(AppRoutes.announcements),
                    ),
                    const SizedBox(height: 10),
                    ...data.announcements.map(
                      (announcement) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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
  const _GreetingHeader({
    required this.resident,
    required this.unreadCount,
    required this.onNotifications,
    required this.onMore,
  });

  final Resident resident;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onMore;

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
                'Good morning, ${resident.name.split(' ').first}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's what's happening with your condo today.",
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          key: const Key('dashboard-all-services-icon'),
          onPressed: onMore,
          tooltip: 'All resident services',
          icon: Icon(Icons.grid_view_rounded, color: tokens.brand),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              key: const Key('dashboard-notifications'),
              onTap: onNotifications,
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: tokens.brandOnDark,
                child: Text(
                  resident.initials,
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
                        fontSize: 9,
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
  const _HomeCard({required this.unit, required this.onViewDetails});

  final UnitSummary unit;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return InkWell(
      onTap: onViewDetails,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.brand,
          borderRadius: BorderRadius.circular(24),
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        StatusBadge(label: unit.occupancy),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${unit.tower} · Unit ${unit.unit}',
                      style: TextStyle(
                        color: tokens.brandOnDark,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${unit.type} · ${unit.area} · ${unit.floor}',
                      style: TextStyle(
                        color: tokens.brandOnDarkMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: tokens.brandOnDark,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${unit.ownership} · Parking ${unit.parkingSlot}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.brandOnDarkMuted,
                              fontSize: 12,
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
  const _BalanceCard({required this.balance, required this.onPayNow});

  final BalanceSummary balance;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Outstanding balance',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(label: 'Due ${balance.dueDate}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${balance.outstanding.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Across all open invoices',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last payment',
                      style: TextStyle(fontSize: 12, color: tokens.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '\$${balance.lastPayment.toStringAsFixed(2)} · ${balance.lastPaymentDate}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onPayNow,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Pay now'),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.brand,
                  foregroundColor: tokens.onBrand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
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
  const _QuickActions({required this.onSelectTab});

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
            const SizedBox(width: 10),
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Register visitor',
                color: const Color(0xFFFFF1D6),
                onTap: () => Get.toNamed(AppRoutes.visitors),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.event_available_outlined,
                label: 'Reserve',
                color: const Color(0xFFEAE8FA),
                onTap: () => onSelectTab(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.room_service_outlined,
                label: 'Services',
                color: const Color(0xFFEAE8FA),
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
  const _QuickAction({
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: tokens.ink, size: 20),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          ...requests.map(
            (request) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              child: Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    color: tokens.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${request.category} · ${request.priority}',
                          style: TextStyle(
                            fontSize: 12,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
            ),
            child: Text(
              '$inProgress in progress  ·  $completed completed',
              style: TextStyle(
                fontSize: 12,
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
  const _ReservationsCard({required this.reservations});

  final List<ReservationSummary> reservations;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: reservations
            .map(
              (reservation) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFEAE8FA),
                  child: Icon(
                    Icons.event_rounded,
                    size: 19,
                    color: const Color(0xFF5B4CC4),
                  ),
                ),
                title: Text(
                  reservation.facility,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${reservation.date} · ${reservation.time}'),
                trailing: StatusBadge(label: reservation.status),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final AnnouncementSummary announcement;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              announcement.isUrgent
                  ? Icons.warning_amber_rounded
                  : Icons.campaign_outlined,
              color: announcement.isUrgent
                  ? const Color(0xFFC2410C)
                  : tokens.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      announcement.date,
                      style: TextStyle(
                        fontSize: 10,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  announcement.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 8),
                StatusBadge(label: announcement.category),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
