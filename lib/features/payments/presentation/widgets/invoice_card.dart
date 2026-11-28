import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:test/core/utils/sized_box_extensions.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_list.dart';
import '../../domain/entities/payment_dashboard.dart';

/// Shared invoice card used by the payment dashboard and invoice list.
///
/// The card renders the same invoice identity, total, due date, date-based
/// progress, status and payment summary everywhere; pages only decide what
/// happens on tap.
class InvoiceCard extends StatelessWidget {
  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.currency,
    this.onTap,
    this.selectionControl,
    this.isSelected = false,
    this.enabled = true,
  });

  /// Builds the shared card from an invoice-list row.
  factory InvoiceCard.fromInvoiceListItem({
    Key? key,
    required InvoiceListItem invoice,
    VoidCallback? onTap,
    Widget? selectionControl,
    bool isSelected = false,
    bool enabled = true,
  }) {
    return InvoiceCard(
      key: key,
      invoice: invoice.toRecentInvoice(),
      currency: invoice.currency,
      onTap: onTap,
      selectionControl: selectionControl,
      isSelected: isSelected,
      enabled: enabled,
    );
  }

  final RecentInvoice invoice;
  final String currency;
  final VoidCallback? onTap;

  /// Optional caller-owned checkbox/selection indicator; kept outside card tap.
  final Widget? selectionControl;

  /// Whether a selection indicator should show the selected visual state.
  final bool isSelected;

  /// When false, card tap is disabled without changing the card layout.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final settled = invoice.invoiceStatus == InvoiceStatus.paid;
    final total = _money(invoice.totalAmount);
    final paid = _money(invoice.paidAmount);
    final remaining = _money(invoice.remainingAmount);
    //final dateProgress = invoice.dateProgress;
    final label = invoice.invoiceStatus.label;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected ? tokens.brand : tokens.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                AppIconTile(
                  icon: settled
                      ? Icons.receipt_long_rounded
                      : Icons.receipt_long_outlined,
                  color: tokens.brandTint,
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
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(total, style: TextStyle(fontWeight: FontWeight.w800)),
                    4.h.heightBox(),
                    Text(
                      invoice.dueDateLabel.isEmpty
                          ? ''
                          : invoice.isOverdue
                          ? 'Over Due ${invoice.dueDateLabel}'
                          : 'Due ${invoice.dueDateLabel}',
                      style: TextStyle(
                        color: invoice.isOverdue
                            ? AppPalette.danger
                            : tokens.muted,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
                if (selectionControl != null) ...[
                  10.w.widthBox(),
                  selectionControl!,
                ],
                Icon(Icons.chevron_right_rounded, color: tokens.faint),
              ],
            ),
            // if (dateProgress != null) ...[
            //   12.h.heightBox(),
            //   _InvoiceDateProgress(progress: dateProgress),
            //   12.h.heightBox(),
            // ] else
              16.h.heightBox(),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                10.w.widthBox(),
                Expanded(
                  child: Text(
                    invoice.invoiceStatus == InvoiceStatus.paid
                        ? 'Paid $paid'
                        : 'Paid $paid . $remaining Left',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: tokens.mutedStrong,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) => currency.trim().isEmpty
      ? AppFormatters.currency(value)
      : AppFormatters.money(value, currency);
}

/// The invoice's position between its issue date and due date.
///
/// This is deliberately separate from the payment completion percentage: a
/// fully paid invoice can still be early in its billing window.
class _InvoiceDateProgress extends StatelessWidget {
  const _InvoiceDateProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final value = progress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animated, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: animated,
            minHeight: 5.h,
            backgroundColor: tokens.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
          ),
        );
      },
    );
  }
}
