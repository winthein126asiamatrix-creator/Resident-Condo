import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
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
  const LeasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Rental & lease',
        actions: [
          IconButton(
            onPressed: controller.loadLeases,
            tooltip: 'Refresh lease',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.leases.isEmpty) {
          return const Center(child: CircularProgressIndicator());
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
            key: const Key('lease-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
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
                const SizedBox(height: 16),
                AppSectionCard(
                  title: 'People on the lease',
                  child: Column(
                    children: [
                      _PartyTile(party: lease.owner),
                      const Divider(height: 20),
                      _PartyTile(party: lease.tenant),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 22),
                const AppSectionHeader(title: 'Renewal requests'),
                const SizedBox(height: 4),
                const Text(
                  'The tenant and the owner can both propose a renewal.',
                  style: TextStyle(color: AppPalette.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                _RenewalList(controller: controller, lease: lease),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('request-lease-renewal'),
                  onPressed: controller.pendingRenewal != null
                      ? null
                      : () {
                          controller.selectLease(lease);
                          Get.toNamed(AppRoutes.leaseRenewal);
                        },
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  label: Text(
                    controller.pendingRenewal == null
                        ? 'Request renewal'
                        : 'Renewal under review',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                if (controller.pendingRenewal == null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Rent is billed separately from your monthly condo fee.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppPalette.muted, fontSize: 11),
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
  const _LeaseProgressCard({required this.lease, required this.perspective});
  final Lease lease;
  final String perspective;

  @override
  Widget build(BuildContext context) {
    final color = switch (lease.status) {
      LeaseStatus.expired => AppPalette.danger,
      LeaseStatus.expiringSoon => AppPalette.warning,
      _ => AppPalette.success,
    };

    return AppHeroPanel(
      icon: Icons.description_rounded,
      title: lease.unitLabel,
      subtitle:
          '${lease.reference} · $perspective '
          '${AppFormatters.currency(lease.monthlyRent)} / month',
      footnote: lease.hasExpired
          ? 'This term has ended. Submit a renewal to continue the tenancy.'
          : 'Ends ${AppDates.format(lease.endDate)} · ${lease.daysRemaining} days left',
      trailing: AppStatusPill(label: lease.status.label, color: color),
      leading: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Term progress',
                style: TextStyle(
                  color: AppPalette.brandOnDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                AppFormatters.percent(lease.progress),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: lease.progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                AppDates.formatShort(lease.startDate),
                style: const TextStyle(
                  color: AppPalette.brandOnDarkMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                AppDates.formatShort(lease.endDate),
                style: const TextStyle(
                  color: AppPalette.brandOnDarkMuted,
                  fontSize: 11,
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
  const _PartyTile({required this.party});
  final LeaseParty party;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppPalette.brandSoft,
          child: Text(
            party.initials,
            style: const TextStyle(
              color: AppPalette.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                party.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                party.role.label,
                style: const TextStyle(color: AppPalette.muted, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                party.phone,
                style: const TextStyle(color: AppPalette.faint, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Call ${party.name}',
          onPressed: () {},
          icon: const Icon(Icons.call_outlined, color: AppPalette.brand),
        ),
      ],
    );
  }
}

class _RenewalList extends StatelessWidget {
  const _RenewalList({required this.controller, required this.lease});
  final LeaseController controller;
  final Lease lease;

  @override
  Widget build(BuildContext context) {
    final items = controller.renewalsFor(lease);
    if (items.isEmpty) {
      return AppCard(
        child: const Text(
          'No renewal request yet. Start one at least 60 days before the end '
          'of the term.',
          style: TextStyle(color: AppPalette.muted, fontSize: 12, height: 1.4),
        ),
      );
    }
    return Column(
      children: [
        for (final renewal in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RenewalCard(controller: controller, renewal: renewal),
          ),
      ],
    );
  }
}

class _RenewalCard extends StatelessWidget {
  const _RenewalCard({required this.controller, required this.renewal});
  final LeaseController controller;
  final LeaseRenewal renewal;

  @override
  Widget build(BuildContext context) {
    final color = switch (renewal.status) {
      RenewalStatus.approved => AppPalette.success,
      RenewalStatus.declined => AppPalette.danger,
      RenewalStatus.withdrawn => AppPalette.faint,
      RenewalStatus.pending => AppPalette.warning,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusPill(label: renewal.status.label, color: color),
              const Spacer(),
              Text(
                renewal.requestedOn,
                style: const TextStyle(color: AppPalette.faint, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${AppFormatters.currency(renewal.proposedRent)} / month',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            '${renewal.proposedStart} → ${renewal.proposedEnd}',
            style: const TextStyle(color: AppPalette.mutedStrong, fontSize: 12),
          ),
          if (renewal.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              renewal.note,
              style: const TextStyle(
                color: AppPalette.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Requested by ${renewal.requestedBy}'
            '${renewal.decidedOn == null ? '' : ' · updated ${renewal.decidedOn}'}',
            style: const TextStyle(color: AppPalette.faint, fontSize: 11),
          ),
          if (renewal.status == RenewalStatus.pending) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: Key('withdraw-renewal-${renewal.id}'),
              onPressed: () => _withdraw(context),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Withdraw request'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.danger,
                side: const BorderSide(color: Color(0xFFF0C6C0)),
                minimumSize: const Size.fromHeight(44),
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
