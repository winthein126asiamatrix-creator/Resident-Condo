import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/lease.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

class LeaseRenewalSentPage extends StatelessWidget {
  const LeaseRenewalSentPage({required this.renewal, super.key});

  final LeaseRenewal renewal;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Renewal requested'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          const SizedBox(height: 22),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tokens.brandTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppPalette.success,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Renewal request sent',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Both parties will be notified and the request stays pending until '
            'it is approved or declined.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              children: [
                _Line(
                  label: 'Proposed rent',
                  value:
                      '${AppFormatters.currency(renewal.proposedRent)} / month',
                ),
                _Line(label: 'New start', value: renewal.proposedStart),
                _Line(label: 'New end', value: renewal.proposedEnd),
                _Line(label: 'Status', value: renewal.status.label),
                _Line(label: 'Requested by', value: renewal.requestedBy),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Get.offAllNamed(AppRoutes.lease),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Back to lease'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: tokens.muted)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
