import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  LeaseRenewalSentPage({required this.renewal, super.key});

  final LeaseRenewal renewal;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Renewal requested'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          SizedBox(height: 22.h),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tokens.brandTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: AppPalette.success,
                size: 48,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Renewal request sent',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Both parties will be notified and the request stays pending until '
            'it is approved or declined.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, height: 1.4),
          ),
          SizedBox(height: 24.h),
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
          SizedBox(height: 20.h),
          FilledButton.icon(
            onPressed: () => Get.offAllNamed(AppRoutes.lease),
            icon: Icon(Icons.home_rounded),
            label: Text('Back to lease'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: tokens.muted)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
