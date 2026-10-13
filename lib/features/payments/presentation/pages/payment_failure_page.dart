import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shown when the gateway declines the payment.
///
/// Nothing is settled: the invoice keeps the same open items so the resident
/// can retry with another method.
class PaymentFailurePage extends StatelessWidget {
  PaymentFailurePage({required this.payment, super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Payment failed'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          SizedBox(height: 18.h),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tokens.brandTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: AppPalette.danger,
                size: 48,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Payment Not Completed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            payment.failureReason ??
                'The transaction was declined. No amount has been charged.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, height: 1.4),
          ),
          SizedBox(height: 24.h),
          AppCard(
            color: tokens.brandTint,
            borderColor: Color(0xFFF0C6C0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your fees are still open',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppPalette.danger,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'A failed payment never changes an invoice. These items stay '
                  'unpaid and can be selected again.',
                  style: TextStyle(
                    color: tokens.mutedStrong,
                    fontSize: 12.sp,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12.h),
                for (final item in payment.items)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: AppPalette.danger,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            item.type.label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.currency(item.amount),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(height: 24),
                _Line(
                  label: 'Attempted amount',
                  value: AppFormatters.currency(payment.amount),
                ),
                _Line(label: 'Method', value: payment.method.label),
                _Line(label: 'Reference', value: payment.transactionId),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          FilledButton.icon(
            key: Key('retry-payment'),
            onPressed: () => Get.offNamed(AppRoutes.paymentMethod),
            icon: Icon(Icons.refresh_rounded, size: 18),
            label: Text('Try another method'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(52),
            ),
          ),
          SizedBox(height: 10.h),
          OutlinedButton(
            onPressed: () => Get.offAllNamed(AppRoutes.home),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(50),
            ),
            child: Text('Back to payments'),
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
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.mutedStrong, fontSize: 12.sp),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}
