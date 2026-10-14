import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../app/routes/app_routes.dart';


import '../../../../core/theme/app_palette.dart';


import '../../../../core/theme/app_theme_tokens.dart';


import '../../../../core/widgets/app_detail_app_bar.dart';


import '../../../../core/utils/app_formatters.dart';


import '../../domain/entities/invoice.dart';


import '../../domain/entities/payment.dart';


import '../widgets/payment_record_badge.dart';


import '../../../../core/theme/app_spacing.dart';

class PaymentReceiptPage extends StatelessWidget {
  PaymentReceiptPage({required this.payment, super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isSuccess = payment.isSuccessful;
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(
        title: isSuccess ? 'Payment receipt' : 'Failed attempt',
      ),
      body: ListView(
        key: Key('payment-receipt-scroll'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PAYMENT RECEIPT',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: tokens.brand,
                        ),
                      ),
                    ),
                    PaymentRecordBadge(status: payment.status),
                  ],
                ),
                8.h.heightBox(),
                Text(
                  'Condo Residents',
                  style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                ),
                Divider(height: 30),
                _ReceiptLine(label: 'Resident', value: payment.residentName),
                _ReceiptLine(label: 'Unit', value: payment.unitLabel),
                _ReceiptLine(label: 'Invoice', value: payment.invoiceNumber),
                18.h.heightBox(),
                Text(
                  isSuccess ? 'Items paid' : 'Items attempted',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                8.h.heightBox(),
                for (final item in payment.items)
                  _ReceiptLine(
                    label: item.note.isEmpty
                        ? item.type.label
                        : item.type.label,
                    value: AppFormatters.currency(item.amount),
                    detail: item.note,
                  ),
                Divider(height: 24),
                _ReceiptLine(
                  label: isSuccess ? 'Total paid' : 'Total attempted',
                  value: AppFormatters.currency(payment.amount),
                  emphasize: true,
                ),
                16.h.heightBox(),
                _ReceiptLine(
                  label: 'Payment method',
                  value: payment.method.label,
                ),
                _ReceiptLine(label: 'Payment date', value: payment.date),
                _ReceiptLine(
                  label: 'Transaction ID',
                  value: payment.transactionId,
                ),
                if (payment.isFailed) ...[
                  12.h.heightBox(),
                  Text(
                    payment.failureReason ?? 'Payment was declined.',
                    style: TextStyle(
                      color: AppPalette.danger,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          20.h.heightBox(),
          OutlinedButton.icon(
            onPressed: () => Get.offAllNamed(AppRoutes.home),
            icon: Icon(Icons.check_rounded),
            label: Text('Done'),
            style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  _ReceiptLine({
    required this.label,
    required this.value,
    this.detail,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final String? detail;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: emphasize ? tokens.ink : tokens.muted,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  2.h.heightBox(),
                  Text(
                    detail!,
                    style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                  ),
                ],
              ],
            ),
          ),
          10.w.widthBox(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: emphasize ? tokens.brand : tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}
