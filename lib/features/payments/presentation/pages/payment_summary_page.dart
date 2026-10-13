import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/payment_controller.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/theme/app_spacing.dart';

class PaymentSummaryPage extends GetView<PaymentController> {
  PaymentSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Payment summary',
        actions: [
          Obx(
            () => TextButton(
              onPressed: controller.selectedItems.isEmpty
                  ? null
                  : controller.clearSelection,
              child: Text('Clear'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final invoice = controller.selectedInvoice.value;
        final tokens = AppThemeTokens.of(context);
        if (invoice == null) {
          return AppStateMessage(
            title: 'No invoice selected',
            message: 'Choose an invoice before continuing.',
            icon: Icons.receipt_long_outlined,
            actionLabel: 'Back to payments',
            onAction: () => Get.offNamed(AppRoutes.home),
          );
        }
        return ListView(
          key: Key('payment-summary-scroll'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32,
          ),
          children: [
            _SummaryIntro(invoice: invoice),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select items',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
                  ),
                ),
                TextButton.icon(
                  key: Key('select-all-unpaid'),
                  onPressed: invoice.unpaidItems.isEmpty
                      ? null
                      : controller.selectAllUnpaidItems,
                  icon: Icon(Icons.done_all_rounded, size: 18),
                  label: Text('Select all unpaid'),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Pick one or several fees. Mandatory fees are always included '
              'and settled items are locked.',
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
            SizedBox(height: 10.h),
            for (final item in invoice.items)
              _SelectableItem(
                key: Key('invoice-item-${item.key}'),
                item: item,
                selected: controller.isItemSelected(item),
                onChanged: item.isPayable && !item.mustPaid
                    ? (_) => controller.toggleInvoiceItem(item)
                    : null,
              ),
            SizedBox(height: 18.h),
            _TotalCard(
              total: controller.selectedTotal,
              count: controller.selectedCount,
            ),
            if (controller.missingMandatoryItems.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _MandatoryWarning(message: controller.mandatoryValidationMessage),
            ],
            SizedBox(height: 20.h),
            FilledButton(
              key: Key('continue-to-payment'),
              onPressed: controller.canProceedToPayment
                  ? () {
                      if (!controller.canProceedToPayment) {
                        return;
                      }
                      Get.toNamed(AppRoutes.paymentMethod);
                    }
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(52),
              ),
              child: Text('Continue to Payment'),
            ),
          ],
        );
      }),
    );
  }
}

class _SummaryIntro extends StatelessWidget {
  _SummaryIntro({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.number,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                AppFormatters.currency(invoice.amountDue),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.danger,
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          Text(
            invoice.unitLabel,
            style: TextStyle(color: tokens.muted),
          ),
          SizedBox(height: 4.h),
          Text(
            'Due ${invoice.dueDate} Â· ${invoice.unpaidItems.length} unpaid items',
            style: TextStyle(color: tokens.muted, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _SelectableItem extends StatelessWidget {
  _SelectableItem({
    required this.item,
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final InvoiceItem item;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    final tokens = AppThemeTokens.of(context);
    final radius = BorderRadius.circular(16.r);
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: item.isPaid
            ? tokens.brandTint
            : locked
            ? tokens.surface
            : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? tokens.brand : tokens.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          value: item.isPaid
              ? false
              : item.isMandatory
              ? true
              : selected,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.symmetric(horizontal: 6),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.type.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: item.isPaid ? tokens.muted : tokens.ink,
                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (item.isMandatory) ...[
                _MandatoryBadge(),
                SizedBox(width: 8.w),
              ],
              Text(
                item.isZero ? 'No charge' : AppFormatters.currency(item.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: item.isPaid ? tokens.muted : tokens.ink,
                ),
              ),
            ],
          ),
          subtitle: Text(
            item.isPaid
                ? 'Paid${item.paidDate == null ? '' : ' on ${item.paidDate}'}'
                : item.isMandatory
                ? 'Mandatory fee Â· always included'
                : item.isZero
                ? 'Not charged this period'
                : item.note.isEmpty
                ? item.type.label
                : item.note,
            style: TextStyle(
              fontSize: 11.sp,
              color: item.isPaid
                  ? AppPalette.success
                  : item.isMandatory
                  ? tokens.brand
                  : tokens.muted,
              fontWeight: item.isPaid || item.isMandatory
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
          secondary: item.isPaid
              ? Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: AppPalette.success,
                )
              : item.isMandatory
              ? Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: tokens.brand,
                )
              : null,
        ),
      ),
    );
  }
}

class _MandatoryBadge extends StatelessWidget {
  _MandatoryBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      key: Key('mandatory-badge'),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.brandTint,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        'Mandatory',
        style: TextStyle(
          color: tokens.brand,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MandatoryWarning extends StatelessWidget {
  _MandatoryWarning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('mandatory-warning'),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppPalette.danger,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppPalette.danger,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  _TotalCard({required this.total, required this.count});
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.brand,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected total',
                  style: TextStyle(
                    color: tokens.brandOnDarkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count item${count == 1 ? '' : 's'}',
                style: TextStyle(
                  color: tokens.brandOnDark,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            AppFormatters.currency(total),
            style: TextStyle(
              color: tokens.surface,
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
