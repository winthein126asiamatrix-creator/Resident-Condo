import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_record_badge.dart';

class PaymentHistoryPage extends GetView<PaymentController> {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: Obx(() {
        if (controller.isLoading.value && controller.paymentHistory.isEmpty) {
          return const Center(child: CircularProgressIndicator());
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
          return const AppStateMessage(
            title: 'No payment history',
            message: 'Completed payments will appear here.',
            icon: Icons.history_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          itemCount: controller.paymentHistory.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) =>
              _HistoryCard(payment: controller.paymentHistory[index]),
        );
      }),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final color = payment.isSuccessful ? AppPalette.success : AppPalette.danger;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.date,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              PaymentRecordBadge(status: payment.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                AppFormatters.currency(payment.amount),
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            payment.items.map((item) => item.type.shortLabel).join(' · '),
            style: const TextStyle(color: AppPalette.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${payment.method.label} · ${payment.transactionId}',
            style: const TextStyle(color: AppPalette.faint, fontSize: 11),
          ),
          if (payment.isFailed) ...[
            const SizedBox(height: 8),
            Text(
              payment.failureReason ?? 'Payment was declined.',
              style: const TextStyle(
                color: AppPalette.danger,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
