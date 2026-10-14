import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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


import '../../../../core/widgets/app_detail_app_bar.dart';


import '../../../../core/widgets/app_segmented_tabs.dart';

class RulesPage extends GetView<RulesController> {
  RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Rules & violations',
        actions: [
          IconButton(
            onPressed: controller.loadAll,
            tooltip: 'Refresh rules',
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.rules.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null && controller.rules.isEmpty) {
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
            key: Key('rules-scroll'),
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AppHeroPanel(
                icon: Icons.gavel_rounded,
                title: 'Community rules',
                subtitle:
                    '${controller.rules.length} rules Â· '
                    '${controller.openViolationCount} open violations',
                footnote:
                    'Fines are billed as a separate Violation Fine item, '
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
              18.h.heightBox(),
              _TabRow(controller: controller),
              18.h.heightBox(),
              // The pill slides into the next tab, so the panel that follows it
              // across rather than swapping the instant the tap lands.
              AnimatedSwitcher(
                duration: AppSegmentedTabs.slideDuration,
                switchInCurve: AppSegmentedTabs.slideCurve,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(controller.tab.value),
                  child: controller.tab.value == RulesTab.violations
                      ? _Violations(controller: controller)
                      : _Rules(controller: controller),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TabRow extends StatelessWidget {
  _TabRow({required this.controller});
  final RulesController controller;

  @override
  Widget build(BuildContext context) {
    return AppSegmentedTabs(
      keyPrefix: 'rules',
      selectedIndex: controller.tab.value.index,
      onSelect: (index) => controller.selectTab(RulesTab.values[index]),
      tabs: [
        AppSegmentedTab(
          name: 'rules',
          label: 'Community rules',
          icon: Icons.menu_book_rounded,
        ),
        // The count rides on the label, so it has to be rebuilt with the list.
        AppSegmentedTab(
          name: 'violations',
          label: 'My violations (${controller.violations.length})',
          icon: Icons.report_rounded,
        ),
      ],
    );
  }
}

class _Rules extends StatelessWidget {
  _Rules({required this.controller});
  final RulesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.rules.isEmpty) {
      return AppStateMessage(
        title: 'No rules published',
        message: 'Community rules will appear here.',
        icon: Icons.menu_book_outlined,
      );
    }
    return Column(
      children: [
        for (final rule in controller.rules)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
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
                  12.w.widthBox(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rule.title,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              rule.code,
                              style: TextStyle(
                                color: AppPalette.faint,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        5.h.heightBox(),
                        Text(
                          rule.summary,
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 12.sp,
                            height: 1.35,
                          ),
                        ),
                        8.h.heightBox(),
                        Text(
                          'Fine up to ${AppFormatters.currency(rule.fineAmount)}',
                          style: TextStyle(
                            color: AppPalette.warning,
                            fontSize: 11.sp,
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
  _Violations({required this.controller});
  final RulesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.violations.isEmpty) {
      return AppStateMessage(
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
        10.h.heightBox(),
        for (final violation in controller.violations)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
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
                  12.w.widthBox(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          violation.ruleTitle,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        4.h.heightBox(),
                        Text(
                          '${violation.reference} Â· issued ${violation.issuedOn}',
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11.sp,
                          ),
                        ),
                        8.h.heightBox(),
                        Row(
                          children: [
                            ViolationStatusPill(status: violation.status),
                            8.w.widthBox(),
                            if (controller.appealFor(violation) != null)
                              AppStatusPill(
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
                      4.h.heightBox(),
                      Icon(
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
