import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_status_badge.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

class InvoiceDetailPage extends GetView<PaymentController> {
  const InvoiceDetailPage({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentInvoice = _currentInvoice();
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Invoice details'),
        body: _buildBody(context, currentInvoice),
      );
    });
  }

  Widget _buildBody(BuildContext context, Invoice currentInvoice) {
    final tokens = AppThemeTokens.of(context);
    return ListView(
      key: const Key('invoice-detail-scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.pageTop,
        AppSpacing.gutter,
        32,
      ),
      children: [
        _InvoiceHero(invoice: currentInvoice),
        const SizedBox(height: 20),
        AppSectionCard(
          title: 'Invoice information',
          child: Column(
            children: [
              AppLabelValueRow(
                label: 'Invoice number',
                value: currentInvoice.number,
              ),
              AppLabelValueRow(
                label: 'Billing period',
                value: currentInvoice.billingPeriod,
              ),
              AppLabelValueRow(label: 'Unit', value: currentInvoice.unitLabel),
              AppLabelValueRow(
                label: 'Due date',
                value: currentInvoice.dueDate,
              ),
              AppLabelValueRow(
                label: 'Status',
                valueWidget: PaymentStatusBadge(status: currentInvoice.status),
              ),
              if (currentInvoice.amountPaid > 0)
                AppLabelValueRow(
                  label: 'Already paid',
                  value: AppFormatters.currency(currentInvoice.amountPaid),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Breakdown',
          subtitle: 'Every charge is billed and paid separately.',
          child: Column(
            children: [
              for (final item in currentInvoice.items) _ItemLine(item: item),
              const Divider(height: 20),
              AppLabelValueRow(
                label: 'Invoice total',
                value: AppFormatters.currency(currentInvoice.total),
              ),
              AppLabelValueRow(
                label: 'Amount due',
                value: AppFormatters.currency(currentInvoice.amountDue),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (currentInvoice.isPayable)
          FilledButton.icon(
            key: const Key('invoice-pay-selected'),
            onPressed: () {
              controller.selectInvoice(currentInvoice);
              Get.toNamed(AppRoutes.paymentSummary);
            },
            icon: const Icon(Icons.lock_outline_rounded, size: 18),
            label: const Text('Choose items to pay'),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.brand,
              foregroundColor: tokens.onBrand,
              minimumSize: const Size.fromHeight(52),
            ),
          )
        else
          _PaidCard(
            invoice: currentInvoice,
            payment: _paymentFor(currentInvoice),
          ),
        if (currentInvoice.isPayable) ...[
          const SizedBox(height: 8),
          Text(
            'Pay Now never charges the full balance automatically — you pick '
            'exactly which fees to settle.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Invoice _currentInvoice() {
    return controller.invoices.firstWhere(
      (item) => item.id == invoice.id,
      orElse: () => invoice,
    );
  }

  Payment? _paymentFor(Invoice currentInvoice) {
    for (final payment in controller.paymentHistory) {
      if (payment.invoiceNumber == currentInvoice.number &&
          payment.isSuccessful) {
        return payment;
      }
    }
    return null;
  }
}

class _InvoiceHero extends StatelessWidget {
  const _InvoiceHero({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(22),
        boxShadow: tokens.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AMOUNT DUE',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              PaymentStatusBadge(status: invoice.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            AppFormatters.currency(invoice.amountDue),
            style: TextStyle(
              color: tokens.onBrand,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${invoice.number} · ${invoice.billingPeriod}',
            style: TextStyle(
              color: tokens.brandOnDarkMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});
  final InvoiceItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isPaid
                ? Icons.check_circle_rounded
                : item.isZero
                ? Icons.remove_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: item.isPaid
                ? AppPalette.success
                : item.isZero
                ? tokens.faint
                : AppPalette.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: item.isPaid ? tokens.muted : tokens.ink,
                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.isPaid && item.paidDate != null
                        ? '${item.note} · paid ${item.paidDate}'
                        : item.note,
                    style: TextStyle(color: tokens.muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            item.isZero ? 'No charge' : AppFormatters.currency(item.amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: item.isPaid ? tokens.muted : tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidCard extends StatelessWidget {
  const _PaidCard({required this.invoice, required this.payment});
  final Invoice invoice;
  final Payment? payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: tokens.brandTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tokens.brandSoft,
            child: const Icon(Icons.check_rounded, color: AppPalette.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paid in full',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppPalette.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.paidDate == null
                      ? 'Payment complete'
                      : 'Paid on ${invoice.paidDate}',
                  style: TextStyle(
                    color: tokens.mutedStrong,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (payment != null)
            Text(
              payment!.transactionId,
              style: const TextStyle(
                color: AppPalette.success,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
