import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/visitor.dart';
import '../controllers/visitor_controller.dart';
import '../widgets/visitor_status_badge.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_primary_action.dart';

class VisitorsPage extends GetView<VisitorController> {
  const VisitorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Visitors'),
      body: Obx(() {
        if (controller.isLoading.value && controller.visitors.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.visitors.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load visitors',
            message: controller.errorMessage.value!,
            icon: Icons.people_outline_rounded,
            actionLabel: 'Try again',
            onAction: controller.loadVisitors,
          );
        }
        final visible = controller.visibleVisitors;
        return RefreshIndicator(
          onRefresh: controller.loadVisitors,
          child: ListView(
            key: const Key('visitors-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
              96,
            ),
            children: [
              _VisitorHero(controller: controller),
              const SizedBox(height: 16),
              AppCard(
                color: AppPalette.brandTint,
                borderColor: AppPalette.brandSoft,
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppPalette.brand),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Visitors are verified with an alphanumeric access code '
                        'read out at the lobby desk.',
                        style: TextStyle(
                          color: AppPalette.mutedStrong,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.visitorVerify),
                      child: const Text('Verify'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FilterRow(controller: controller),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                const AppStateMessage(
                  title: 'Nothing here yet',
                  message: 'Register a visitor to generate an access code.',
                  icon: Icons.person_add_alt_1_outlined,
                )
              else
                for (final visitor in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VisitorCard(
                      controller: controller,
                      visitor: visitor,
                    ),
                  ),
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('register-visitor'),
        onPressed: () => Get.toNamed(AppRoutes.visitorRegister),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Register visitor'),
      ),
    );
  }
}

class _VisitorHero extends StatelessWidget {
  const _VisitorHero({required this.controller});
  final VisitorController controller;

  @override
  Widget build(BuildContext context) {
    return AppHeroPanel(
      icon: Icons.people_alt_rounded,
      title: 'Visitor access',
      subtitle:
          '${controller.activeCount} active  ·  ${controller.onSiteCount} on site now',
      footnote: 'Codes expire automatically after the visitor checks out.',
      trailing: IconButton(
        tooltip: 'Refresh visitors',
        onPressed: controller.loadVisitors,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller});
  final VisitorController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in VisitorFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${filter.label} (${controller.countFor(filter)})'),
                selected: controller.filter.value == filter,
                onSelected: (_) => controller.selectFilter(filter),
                selectedColor: AppPalette.brandSoft,
                labelStyle: TextStyle(
                  color: controller.filter.value == filter
                      ? AppPalette.brand
                      : AppPalette.mutedStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({required this.controller, required this.visitor});
  final VisitorController controller;
  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    final color = visitorStatusColor(visitor.status);
    return AppCard(
      onTap: () {
        controller.selectVisitor(visitor);
        Get.toNamed(AppRoutes.visitorPass, arguments: visitor);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Text(
                  visitor.initials,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${visitor.relation.label} · ${visitor.purpose}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusPill(label: visitor.status.label, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.vpn_key_outlined,
                  size: 16,
                  color: AppPalette.brand,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    visitor.accessCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${visitor.date} ? ${visitor.arrivalWindow}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (visitor.canCheckIn)
                Expanded(
                  child: AppPrimaryAction(
                    key: Key('check-in-${visitor.id}'),
                    height: 44,
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () => _confirmCheckIn(context),
                    label: 'Check in',
                    icon: Icons.login_rounded,
                  ),
                ),
              if (visitor.canCheckIn && visitor.canCheckOut)
                const SizedBox(width: 10),
              if (visitor.canCheckOut)
                Expanded(
                  child: AppPrimaryAction(
                    key: Key('check-out-${visitor.id}'),
                    height: 44,
                    backgroundColor: AppPalette.accent,
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () => _confirmCheckOut(context),
                    label: 'Check out',
                    icon: Icons.logout_rounded,
                  ),
                ),
              if (!visitor.canCheckIn && !visitor.canCheckOut)
                Expanded(
                  child: AppOutlinedButton(
                    onPressed: () {
                      controller.selectVisitor(visitor);
                      Get.toNamed(AppRoutes.visitorPass, arguments: visitor);
                    },
                    label: 'View pass',
                    icon: Icons.badge_outlined,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCheckIn(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Check in ${visitor.name}?',
      message:
          'The lobby will record arrival at the current time using access code '
          '${visitor.accessCode}.',
      confirmLabel: 'Check in',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.checkIn(visitor);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to check in' : 'Visitor checked in',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : '${updated.name} is on site.',
      isError: updated == null,
    );
  }

  Future<void> _confirmCheckOut(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Check out ${visitor.name}?',
      message: 'The access code will stop working once the visitor leaves.',
      confirmLabel: 'Check out',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final updated = await controller.checkOut(visitor);
    if (!context.mounted) {
      return;
    }
    showAppFeedback(
      context,
      title: updated == null ? 'Unable to check out' : 'Visitor checked out',
      message: updated == null
          ? (controller.errorMessage.value ?? 'Please try again.')
          : 'Thanks for hosting ${updated.name}.',
      isError: updated == null,
    );
  }
}
