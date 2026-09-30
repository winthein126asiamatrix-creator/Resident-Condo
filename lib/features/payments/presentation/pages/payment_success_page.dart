import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({required this.payment, super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Payment successful'),
      body: ListView(
        key: const Key('payment-success-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppPalette.brandTint,
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
          const Text(
            'Payment Successful',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Only the items you selected have been settled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.muted),
          ),
          const SizedBox(height: 24),
          _SuccessCard(payment: payment),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () =>
                Get.toNamed(AppRoutes.paymentReceipt, arguments: payment),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View Receipt'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Get.offAllNamed(AppRoutes.home),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAID ITEMS (${payment.items.length})',
            style: const TextStyle(
              color: AppPalette.brandOnDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in payment.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppPalette.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.type.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    AppFormatters.currency(item.amount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
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
  const _SuccessLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
