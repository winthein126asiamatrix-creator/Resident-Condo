import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_status_badge.dart';

class PaymentsPage extends GetView<PaymentController> {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: SafeArea(
        child: Obx(
          () => controller.isLoading.value && controller.invoices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : controller.errorMessage.value != null &&
                    controller.invoices.isEmpty
              ? AppStateMessage(
                  title: 'Unable to load payments',
                  message: controller.errorMessage.value!,
                  icon: Icons.payments_outlined,
                  actionLabel: 'Try again',
                  onAction: controller.loadPayments,
                )
              : RefreshIndicator(
                  onRefresh: controller.loadPayments,
                  child: ListView(
                    key: const Key('payments-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      _PaymentsHeader(onRefresh: controller.loadPayments),
                      const SizedBox(height: 20),
                      _BalanceSummary(controller: controller),
                      const SizedBox(height: 20),
                      _FeeBreakdown(controller: controller),
                      const SizedBox(height: 25),
                      _SectionHeader(
                        title: 'Invoices',
                        count: controller.invoices.length,
                      ),
                      const SizedBox(height: 10),
                      if (controller.invoices.isEmpty)
                        const AppStateMessage(
                          title: 'No invoices',
                          message: 'Your invoices will appear here.',
                          icon: Icons.receipt_long_outlined,
                        )
                      else
                        ...controller.invoices.map(
                          (invoice) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InvoiceCard(invoice: invoice),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'Payment history',
                        count: controller.paymentHistory.length,
                        actionLabel: 'View all',
                        onAction: () => Get.toNamed(AppRoutes.paymentHistory),
                      ),
                      const SizedBox(height: 10),
                      if (controller.paymentHistory.isEmpty)
                        const Text(
                          'No payment history yet.',
                          style: TextStyle(color: AppPalette.muted),
                        )
                      else
                        ...controller.paymentHistory
                            .take(2)
                            .map(
                              (payment) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PaymentPreview(payment: payment),
                              ),
                            ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payments', style: AppPalette.titleStyle),
              SizedBox(height: 4),
              Text(
                'Pay a single fee or several at once',
                style: AppPalette.subtitleStyle,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh payments',
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          onPressed: () => Get.toNamed(AppRoutes.paymentHistory),
          tooltip: 'Payment history',
          icon: const Icon(Icons.history_rounded),
        ),
      ],
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.controller});
  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    final outstanding = controller.outstandingBalance;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.brand,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppPalette.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Outstanding balance',
                  style: TextStyle(
                    color: AppPalette.brandOnDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.brandOnDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${controller.openInvoiceCount} open',
                  style: const TextStyle(
                    color: AppPalette.brand,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppFormatters.currency(outstanding),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Across all open invoices',
            style: TextStyle(color: AppPalette.brandOnDarkMuted, fontSize: 12),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Current month',
                  value: AppFormatters.currency(controller.currentMonthTotal),
                  detail: PaymentController.currentBillingPeriod,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Last payment',
                  value: AppFormatters.currency(controller.lastPaymentAmount),
                  detail: controller.lastPaymentDate,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Paid this year',
                  value: AppFormatters.currency(controller.totalPaidThisYear),
                  detail: '2026 total',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('payments-pay-now'),
              onPressed: outstanding <= 0
                  ? null
                  : () => _openOldestInvoice(context),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Pay Now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pay Now takes you to the item list. Nothing is charged until you '
            'confirm the items you selected.',
            style: TextStyle(
              color: AppPalette.brandOnDarkMuted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _openOldestInvoice(BuildContext context) {
    final invoice = controller.oldestOpenInvoice;
    if (invoice == null) {
      showAppFeedback(
        context,
        title: 'Nothing to pay',
        message: 'You have no open invoices.',
        isError: false,
      );
      return;
    }
    Get.toNamed(AppRoutes.paymentDetail, arguments: invoice);
  }
}

class _FeeBreakdown extends StatelessWidget {
  const _FeeBreakdown({required this.controller});
  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, double amount, Color color})>[
      (
        label: 'Monthly Rent',
        amount: controller.rentDueTotal,
        color: AppPalette.info,
      ),
      (
        label: 'Monthly Condo Fee',
        amount: controller.condoFeeDueTotal,
        color: AppPalette.brand,
      ),
      (
        label: 'Parking, utility, facility, service & fines',
        amount: controller.otherChargesDueTotal,
        color: AppPalette.warning,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Balance by fee type',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rent and the monthly condo fee are billed separately.',
            style: TextStyle(color: AppPalette.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: row.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: AppPalette.mutedStrong,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    AppFormatters.currency(row.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppPalette.brandOnDark, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppPalette.brandOnDark, fontSize: 9),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final int count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: AppPalette.ink),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppPalette.brandTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppPalette.brand,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final openItems = invoice.unpaidItems;
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.paymentDetail, arguments: invoice),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          children: [
            AppIconTile(
              icon: invoice.isFullyPaid
                  ? Icons.receipt_long_rounded
                  : Icons.receipt_long_outlined,
              color: invoice.isFullyPaid
                  ? AppPalette.success
                  : AppPalette.brand,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${invoice.billingPeriod} · ${invoice.number}',
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (openItems.isNotEmpty)
                    Text(
                      openItems.map((item) => item.type.shortLabel).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.mutedStrong,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.currency(invoice.amountDue),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.isFullyPaid ? 'Settled' : 'Due ${invoice.dueDate}',
                  style: const TextStyle(color: AppPalette.muted, fontSize: 10),
                ),
                const SizedBox(height: 5),
                PaymentStatusBadge(status: invoice.status),
              ],
            ),
            const Icon(Icons.chevron_right_rounded, color: AppPalette.faint),
          ],
        ),
      ),
    );
  }
}

class _PaymentPreview extends StatelessWidget {
  const _PaymentPreview({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          Icon(
            payment.isSuccessful
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            color: payment.isSuccessful
                ? AppPalette.success
                : AppPalette.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${payment.date} · ${payment.status.label}',
                  style: const TextStyle(color: AppPalette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            AppFormatters.currency(payment.amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: payment.isSuccessful
                  ? AppPalette.success
                  : AppPalette.danger,
            ),
          ),
        ],
      ),
    );
  }
}
