import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../../../core/theme/app_palette.dart';


import '../../../../core/theme/app_theme_tokens.dart';


import '../../../../core/utils/app_dates.dart';


import '../../../../core/utils/app_formatters.dart';


import '../../../../core/widgets/app_card.dart';


import '../../../../core/widgets/app_dialogs.dart';


import '../../../../core/widgets/app_section.dart';


import '../../../../core/widgets/app_state_message.dart';


import '../../../../core/widgets/app_status_pill.dart';


import '../../domain/entities/lease.dart';


import '../controllers/lease_controller.dart';


import '../../../../core/widgets/app_detail_app_bar.dart';


import '../../../../core/theme/app_spacing.dart';

class LeasePage extends GetView<LeaseController> {
  LeasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Rental & lease',
        actions: [
          IconButton(
            onPressed: controller.loadLeases,
            tooltip: 'Refresh lease',
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.leases.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.leases.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load lease',
            message: controller.errorMessage.value!,
            icon: Icons.description_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadLeases,
          );
        }
        if (controller.leases.isEmpty) {
          return AppStateMessage(
            title: 'No active lease',
            message:
                'Your rental agreement will appear here once it is registered.',
            icon: Icons.home_work_outlined,
            actionLabel: 'Refresh',
            onAction: controller.loadLeases,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadLeases,
          child: ListView(
            key: Key('lease-scroll'),
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
              32,
            ),
            children: [
              for (final lease in controller.leases) ...[
                _LeaseProgressCard(
                  lease: lease,
                  perspective: controller.rentPerspectiveLabel,
                ),
                16.h.heightBox(),
                AppSectionCard(
                  title: 'People on the lease',
                  child: Column(
                    children: [
                      _PartyTile(party: lease.owner),
                      Divider(height: 20),
                      _PartyTile(party: lease.tenant),
                    ],
                  ),
                ),
                16.h.heightBox(),
                AppSectionCard(
                  title: 'Lease terms',
                  child: Column(
                    children: [
                      AppLabelValueRow(
                        label: 'Agreement',
                        value: lease.reference,
                      ),
                      AppLabelValueRow(
                        label: 'Start date',
                        value: AppDates.format(lease.startDate),
                      ),
                      AppLabelValueRow(
                        label: 'End date',
                        value: AppDates.format(lease.endDate),
                      ),
                      AppLabelValueRow(
                        label: 'Rent due',
                        value: 'Day ${lease.rentDueDay} of each month',
                      ),
                      AppLabelValueRow(
                        label: 'Security deposit',
                        value: AppFormatters.currency(lease.securityDeposit),
                      ),
                      AppLabelValueRow(
                        label: 'Last rent payment',
                        value: lease.lastRentPaymentDate,
                      ),
                    ],
                  ),
                ),
                22.h.heightBox(),
                AppSectionHeader(title: 'Renewal requests'),
                4.h.heightBox(),
                Text(
                  'The tenant and the owner can both propose a renewal.',
                  style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                ),
                10.h.heightBox(),
                _RenewalList(controller: controller, lease: lease),
                20.h.heightBox(),
                FilledButton.icon(
                  key: Key('request-lease-renewal'),
                  onPressed: controller.pendingRenewal != null
                      ? null
                      : () {
                          vibrateNow();
                          controller.selectLease(lease);
                          Get.toNamed(AppRoutes.leaseRenewal);
                        },
                  icon: Icon(Icons.autorenew_rounded, size: 18),
                  label: Text(
                    controller.pendingRenewal == null
                        ? 'Request renewal'
                        : 'Renewal under review',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(52),
                  ),
                ),
                if (controller.pendingRenewal == null) ...[
                  8.h.heightBox(),
                  Text(
                    'Rent is billed separately from your monthly condo fee.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                  ),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _LeaseProgressCard extends StatelessWidget {
  _LeaseProgressCard({required this.lease, required this.perspective});
  final Lease lease;
  final String perspective;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = switch (lease.status) {
      LeaseStatus.expired => AppPalette.danger,
      LeaseStatus.expiringSoon => AppPalette.warning,
      _ => AppPalette.success,
    };

    return AppHeroPanel(
      icon: Icons.description_rounded,
      title: lease.unitLabel,
      subtitle:
          '${lease.reference} Â· $perspective '
          '${AppFormatters.currency(lease.monthlyRent)} / month',
      footnote: lease.hasExpired
          ? 'This term has ended. Submit a renewal to continue the tenancy.'
          : 'Ends ${AppDates.format(lease.endDate)} Â· ${lease.daysRemaining} days left',
      trailing: AppStatusPill(label: lease.status.label, color: color),
      leading: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Term progress',
                style: TextStyle(
                  color: tokens.brandOnDark,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                AppFormatters.percent(lease.progress),
                style: TextStyle(
                  color: tokens.brandOnDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          8.h.heightBox(),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: lease.progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation<Color>(tokens.brandOnDark),
            ),
          ),
          10.h.heightBox(),
          Row(
            children: [
              Text(
                AppDates.formatShort(lease.startDate),
                style: TextStyle(
                  color: tokens.brandOnDarkMuted,
                  fontSize: 11.sp,
                ),
              ),
              Spacer(),
              Text(
                AppDates.formatShort(lease.endDate),
                style: TextStyle(
                  color: tokens.brandOnDarkMuted,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartyTile extends StatelessWidget {
  _PartyTile({required this.party});
  final LeaseParty party;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: tokens.brandSoft,
          child: Text(
            party.initials,
            style: TextStyle(color: tokens.brand, fontWeight: FontWeight.w800),
          ),
        ),
        12.w.widthBox(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(party.name, style: TextStyle(fontWeight: FontWeight.w800)),
              2.h.heightBox(),
              Text(
                party.role.label,
                style: TextStyle(color: tokens.muted, fontSize: 11.sp),
              ),
              2.h.heightBox(),
              Text(
                party.phone,
                style: TextStyle(color: tokens.faint, fontSize: 11.sp),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Call ${party.name}',
          onPressed: () {},
          icon: Icon(Icons.call_outlined, color: tokens.brand),
        ),
      ],
    );
  }
}

class _RenewalList extends StatelessWidget {
  _RenewalList({required this.controller, required this.lease});
  final LeaseController controller;
  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final items = controller.renewalsFor(lease);
    if (items.isEmpty) {
      return AppCard(
        child: Text(
          'No renewal request yet. Start one at least 60 days before the end '
          'of the term.',
          style: TextStyle(color: tokens.muted, fontSize: 12.sp, height: 1.4),
        ),
      );
    }
    return Column(
      children: [
        for (final renewal in items)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _RenewalCard(controller: controller, renewal: renewal),
          ),
      ],
    );
  }
}

class _RenewalCard extends StatelessWidget {
  _RenewalCard({required this.controller, required this.renewal});
  final LeaseController controller;
  final LeaseRenewal renewal;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = switch (renewal.status) {
      RenewalStatus.approved => AppPalette.success,
      RenewalStatus.declined => AppPalette.danger,
      RenewalStatus.withdrawn => tokens.faint,
      RenewalStatus.pending => AppPalette.warning,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusPill(label: renewal.status.label, color: color),
              Spacer(),
              Text(
                renewal.requestedOn,
                style: TextStyle(color: tokens.faint, fontSize: 11.sp),
              ),
            ],
          ),
          12.h.heightBox(),
          Text(
            '${AppFormatters.currency(renewal.proposedRent)} / month',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17.sp),
          ),
          4.h.heightBox(),
          Text(
            '${renewal.proposedStart} â†’ ${renewal.proposedEnd}',
            style: TextStyle(color: tokens.mutedStrong, fontSize: 12.sp),
          ),
          if (renewal.note.isNotEmpty) ...[
            8.h.heightBox(),
            Text(
              renewal.note,
              style: TextStyle(
                color: tokens.muted,
                fontSize: 12.sp,
                height: 1.4,
              ),
            ),
          ],
          8.h.heightBox(),
          Text(
            'Requested by ${renewal.requestedBy}'
            '${renewal.decidedOn == null ? '' : ' Â· updated ${renewal.decidedOn}'}',
            style: TextStyle(color: tokens.faint, fontSize: 11.sp),
          ),
          if (renewal.status == RenewalStatus.pending) ...[
            12.h.heightBox(),
            OutlinedButton.icon(
              key: Key('withdraw-renewal-${renewal.id}'),
              onPressed: () => _withdraw(context),
              icon: Icon(Icons.undo_rounded, size: 18),
              label: Text('Withdraw request'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.danger,
                side: BorderSide(color: Color(0xFFF0C6C0)),
                minimumSize: Size.fromHeight(44),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _withdraw(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Withdraw renewal request?',
      message:
          'The pending renewal for ${renewal.proposedStart} will be cancelled. '
          'You can submit a new one afterwards.',
      confirmLabel: 'Withdraw',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.withdrawRenewal(renewal);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to withdraw' : 'Renewal withdrawn',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'The request was withdrawn.',
      isError: updated == null,
    );
  }
}
