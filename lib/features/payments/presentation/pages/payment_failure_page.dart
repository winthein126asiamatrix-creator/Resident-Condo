import 'package:test/core/utils/sized_box_extensions.dart';
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
  const PaymentFailurePage({required this.payment, super.key});

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
          18.h.heightBox(),
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
          20.h.heightBox(),
          Text(
            'Payment Not Completed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          8.h.heightBox(),
          Text(
            payment.failureReason ??
                'The transaction was declined. No amount has been charged.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, height: 1.4),
          ),
          24.h.heightBox(),
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
                6.h.heightBox(),
                Text(
                  'A failed payment never changes an invoice. These items stay '
                  'unpaid and can be selected again.',
                  style: TextStyle(
                    color: tokens.mutedStrong,
                    fontSize: 12.sp,
                    height: 1.4,
                  ),
                ),
                12.h.heightBox(),
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
                        8.w.widthBox(),
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
          20.h.heightBox(),
          FilledButton.icon(
            key: Key('retry-payment'),
            onPressed: () => Get.offNamed(AppRoutes.paymentMethod),
            icon: Icon(Icons.refresh_rounded, size: 18),
            label: Text('Try another method'),
            style: FilledButton.styleFrom(minimumSize: Size.fromHeight(52)),
          ),
          10.h.heightBox(),
          OutlinedButton(
            onPressed: () => Get.offAllNamed(AppRoutes.home),
            style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(50)),
            child: Text('Back to payments'),
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
