import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/invoice_list.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_status_badge.dart';

/// Picks the one invoice a Pay Now action should open.
///
/// Opened only when the resident has more than one payable invoice. The list
/// is intentionally not the first invoice page: the controller walks every page
/// so a payable invoice on a later page is never hidden from the resident.
class InvoiceSelectionPage extends StatefulWidget {
  const InvoiceSelectionPage({super.key});

  @override
  State<InvoiceSelectionPage> createState() => _InvoiceSelectionPageState();
}

class _InvoiceSelectionPageState extends State<InvoiceSelectionPage> {
  late final PaymentController controller = Get.find<PaymentController>();

  @override
  void initState() {
    super.initState();
    controller.loadPayableInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Select invoice',
        subtitle: 'Choose the invoice you want to pay',
        actions: [
          IconButton(
            key: const Key('invoice-selection-refresh'),
            onPressed: () => controller.loadPayableInvoices(refresh: true),
            tooltip: 'Refresh invoices',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        final items = controller.payableInvoices;
        final loading = controller.isLoadingPayableInvoices.value;
        final error = controller.payableInvoicesError.value;

        return RefreshIndicator(
          onRefresh: () => controller.loadPayableInvoices(refresh: true),
          child: ListView(
            key: const Key('invoice-selection-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.pageTop,
              AppSpacing.gutter,
              32,
            ),
            children: [
              if (controller.isShowingCachedPayableInvoices.value) ...[
                _CacheNotice(updatedAt: controller.payableInvoicesUpdatedLabel),
                10.h.heightBox(),
              ],
              if (loading && items.isEmpty)
                SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      key: const Key('invoice-selection-loading'),
                    ),
                  ),
                )
              else if (error != null && items.isEmpty)
                AppStateMessage(
                  title: 'Unable to load invoices',
                  message: error,
                  icon: Icons.receipt_long_outlined,
                  actionLabel: 'Try again',
                  onAction: () => controller.loadPayableInvoices(refresh: true),
                )
              else if (items.isEmpty)
                AppStateMessage(
                  title: 'No invoices to pay',
                  message: 'Every invoice is fully paid.',
                  icon: Icons.check_circle_outline,
                )
              else ...[
                _SelectionIntro(count: items.length),
                12.h.heightBox(),
                for (final invoice in items)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _PayableInvoiceCard(
                      invoice: invoice,
                      onTap: () {
                        vibrateNow();
                        Get.toNamed(
                          AppRoutes.paymentDetail,
                          arguments: invoice.id,
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _SelectionIntro extends StatelessWidget {
  const _SelectionIntro({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count == 1
              ? '1 invoice awaiting payment'
              : '$count invoices awaiting payment',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
        ),
        3.h.heightBox(),
        Text(
          'Select one invoice to continue. Nothing is charged until you '
          'confirm the items.',
          style: TextStyle(color: tokens.muted, fontSize: 12.sp, height: 1.35),
        ),
      ],
    );
  }
}

class _PayableInvoiceCard extends StatelessWidget {
  const _PayableInvoiceCard({required this.invoice, required this.onTap});

  final InvoiceListItem invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final overdue = invoice.isOverdue;
    final accent = overdue ? AppPalette.danger : tokens.brand;

    return InkWell(
      key: Key('payable-invoice-${invoice.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: overdue
                ? AppPalette.danger.withValues(alpha: 0.45)
                : tokens.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconTile(icon: Icons.receipt_long_rounded, color: accent),
                12.w.widthBox(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (invoice.billingPeriodLabel.isNotEmpty) ...[
                        3.h.heightBox(),
                        Text(
                          invoice.billingPeriodLabel,
                          style: TextStyle(
                            color: tokens.muted,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                10.w.widthBox(),
                PaymentStatusBadges(
                  status: invoice.invoiceStatus,
                //  overdue: overdue,
                ),
              ],
            ),
            12.h.heightBox(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _Amount(
                    label: 'Total',
                    value: _money(invoice.totalAmount, invoice.currency),
                    muted: true,
                  ),
                ),
                Expanded(
                  child: _Amount(
                    label: 'Paid',
                    value: _money(invoice.paidAmount, invoice.currency),
                    muted: true,
                  ),
                ),
                Expanded(
                  child: _Amount(
                    label: 'Remaining',
                    value: _money(invoice.remainingAmount, invoice.currency),
                    muted: false,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            if (invoice.dueDateLabel.isNotEmpty) ...[
              10.h.heightBox(),
              Row(
                children: [
                  Icon(
                    overdue
                        ? Icons.error_outline_rounded
                        : Icons.event_outlined,
                    size: 14,
                    color: overdue ? AppPalette.danger : tokens.muted,
                  ),
                  6.w.widthBox(),
                  Expanded(
                    child: Text(
                      overdue
                          ? 'Overdue · Due ${invoice.dueDateLabel}'
                          : 'Due ${invoice.dueDateLabel}',
                      style: TextStyle(
                        color: overdue ? AppPalette.danger : tokens.muted,
                        fontSize: 11.sp,
                        fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tokens.faint),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _money(double value, String currency) => currency.trim().isEmpty
      ? AppFormatters.currency(value)
      : AppFormatters.money(value, currency);
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    required this.muted,
    this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool muted;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: tokens.muted, fontSize: 10.sp),
        ),
        2.h.heightBox(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: muted ? tokens.mutedStrong : color,
            fontWeight: muted ? FontWeight.w600 : FontWeight.w800,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }
}

class _CacheNotice extends StatelessWidget {
  const _CacheNotice({required this.updatedAt});

  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      key: const Key('invoice-selection-cache'),
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
                  ? 'Showing saved invoices'
                  : 'Showing saved invoices · Updated $updatedAt',
              style: TextStyle(color: tokens.muted, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }
}
