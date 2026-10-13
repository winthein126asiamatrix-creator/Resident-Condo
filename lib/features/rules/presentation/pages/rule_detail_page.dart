import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/rules.dart';
import '../controllers/rules_controller.dart';
import '../widgets/rules_widgets.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';

class RuleDetailPage extends GetView<RulesController> {
  RuleDetailPage({required this.rule, super.key});

  final CommunityRule rule;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final current = controller.rules.firstWhere(
      (item) => item.id == rule.id,
      orElse: () => rule,
    );
    final related = controller.violations
        .where((violation) => violation.ruleId == current.id)
        .toList();

    return Scaffold(
      appBar: AppDetailAppBar(title: 'Community rule'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppHeroPanel(
            icon: ruleCategoryIcon(current.category),
            title: '${current.code} · ${current.category.label}',
            subtitle: current.title,
            footnote: 'Last updated ${current.updatedOn}',
            trailing: current.fineAmount > 0
                ? AppStatusPill(
                    label: 'Fine ${AppFormatters.currency(current.fineAmount)}',
                    color: AppPalette.danger,
                  )
                : null,
          ),
          SizedBox(height: 18.h),
          AppSectionCard(
            title: 'In short',
            child: Text(
              current.summary,
              style: TextStyle(
                color: tokens.mutedStrong,
                height: 1.45,
                fontSize: 13.sp,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          AppSectionCard(
            title: 'Full rule',
            child: Text(
              current.details,
              style: TextStyle(color: tokens.mutedStrong, height: 1.5),
            ),
          ),
          if (related.isNotEmpty) ...[
            SizedBox(height: 20.h),
            AppSectionHeader(
              title: 'Violations of this rule',
              count: related.length,
            ),
            SizedBox(height: 10.h),
            for (final violation in related)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: AppSectionCard(
                  title: violation.reference,
                  subtitle: 'Issued ${violation.issuedOn}',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          violation.description,
                          style: TextStyle(
                            color: tokens.muted,
                            fontSize: 12.sp,
                            height: 1.4,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      ViolationStatusPill(status: violation.status),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
