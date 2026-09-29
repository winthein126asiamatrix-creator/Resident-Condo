import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/payment_controller.dart';

class PaymentSummaryPage extends GetView<PaymentController> {
  const PaymentSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment summary'),
        actions: [
          Obx(
            () => TextButton(
              onPressed: controller.selectedItems.isEmpty
                  ? null
                  : controller.clearSelection,
              child: const Text('Clear'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final invoice = controller.selectedInvoice.value;
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
          key: const Key('payment-summary-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _SummaryIntro(invoice: invoice),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select items',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  key: const Key('select-all-unpaid'),
                  onPressed: invoice.unpaidItems.isEmpty
                      ? null
                      : controller.selectAllUnpaidItems,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Select all unpaid'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick one or several fees. Mandatory fees are always included '
              'and settled items are locked.',
              style: TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (final item in invoice.items)
              _SelectableItem(
                key: Key('invoice-item-${item.key}'),
                item: item,
                selected: controller.isItemSelected(item),
                onChanged: item.isPayable && !item.mustPaid
                    ? (_) => controller.toggleInvoiceItem(item)
                    : null,
              ),
            const SizedBox(height: 18),
            _TotalCard(
              total: controller.selectedTotal,
              count: controller.selectedCount,
            ),
            if (controller.missingMandatoryItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MandatoryWarning(
                message: controller.mandatoryValidationMessage,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('continue-to-payment'),
              onPressed: controller.canProceedToPayment
                  ? () {
                      if (!controller.canProceedToPayment) {
                        return;
                      }
                      Get.toNamed(AppRoutes.paymentMethod);
                    }
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Continue to Payment'),
            ),
          ],
        );
      }),
    );
  }
}

class _SummaryIntro extends StatelessWidget {
  const _SummaryIntro({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.number,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                AppFormatters.currency(invoice.amountDue),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(invoice.unitLabel, style: const TextStyle(color: AppPalette.muted)),
          const SizedBox(height: 4),
          Text(
            'Due ${invoice.dueDate} · ${invoice.unpaidItems.length} unpaid items',
            style: const TextStyle(color: AppPalette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SelectableItem extends StatelessWidget {
  const _SelectableItem({
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
    final radius = BorderRadius.circular(16);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: item.isPaid
            ? AppPalette.brandTint
            : locked
            ? AppPalette.surface
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppPalette.brand : AppPalette.border,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.type.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: item.isPaid ? AppPalette.muted : AppPalette.ink,
                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (item.isMandatory) ...[
                const _MandatoryBadge(),
                const SizedBox(width: 8),
              ],
              Text(
                item.isZero
                    ? 'No charge'
                    : AppFormatters.currency(item.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: item.isPaid ? AppPalette.muted : AppPalette.ink,
                ),
              ),
            ],
          ),
          subtitle: Text(
            item.isPaid
                ? 'Paid${item.paidDate == null ? '' : ' on ${item.paidDate}'}'
                : item.isMandatory
                ? 'Mandatory fee · always included'
                : item.isZero
                ? 'Not charged this period'
                : item.note.isEmpty
                ? item.type.label
                : item.note,
            style: TextStyle(
              fontSize: 11,
              color: item.isPaid
                  ? AppPalette.success
                  : item.isMandatory
                  ? AppPalette.brand
                  : AppPalette.muted,
              fontWeight: item.isPaid || item.isMandatory
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
          secondary: item.isPaid
              ? const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: AppPalette.success,
                )
              : item.isMandatory
              ? const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: AppPalette.brand,
                )
              : null,
        ),
      ),
    );
  }
}

class _MandatoryBadge extends StatelessWidget {
  const _MandatoryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mandatory-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.brandTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Mandatory',
        style: TextStyle(
          color: AppPalette.brand,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MandatoryWarning extends StatelessWidget {
  const _MandatoryWarning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mandatory-warning'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppPalette.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppPalette.danger,
                fontSize: 12,
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
  const _TotalCard({required this.total, required this.count});
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Selected total',
                  style: TextStyle(
                    color: AppPalette.brandOnDarkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count item${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppPalette.brandOnDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppFormatters.currency(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
