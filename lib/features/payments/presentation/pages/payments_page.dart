import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_text_styles.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/app_formatters.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../../../core/widgets/app_status_pill.dart';

import '../../domain/entities/invoice.dart';

import '../../domain/entities/payment.dart';

import '../../domain/entities/payment_dashboard.dart';

import '../controllers/payment_controller.dart';

import '../widgets/payment_record_badge.dart';

import '../widgets/payment_status_badge.dart';

class PaymentsPage extends GetView<PaymentController> {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          final hasDashboard = controller.dashboard.value != null;
          if (controller.isLoading.value && !hasDashboard) {
            return Center(child: CircularProgressIndicator());
          }
          if (controller.errorMessage.value != null && !hasDashboard) {
            return AppStateMessage(
              title: 'Unable to load payments',
              message: controller.errorMessage.value!,
              icon: Icons.payments_outlined,
              actionLabel: 'Try again',
              onAction: controller.loadPayments,
            );
          }
          final summary = controller.invoiceSummary;
          final invoiceCount = hasDashboard
              ? summary?.total ?? controller.recentInvoices.length
              : controller.invoices.length;
          final paymentCount = hasDashboard
              ? controller.recentPayments.length
              : controller.paymentHistory.length;
          final hasInvoices = hasDashboard
              ? controller.recentInvoices.isNotEmpty
              : controller.invoices.isNotEmpty;
          final hasPayments = hasDashboard
              ? controller.recentPayments.isNotEmpty
              : controller.paymentHistory.isNotEmpty;
          return RefreshIndicator(
            onRefresh: controller.loadPayments,
            child: ListView(
              key: Key('payments-scroll'),
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                _PaymentsHeader(onRefresh: controller.loadPayments),
                if (controller.isShowingCachedData.value) ...[
                  10.h.heightBox(),
                  _CachedDataNotice(updatedAt: controller.lastUpdatedLabel),
                ],
                20.h.heightBox(),
                _BalanceSummary(controller: controller),
                20.h.heightBox(),
                _FeeBreakdown(controller: controller),
                if (summary != null) ...[
                  20.h.heightBox(),
                  _InvoiceSummaryCard(summary: summary),
                ],
                25.h.heightBox(),
                _SectionHeader(
                  title: 'Invoices',
                  count: invoiceCount,
                  actionLabel: 'View all',
                  onAction: () => Get.toNamed(AppRoutes.invoiceList),
                ),
                10.h.heightBox(),
                if (!hasInvoices)
                  AppStateMessage(
                    title: 'No invoices',
                    message: 'Your invoices will appear here.',
                    icon: Icons.receipt_long_outlined,
                  )
                else if (hasDashboard)
                  ...controller.recentInvoices.map(
                    (invoice) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _RecentInvoiceCard(
                        invoice: invoice,
                        currency: controller.dashboardCurrency,
                        onTap: () => _openRecentInvoice(context, invoice),
                      ),
                    ),
                  )
                else
                  ...controller.invoices.map(
                    (invoice) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _InvoiceCard(invoice: invoice),
                    ),
                  ),
                16.h.heightBox(),
                _SectionHeader(
                  title: 'Payment history',
                  count: paymentCount,
                  actionLabel: 'View all',
                  onAction: () => Get.toNamed(AppRoutes.paymentHistory),
                ),
                10.h.heightBox(),
                if (!hasPayments)
                  Text(
                    'No payment history yet.',
                    style: TextStyle(color: tokens.muted),
                  )
                else if (hasDashboard)
                  ...controller.recentPayments
                      .take(2)
                      .map(
                        (payment) => Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: _RecentPaymentCard(payment: payment),
                        ),
                      )
                else
                  ...controller.paymentHistory
                      .take(2)
                      .map(
                        (payment) => Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: _PaymentPreview(payment: payment),
                        ),
                      ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _openRecentInvoice(BuildContext context, RecentInvoice invoice) {
    final local = controller.invoiceByNumber(invoice.invoiceNumber);
    if (local == null) {
      showAppFeedback(
        context,
        title: 'Invoice not available',
        message: 'Open the invoice list to view this invoice.',
        isError: false,
      );
      return;
    }
    Get.toNamed(AppRoutes.paymentDetail, arguments: local);
  }
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payments', style: AppTextStyles.of(context).screenTitle),
              4.h.heightBox(),
              Text(
                'Pay a single fee or several at once',
                style: TextStyle(color: tokens.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh payments',
          icon: Icon(Icons.refresh_rounded),
        ),
        IconButton(
          onPressed: () => Get.toNamed(AppRoutes.paymentHistory),
          tooltip: 'Payment history',
          icon: Icon(Icons.history_rounded),
        ),
      ],
    );
  }
}

class _CachedDataNotice extends StatelessWidget {
  const _CachedDataNotice({required this.updatedAt});
  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 15, color: tokens.muted),
          8.w.widthBox(),
          Expanded(
            child: Text(
              updatedAt.isEmpty
                  ? 'Showing saved data'
                  : 'Showing saved data · Updated $updatedAt',
              style: TextStyle(color: tokens.muted, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.controller});
  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final dashboard = controller.dashboard.value;
    final outstanding = controller.outstandingBalanceAmount;
    final currency = dashboard?.outstandingBalance.currency ?? '';
    final statistics = controller.paymentStatistics;
    final summary = controller.invoiceSummary;
    final openCount = summary?.open ?? controller.openInvoiceCount;

    String money(double value) => dashboard == null
        ? AppFormatters.currency(value)
        : AppFormatters.money(value, currency);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: tokens.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Outstanding balance',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.brandOnDark,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '$openCount open',
                  style: TextStyle(
                    color: tokens.brand,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          8.h.heightBox(),
          Text(
            money(outstanding),
            style: TextStyle(
              color: tokens.onBrand,
              fontSize: 31.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          4.h.heightBox(),
          Text(
            'Across all open invoices',
            style: TextStyle(color: tokens.brandOnDarkMuted, fontSize: 12.sp),
          ),
          19.h.heightBox(),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Current month',
                  value: money(
                    statistics?.currentMonthDue ?? controller.currentMonthTotal,
                  ),
                  detail: 'This month',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Last payment',
                  value: money(
                    statistics?.lastPayment ?? controller.lastPaymentAmount,
                  ),
                  detail: dashboard == null
                      ? controller.lastPaymentDate
                      : (controller.lastDashboardPaymentDate.isEmpty
                            ? 'Most recent'
                            : controller.lastDashboardPaymentDate),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Paid this year',
                  value: money(
                    statistics?.paidThisYear ?? controller.totalPaidThisYear,
                  ),
                  detail: '${DateTime.now().year} total',
                ),
              ),
            ],
          ),
          18.h.heightBox(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: Key('payments-pay-now'),
              onPressed: outstanding <= 0
                  ? null
                  : () {
                      vibrateNow();
                      _openOldestInvoice(context);
                    },
              icon: Icon(
                Icons.arrow_forward_rounded,
                size: 18.sp,
                color: tokens.brandOnDark,
              ),
              label: Text(
                'Pay Now',
                style: TextStyle(color: tokens.brandOnDark),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: tokens.brand,
                minimumSize: Size.fromHeight(48),
              ),
            ),
          ),
          8.h.heightBox(),
          Text(
            'Pay Now takes you to the item list. Nothing is charged until you '
            'confirm the items you selected.',
            style: TextStyle(
              color: tokens.brandOnDarkMuted,
              fontSize: 10.sp,
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
    final tokens = AppThemeTokens.of(context);
    final dashboard = controller.dashboard.value;
    final currency = dashboard?.outstandingBalance.currency ?? '';
    final rent = controller.feeSummaryFor(PaymentFeeType.monthlyRent);
    final condoFee = controller.feeSummaryFor(PaymentFeeType.monthlyCondoFee);
    final otherFees = controller.feeSummaryFor(PaymentFeeType.otherFees);

    String labelFor(FeeSummary? fee, String fallback) =>
        fee != null && fee.label.trim().isNotEmpty ? fee.label : fallback;
    String money(double value) => dashboard == null
        ? AppFormatters.currency(value)
        : AppFormatters.money(value, currency);

    // A fee type the API omits is zero, never a local mock amount.
    double amountFor(FeeSummary? fee, double fallback) =>
        fee?.amount ?? (dashboard == null ? fallback : 0);

    final rows = <({String label, double amount, Color color})>[
      (
        label: labelFor(rent, 'Monthly Rent'),
        amount: amountFor(rent, controller.rentDueTotal),
        color: AppPalette.info,
      ),
      (
        label: labelFor(condoFee, 'Monthly Condo Fee'),
        amount: amountFor(condoFee, controller.condoFeeDueTotal),
        color: tokens.brand,
      ),
      (
        label: labelFor(
          otherFees,
          'Parking, utility, facility, service & fines',
        ),
        amount: amountFor(otherFees, controller.otherChargesDueTotal),
        color: AppPalette.warning,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance by fee type',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
          ),
          4.h.heightBox(),
          Text(
            'Rent and the monthly condo fee are billed separately.',
            style: TextStyle(color: tokens.muted, fontSize: 11.sp),
          ),
          12.h.heightBox(),
          for (final row in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: row.color,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  10.w.widthBox(),
                  Expanded(
                    child: Text(
                      row.label,
                      style: TextStyle(
                        color: tokens.mutedStrong,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  Text(
                    money(row.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.sp,
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

class _InvoiceSummaryCard extends StatelessWidget {
  const _InvoiceSummaryCard({required this.summary});
  final InvoiceSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice summary',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
          ),
          12.h.heightBox(),
          Row(
            children: [
              Expanded(
                child: _InvoiceCount(
                  label: 'Total',
                  value: summary.total,
                  color: tokens.ink,
                ),
              ),
              Expanded(
                child: _InvoiceCount(
                  label: 'Unpaid',
                  value: summary.unpaid,
                  color: AppPalette.warning,
                ),
              ),
              Expanded(
                child: _InvoiceCount(
                  label: 'Partial',
                  value: summary.partial,
                  color: AppPalette.info,
                ),
              ),
              Expanded(
                child: _InvoiceCount(
                  label: 'Paid',
                  value: summary.paid,
                  color: AppPalette.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceCount extends StatelessWidget {
  const _InvoiceCount({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
          ),
        ),
        2.h.heightBox(),
        Text(
          label,
          style: TextStyle(color: tokens.muted, fontSize: 11.sp),
        ),
      ],
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
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: tokens.brandOnDark, fontSize: 10.sp),
        ),
        4.h.heightBox(),
        Text(
          value,
          style: TextStyle(
            color: tokens.onBrand,
            fontWeight: FontWeight.w800,
            fontSize: 14.sp,
          ),
        ),
        2.h.heightBox(),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.brandOnDark, fontSize: 9.sp),
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
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: tokens.ink),
        ),
        7.w.widthBox(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.brandTint,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: tokens.brand,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Spacer(),
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
    final tokens = AppThemeTokens.of(context);
    final openItems = invoice.unpaidItems;
    return InkWell(
      onTap: () {
        vibrateNow();
        Get.toNamed(AppRoutes.paymentDetail, arguments: invoice);
      },
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            AppIconTile(
              icon: invoice.isFullyPaid
                  ? Icons.receipt_long_rounded
                  : Icons.receipt_long_outlined,
              color: invoice.isFullyPaid ? AppPalette.success : tokens.brand,
            ),
            12.w.widthBox(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.title,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  4.h.heightBox(),
                  Text(
                    '${invoice.billingPeriod} Â· ${invoice.number}',
                    style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                  ),
                  6.h.heightBox(),
                  if (openItems.isNotEmpty)
                    Text(
                      openItems
                          .map((item) => item.type.shortLabel)
                          .join(' Â· '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.mutedStrong,
                        fontSize: 11.sp,
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
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                4.h.heightBox(),
                Text(
                  invoice.isFullyPaid ? 'Settled' : 'Due ${invoice.dueDate}',
                  style: TextStyle(color: tokens.muted, fontSize: 10.sp),
                ),
                5.h.heightBox(),
                PaymentStatusBadge(status: invoice.status),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.faint),
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
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: tokens.border),
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
          10.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.invoiceNumber,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                3.h.heightBox(),
                Text(
                  '${payment.date} Â· ${payment.status.label}',
                  style: TextStyle(color: tokens.muted, fontSize: 12.sp),
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

class _RecentInvoiceCard extends StatelessWidget {
  const _RecentInvoiceCard({
    required this.invoice,
    required this.currency,
    required this.onTap,
  });
  final RecentInvoice invoice;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final settled = invoice.invoiceStatus == InvoiceStatus.paid;
    final total = _money(invoice.totalAmount);
    final paid = _money(invoice.paidAmount);
    final remaining = _money(invoice.remainingAmount);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            AppIconTile(
              icon: settled
                  ? Icons.receipt_long_rounded
                  : Icons.receipt_long_outlined,
              color: settled ? AppPalette.success : tokens.brand,
            ),
            12.w.widthBox(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  4.h.heightBox(),
                  Text(
                    invoice.billingPeriodLabel,
                    style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                  ),
                  6.h.heightBox(),
                  Text(
                    'Total $total · Paid $paid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.mutedStrong,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(remaining, style: TextStyle(fontWeight: FontWeight.w800)),
                4.h.heightBox(),
                Text(
                  invoice.dueDateLabel.isEmpty
                      ? ''
                      : 'Due ${invoice.dueDateLabel}',
                  style: TextStyle(color: tokens.muted, fontSize: 10.sp),
                ),
                5.h.heightBox(),
                PaymentStatusBadge(status: invoice.invoiceStatus),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.faint),
          ],
        ),
      ),
    );
  }

  String _money(double value) => currency.trim().isEmpty
      ? AppFormatters.currency(value)
      : AppFormatters.money(value, currency);
}

class _RecentPaymentCard extends StatelessWidget {
  const _RecentPaymentCard({required this.payment});
  final RecentPayment payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final status = payment.paymentStatus;
    final failed = status == PaymentStatus.failed;
    final color = failed ? AppPalette.danger : AppPalette.success;
    final amount = payment.currency.trim().isEmpty
        ? AppFormatters.currency(payment.amount)
        : AppFormatters.money(payment.amount, payment.currency);
    final subtitle = payment.paidAtLabel.isEmpty
        ? payment.statusLabel
        : '${payment.paidAtLabel} · ${payment.statusLabel}';
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(
            failed ? Icons.error_rounded : Icons.check_circle_rounded,
            color: color,
          ),
          10.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentNumber,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                3.h.heightBox(),
                Text(
                  subtitle,
                  style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              4.h.heightBox(),
              if (status != null)
                PaymentRecordBadge(status: status)
              else
                _StatusPill(label: payment.statusLabel, color: tokens.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
