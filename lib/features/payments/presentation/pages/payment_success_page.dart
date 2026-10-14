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

class PaymentSuccessPage extends StatelessWidget {
  PaymentSuccessPage({required this.payment, super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Payment successful'),
      body: ListView(
        key: Key('payment-success-scroll'),
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
                Icons.check_rounded,
                color: AppPalette.success,
                size: 48,
              ),
            ),
          ),
          20.h.heightBox(),
          Text(
            'Payment Successful',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          8.h.heightBox(),
          Text(
            'Only the items you selected have been settled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted),
          ),
          24.h.heightBox(),
          _SuccessCard(payment: payment),
          20.h.heightBox(),
          FilledButton.icon(
            onPressed: () =>
                Get.toNamed(AppRoutes.paymentReceipt, arguments: payment),
            icon: Icon(Icons.receipt_long_outlined),
            label: Text('View Receipt'),
            style: FilledButton.styleFrom(minimumSize: Size.fromHeight(52)),
          ),
          10.h.heightBox(),
          OutlinedButton(
            onPressed: () => Get.offAllNamed(AppRoutes.home),
            style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(50)),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  _SuccessCard({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAID ITEMS (${payment.items.length})',
            style: TextStyle(
              color: tokens.brandOnDark,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          8.h.heightBox(),
          for (final item in payment.items)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppPalette.success,
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
          _SuccessLine(
            label: 'Amount paid',
            value: AppFormatters.currency(payment.amount),
          ),
          _SuccessLine(label: 'Date', value: payment.date),
          _SuccessLine(label: 'Payment method', value: payment.method.label),
          _SuccessLine(label: 'Transaction ID', value: payment.transactionId),
          _SuccessLine(label: 'Invoice', value: payment.invoiceNumber),
          _SuccessLine(label: 'Unit', value: payment.unitLabel),
        ],
      ),
    );
  }
}

class _SuccessLine extends StatelessWidget {
  _SuccessLine({required this.label, required this.value});
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
            child: Text(
              label,
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }
}
