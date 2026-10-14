import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';


import '../../../../core/theme/app_palette.dart';


import '../../../../core/theme/app_theme_tokens.dart';


import '../../../../core/utils/app_formatters.dart';


import '../../../../core/widgets/app_state_message.dart';


import '../../domain/entities/invoice.dart';


import '../../domain/entities/payment.dart';


import '../controllers/payment_controller.dart';


import '../widgets/payment_record_badge.dart';


import '../../../../core/widgets/app_detail_app_bar.dart';

class PaymentHistoryPage extends GetView<PaymentController> {
  PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Payment history'),
      body: Obx(() {
        if (controller.isLoading.value && controller.paymentHistory.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.paymentHistory.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load history',
            message: controller.errorMessage.value!,
            icon: Icons.history_rounded,
            actionLabel: 'Try again',
            onAction: controller.loadPayments,
          );
        }
        if (controller.paymentHistory.isEmpty) {
          return AppStateMessage(
            title: 'No payment history',
            message: 'Completed payments will appear here.',
            icon: Icons.history_rounded,
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 32),
          itemCount: controller.paymentHistory.length,
          separatorBuilder: (_, _) => 10.h.heightBox(),
          itemBuilder: (_, index) =>
              _HistoryCard(payment: controller.paymentHistory[index]),
        );
      }),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  _HistoryCard({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = payment.isSuccessful ? AppPalette.success : AppPalette.danger;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.date,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              PaymentRecordBadge(status: payment.status),
            ],
          ),
          12.h.heightBox(),
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.invoiceNumber,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                AppFormatters.currency(payment.amount),
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          6.h.heightBox(),
          Text(
            payment.items.map((item) => item.type.shortLabel).join(' Â· '),
            style: TextStyle(color: tokens.muted, fontSize: 12.sp),
          ),
          4.h.heightBox(),
          Text(
            '${payment.method.label} Â· ${payment.transactionId}',
            style: TextStyle(color: tokens.faint, fontSize: 11.sp),
          ),
          if (payment.isFailed) ...[
            8.h.heightBox(),
            Text(
              payment.failureReason ?? 'Payment was declined.',
              style: TextStyle(
                color: AppPalette.danger,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
