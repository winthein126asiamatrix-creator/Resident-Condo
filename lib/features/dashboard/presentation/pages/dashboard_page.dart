import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:test/features/auth/data/models/auth_user.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/network/api_log_store.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/super_print.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';

import '../../../../core/widgets/authenticated_avatar.dart';

import '../../../../core/widgets/branded_loading_view.dart';

import '../../../config/domain/entities/condo_config.dart';
import '../../../config/presentation/controllers/condo_config_controller.dart';
import '../../../maintenance/presentation/controllers/maintenance_controller.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';

import '../../../payments/domain/entities/payment_dashboard.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';

import '../../../session/domain/entities/resident_session.dart';

import '../../../session/presentation/controllers/session_controller.dart';
import '../../../unit/domain/entities/unit.dart';
import '../../../unit/presentation/controllers/unit_controller.dart';

import '../../domain/entities/dashboard.dart';

import '../controllers/dashboard_controller.dart';

import '../widgets/dashboard_maintenance_section.dart';
import '../widgets/section_header.dart';

import '../widgets/status_badge.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

List<CondoFeature> selectDashboardQuickActionFeatures(CondoConfig? config) {
  if (config == null) return const <CondoFeature>[];
  return CondoFeature.values
      .where((feature) => feature != CondoFeature.dashboard)
      .where(config.isFeatureEnabled)
      .take(6)
      .toList(growable: false);
}

class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({required this.onSelectFeature, super.key});

  final ValueChanged<String> onSelectFeature;

  CondoConfigController? get _configController =>
      Get.isRegistered<CondoConfigController>()
      ? Get.find<CondoConfigController>()
      : null;

  bool _enabled(CondoFeature feature) {
    final config = _configController;
    return config == null || config.isFeatureEnabled(feature);
  }

  /// Reads the shared notification controller so the badge always matches the
  /// unread count instead of a hardcoded number.
  int get _unreadNotifications {
    if (!Get.isRegistered<NotificationController>()) {
      return 0;
    }
    return Get.find<NotificationController>().unreadCount;
  }

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
      // The balance card reads the payment feature's shared controller instead
      // of issuing its own request. The controller is registered app-wide and
      // already owns the API data, its cache and its offline fallback.
      final paymentController = Get.isRegistered<PaymentController>()
          ? Get.find<PaymentController>()
          : null;
      final maintenanceController = Get.isRegistered<MaintenanceController>()
          ? Get.find<MaintenanceController>()
          : null;
      final quickActionFeatures = selectDashboardQuickActionFeatures(
        _configController?.config.value,
      );
      final hasQuickActions = quickActionFeatures.isNotEmpty;
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _GreetingHeader(
                resident: _residentSession,
                onNotifications: () => Get.toNamed(AppRoutes.notifications),
                onMore: () => Get.toNamed(AppRoutes.more),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait<void>([
                    controller.loadDashboard(),
                    if (paymentController != null)
                      paymentController.loadPayments(),
                    if (maintenanceController != null)
                      maintenanceController.refreshRequests(),
                  ]);
                },
                child: ListView(
                  key: Key('dashboard-scroll'),
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _HomeCard(
                      unitController: Get.isRegistered<UnitController>()
                          ? Get.find<UnitController>()
                          : null,
                      onViewDetails: () => Get.toNamed(AppRoutes.unit),
                    ),
                    if (_enabled(CondoFeature.payments)) ...[
                      22.h.heightBox(),
                      _BalanceCard(
                        paymentController: paymentController,
                        onPayNow: () {
                          vibrateNow();
                          onSelectFeature(CondoFeature.payments.wire);
                        },
                      ),
                    ],
                    if (hasQuickActions) ...[
                      26.h.heightBox(),
                      SectionHeader(title: 'Quick actions'),
                      12.h.heightBox(),
                      _QuickActions(
                        onSelectFeature: onSelectFeature,
                        enabledFeatures: quickActionFeatures,
                      ),
                    ],
                    10.h.heightBox(),
                    OutlinedButton.icon(
                      key: Key('dashboard-all-services'),
                      onPressed: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.more);
                      },
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                      label: Text('All resident services'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(46),
                      ),
                    ),
                    if (_enabled(CondoFeature.maintenance)) ...[
                      26.h.heightBox(),
                      DashboardMaintenanceSection(
                        onViewAll: () {
                          vibrateNow();
                          onSelectFeature(CondoFeature.maintenance.wire);
                        },
                      ),
                    ],
                    if (_enabled(CondoFeature.facilities)) ...[
                      26.h.heightBox(),
                      SectionHeader(
                        title: 'Reservations',
                        actionLabel: 'Book',
                        onAction: () {
                          vibrateNow();
                          onSelectFeature(CondoFeature.facilities.wire);
                        },
                      ),
                      10.h.heightBox(),
                      _ReservationsCard(reservations: data.reservations),
                    ],
                    26.h.heightBox(),
                    SectionHeader(
                      title: 'Latest announcements',
                      actionLabel: 'View all',
                      onAction: () {
                        vibrateNow();
                        Get.toNamed(AppRoutes.announcements);
                      },
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
  const _GreetingHeader({
    required this.resident,
    required this.onNotifications,
    required this.onMore,
  });

  final ResidentSession? resident;
  final VoidCallback onNotifications;
  final VoidCallback onMore;

  static String _firstName(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Resident';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static void _showApiLogger() {
    if (!Get.isRegistered<ApiLogStore>()) {
      return;
    }
    Get.find<ApiLogStore>().showOverlay();
  }

  static Future<void> _copyDeviceToken(BuildContext context) async {
    if (!Get.isRegistered<FirebaseService>()) {
      showAppFeedback(
        context,
        title: 'No token yet',
        message: 'Firebase is not available on this build.',
        isError: true,
      );
      return;
    }
    final firebase = Get.find<FirebaseService>();
    final token = firebase.deviceToken.value;
    if (token == null || token.isEmpty) {
      showAppFeedback(
        context,
        title: 'No token yet',
        message: firebase.permissionStatus.value?.name == 'denied'
            ? 'Allow notifications for this app to get a token.'
            : 'Firebase has not issued one yet.',
        isError: false,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    if (!context.mounted) {
      return;
    }
    superPrint('FCM token copied to the clipboard.', title: 'Firebase Service');
    showAppFeedback(
      context,
      title: 'Token copied',
      message: 'Paste it into the Firebase console to send a test message.',
      isError: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final imageUrl = resident?.image?.trim() ?? '';
    final avatarFallback = Text(
      resident?.initials ?? '?',
      style: TextStyle(color: tokens.brand, fontWeight: FontWeight.w800),
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _copyDeviceToken(context),
                onDoubleTap: _showApiLogger,
                child: Text(
                  'Good morning, ${_firstName(resident?.name)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
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
                child: AuthenticatedAvatar(
                  url: imageUrl,
                  fallback: avatarFallback,
                ),
              ),
            ),
            if ((resident?.user.unreadNotificationCount ?? 0) > 0)
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
                      resident!.user.unreadNotificationCount > 9
                          ? '9+'
                          : '$resident!.user.unreadNotificationCount',
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
  const _HomeCard({required this.unitController, required this.onViewDetails});

  final UnitController? unitController;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final controller = unitController;
    if (controller == null) {
      return _buildCard(context, null, false);
    }
    return Obx(
      () => _buildCard(
        context,
        controller.unit.value,
        controller.isLoading.value && controller.unit.value == null,
      ),
    );
  }

  Widget _buildCard(BuildContext context, Unit? unitData, bool isLoading) {
    final tokens = AppThemeTokens.of(context);
    final unitInfo = unitData?.unit;
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
                      // StatusBadge(label: unit.occupancy),
                    ],
                  ),
                  18.h.heightBox(),
                  Text(
                    isLoading
                        ? 'Loading unit...'
                        : (unitInfo?.label ?? unitData?.unit.label ?? ''),
                    style: TextStyle(
                      color: tokens.brandOnDark,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  6.h.heightBox(),
                  Text(
                    isLoading
                        ? ''
                        : '${unitInfo?.unitType?.name ?? ''} · ${unitInfo?.areaM2 ?? ''} m² · ${unitInfo?.floorLabel ?? ''}',
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
                        child:
                            // Text(
                            //   '${unitInfo?.parkingSlot ?? 'N/A'}',
                            //   maxLines: 1,
                            //   overflow: TextOverflow.ellipsis,
                            //   style: TextStyle(
                            //     color: tokens.brandOnDarkMuted,
                            //     fontSize: 12.sp,
                            //   ),
                            // ),
                            Text(
                              '${(unitInfo?.myRole ?? '').capitalizeFirst} · Parking ${unitInfo?.parkingSlot ?? 'N/A'}',
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
  const _BalanceCard({required this.paymentController, required this.onPayNow});

  final PaymentController? paymentController;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    final controller = paymentController;
    if (controller == null) {
      return _buildCard(context, null, false, 'Balance unavailable');
    }
    return Obx(
      () => _buildCard(
        context,
        controller.dashboard.value,
        controller.isLoading.value,
        controller.errorMessage.value,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    PaymentDashboard? dashboard,
    bool isLoading,
    String? errorMessage,
  ) {
    final tokens = AppThemeTokens.of(context);
    final hasData = dashboard != null;
    final failed = !hasData && !isLoading && errorMessage != null;
    final currency = dashboard?.outstandingBalance.currency ?? '';
    final due = _dueInfo(dashboard);
    final lastPaymentDate = paymentController?.lastDashboardPaymentDate ?? '';

    final balanceText = hasData
        ? _money(dashboard.outstandingBalance.amount, currency)
        : failed
        ? '—'
        : 'Loading...';
    final balanceDetail = hasData
        ? 'Across all open invoices'
        : failed
        ? errorMessage
        : 'Fetching your balance...';
    final lastPaymentText = hasData
        ? _lastPaymentText(
            dashboard.paymentStatistics.lastPayment,
            lastPaymentDate,
            currency,
          )
        : failed
        ? '—'
        : 'Loading...';

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
              if (due.date.isNotEmpty)
                _DueDateChip(date: due.date, overdue: due.overdue),
            ],
          ),
          8.h.heightBox(),
          Text(
            balanceText,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w800),
          ),
          Text(
            balanceDetail,
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
                      lastPaymentText,
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

  String _money(double value, String currency) => currency.trim().isEmpty
      ? AppFormatters.currency(value)
      : AppFormatters.money(value, currency);

  String _lastPaymentText(double amount, String paidAt, String currency) {
    final money = _money(amount, currency);
    return paidAt.isEmpty ? money : '$money · $paidAt';
  }

  ({String date, bool overdue}) _dueInfo(PaymentDashboard? dashboard) {
    final invoices = dashboard?.recentInvoices ?? const <RecentInvoice>[];
    RecentInvoice? open;
    for (final invoice in invoices) {
      if (invoice.remainingAmount > 0 && invoice.dueDateLabel.isNotEmpty) {
        open = invoice;
        break;
      }
    }
    final selected = open ?? (invoices.isEmpty ? null : invoices.first);
    if (selected == null) {
      return (date: '', overdue: false);
    }
    return (date: selected.dueDateLabel, overdue: selected.isOverdue);
  }
}

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({required this.date, required this.overdue});

  final String date;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = overdue ? AppPalette.danger : tokens.brand;
    final background = overdue
        ? Color.alphaBlend(
            AppPalette.danger.withValues(alpha: 0.10),
            tokens.surface,
          )
        : tokens.brand.withValues(alpha: 0.12);
    return Container(
      key: Key(overdue ? 'dashboard-due-overdue' : 'dashboard-due-date'),
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            overdue
                ? Icons.warning_amber_rounded
                : Icons.calendar_today_rounded,
            size: 12.sp,
            color: color,
          ),
          4.w.widthBox(),
          Text(
            overdue ? 'Overdue' : 'Due Date',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          5.w.widthBox(),
          Text(
            date,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onSelectFeature,
    required this.enabledFeatures,
  });

  final ValueChanged<String> onSelectFeature;
  final List<CondoFeature> enabledFeatures;
  static const int _quickActionColumns = 2;
  static const int _quickActionRows = 3;
  static const int _quickActionSlots = _quickActionColumns * _quickActionRows;

  /// Six fixed slots, three across and two down. Disabled features are
  /// omitted and the remaining shortcuts keep their order. Every other module
  /// is one tap away through "All resident services" below the grid.
  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final actions = <Widget>[];
    for (final feature in enabledFeatures) {
      final action = _actionFor(feature, tokens);
      if (action != null) actions.add(action);
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    final slots = actions.take(_quickActionSlots).toList();
    return Column(
      children: [
        for (var row = 0; row < _quickActionRows; row++) ...[
          if (row > 0) 10.h.heightBox(),
          Row(
            children: [
              for (var column = 0; column < _quickActionColumns; column++) ...[
                if (column > 0) 10.w.widthBox(),
                Expanded(
                  child: row * _quickActionColumns + column < slots.length
                      ? slots[row * _quickActionColumns + column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget? _actionFor(CondoFeature feature, AppThemeTokens tokens) {
    switch (feature) {
      case CondoFeature.payments:
        return _QuickAction(
          icon: Icons.payments_outlined,
          label: 'Pay fees',
          color: tokens.brandTint,
          onTap: () {
            vibrateNow();
            onSelectFeature(CondoFeature.payments.wire);
          },
        );
      case CondoFeature.maintenance:
        return _QuickAction(
          icon: Icons.handyman_outlined,
          label: 'Maintenance',
          color: tokens.brandTint,
          onTap: () {
            vibrateNow();
            onSelectFeature(CondoFeature.maintenance.wire);
          },
        );
      case CondoFeature.condoServices:
        return _QuickAction(
          icon: Icons.room_service_outlined,
          label: 'Services',
          color: tokens.infoTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.services);
          },
        );
      case CondoFeature.facilities:
        return _QuickAction(
          icon: Icons.event_available_outlined,
          label: 'Reserve',
          color: tokens.infoTint,
          onTap: () {
            vibrateNow();
            onSelectFeature(CondoFeature.facilities.wire);
          },
        );
      case CondoFeature.complaints:
        return _QuickAction(
          icon: Icons.report_problem_outlined,
          label: CondoFeature.complaints.label,
          color: tokens.infoTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.complaints);
          },
        );
      case CondoFeature.visitors:
        return _QuickAction(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Register visitor',
          color: tokens.warningTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.visitors);
          },
        );
      case CondoFeature.parking:
        return _QuickAction(
          icon: Icons.local_parking_outlined,
          label: CondoFeature.parking.label,
          color: tokens.brandTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.parking);
          },
        );
      case CondoFeature.rulesViolations:
        return _QuickAction(
          icon: Icons.gavel_outlined,
          label: CondoFeature.rulesViolations.label,
          color: tokens.warningTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.rules);
          },
        );
      case CondoFeature.violationAppeals:
        return _QuickAction(
          icon: Icons.rule_outlined,
          label: CondoFeature.violationAppeals.label,
          color: tokens.warningTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.rules);
          },
        );
      case CondoFeature.partialPayment:
        return _QuickAction(
          icon: Icons.pie_chart_outline,
          label: CondoFeature.partialPayment.label,
          color: tokens.infoTint,
          onTap: () {
            vibrateNow();
            onSelectFeature(CondoFeature.payments.wire);
          },
        );
      case CondoFeature.lease:
        return _QuickAction(
          icon: Icons.description_outlined,
          label: CondoFeature.lease.label,
          color: tokens.infoTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.lease);
          },
        );
      case CondoFeature.convenienceStore:
        return _QuickAction(
          icon: Icons.storefront_outlined,
          label: 'Convenience Store',
          color: tokens.brandTint,
          onTap: () {
            vibrateNow();
            Get.toNamed(AppRoutes.store);
          },
        );
      case CondoFeature.dashboard:
        return null;
    }
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
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
  const _AnnouncementCard({required this.announcement});

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
