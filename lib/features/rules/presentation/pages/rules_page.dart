import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../controllers/rules_controller.dart';
import '../widgets/rules_widgets.dart';
import '../../../../core/widgets/app_status_pill.dart';

class RulesPage extends GetView<RulesController> {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules & violations'),
        actions: [
          IconButton(
            onPressed: controller.loadAll,
            tooltip: 'Refresh rules',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.rules.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.rules.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load rules',
            message: controller.errorMessage.value!,
            icon: Icons.gavel_rounded,
            actionLabel: 'Try again',
            onAction: controller.loadAll,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            key: const Key('rules-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AppHeroPanel(
                icon: Icons.gavel_rounded,
                title: 'Community rules',
                subtitle: '${controller.rules.length} rules · '
                    '${controller.openViolationCount} open violations',
                footnote: 'Fines are billed as a separate Violation Fine item, '
                    'never inside the monthly condo fee.',
                trailing: controller.outstandingFines > 0
                    ? AppStatusPill(
                        label: AppFormatters.currency(
                          controller.outstandingFines,
                        ),
                        color: AppPalette.danger,
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              _TabRow(controller: controller),
              const SizedBox(height: 18),
              if (controller.tab.value == RulesTab.violations)
                _Violations(controller: controller)
              else
                _Rules(controller: controller),
            ],
          ),
        );
      }),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.controller});
  final RulesController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.brandTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final tab in RulesTab.values)
            Expanded(
              child: GestureDetector(
                key: Key('rules-tab-${tab.name}'),
                onTap: () => controller.selectTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: controller.tab.value == tab
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    tab == RulesTab.rules
                        ? 'Community rules'
                        : 'My violations (${controller.violations.length})',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: controller.tab.value == tab
                          ? AppPalette.brand
                          : AppPalette.mutedStrong,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules({required this.controller});
  final RulesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.rules.isEmpty) {
      return const AppStateMessage(
        title: 'No rules published',
        message: 'Community rules will appear here.',
        icon: Icons.menu_book_outlined,
      );
    }
    return Column(
      children: [
        for (final rule in controller.rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () {
                controller.selectRule(rule);
                Get.toNamed(AppRoutes.ruleDetail, arguments: rule);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconTile(
                    icon: ruleCategoryIcon(rule.category),
                    color: AppPalette.brand,
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
                                rule.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              rule.code,
                              style: const TextStyle(
                                color: AppPalette.faint,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          rule.summary,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fine up to ${AppFormatters.currency(rule.fineAmount)}',
                          style: const TextStyle(
                            color: AppPalette.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Violations extends StatelessWidget {
  const _Violations({required this.controller});
  final RulesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.violations.isEmpty) {
      return const AppStateMessage(
        title: 'No violations',
        message: 'You have no rule violations on record. Well done!',
        icon: Icons.verified_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Issued to your unit',
          count: controller.violations.length,
        ),
        const SizedBox(height: 10),
        for (final violation in controller.violations)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () {
                controller.selectViolation(violation);
                Get.toNamed(AppRoutes.violationDetail, arguments: violation);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconTile(
                    icon: Icons.report_rounded,
                    color: violationStatusColor(violation.status),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          violation.ruleTitle,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${violation.reference} · issued ${violation.issuedOn}',
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ViolationStatusPill(status: violation.status),
                            const SizedBox(width: 8),
                            if (controller.appealFor(violation) != null)
                              const AppStatusPill(
                                label: 'Appeal open',
                                color: AppPalette.info,
                                dense: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.currency(violation.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: violation.amount > 0
                              ? AppPalette.danger
                              : AppPalette.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppPalette.faint,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
