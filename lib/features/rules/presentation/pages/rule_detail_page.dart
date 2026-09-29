import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/rules.dart';
import '../controllers/rules_controller.dart';
import '../widgets/rules_widgets.dart';

class RuleDetailPage extends GetView<RulesController> {
  const RuleDetailPage({required this.rule, super.key});

  final CommunityRule rule;

  @override
  Widget build(BuildContext context) {
    final current = controller.rules.firstWhere(
      (item) => item.id == rule.id,
      orElse: () => rule,
    );
    final related = controller.violations
        .where((violation) => violation.ruleId == current.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Community rule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
          const SizedBox(height: 18),
          AppSectionCard(
            title: 'In short',
            child: Text(
              current.summary,
              style: const TextStyle(
                color: AppPalette.mutedStrong,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Full rule',
            child: Text(
              current.details,
              style: const TextStyle(
                color: AppPalette.mutedStrong,
                height: 1.5,
              ),
            ),
          ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 20),
            AppSectionHeader(
              title: 'Violations of this rule',
              count: related.length,
            ),
            const SizedBox(height: 10),
            for (final violation in related)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppSectionCard(
                  title: violation.reference,
                  subtitle: 'Issued ${violation.issuedOn}',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          violation.description,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
