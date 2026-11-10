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
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_detail.dart';
import '../../domain/entities/payment.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_status_badge.dart';

/// Invoice detail for either an API-loaded invoice or a legacy ledger invoice.
///
/// The invoice list only passes an id, so the page loads
/// `GET /api/v1/payments/invoices/{id}` and never builds a detail screen from a
/// cached list row. The payment dashboard's existing flows still hand over a
/// fully loaded [Invoice], which keeps that behaviour unchanged.
class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({this.invoice, this.invoiceId, super.key})
    : assert(invoice == null || invoiceId == null);

  final Invoice? invoice;
  final int? invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late final PaymentController controller = Get.find<PaymentController>();

  @override
  void initState() {
    super.initState();
    final id = widget.invoiceId;
    if (id != null && id > 0) {
      controller.loadInvoiceDetail(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.invoiceId != null) {
        return _buildApi(context);
      }
      return _buildLegacy(context);
    });
  }

  Widget _buildApi(BuildContext context) {
    final id = widget.invoiceId;
    final detail = controller.invoiceDetail.value;
    final loading = controller.isLoadingInvoiceDetail.value;
    final error = controller.invoiceDetailError.value;

    if (detail == null || (id != null && detail.id != 0 && detail.id != id)) {
      return Scaffold(
        appBar: AppDetailAppBar(
          title: 'Invoice details',
          actions: [
            IconButton(
              onPressed: id == null
                  ? null
                  : () => controller.loadInvoiceDetail(id),
              tooltip: 'Refresh invoice',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : AppStateMessage(
                title: 'Unable to load invoice',
                message: error ?? 'This invoice is not available right now.',
                icon: Icons.receipt_long_outlined,
                actionLabel: 'Try again',
                onAction: id == null
                    ? null
                    : () => controller.loadInvoiceDetail(id),
              ),
      );
    }

    return _DetailScaffold(
      view: _InvoiceView.fromApi(detail),
      payment: _paymentFor(detail.invoiceNumber),
      controller: controller,
    );
  }

  Widget _buildLegacy(BuildContext context) {
    final invoice = widget.invoice;
    if (invoice == null) {
      return Scaffold(
        appBar: AppDetailAppBar(title: 'Invoice details'),
        body: AppStateMessage(
          title: 'Invoice not available',
          message: 'Choose an invoice from the list.',
          icon: Icons.receipt_long_outlined,
          actionLabel: 'Back',
          onAction: Get.back,
        ),
      );
    }
    final current = controller.invoices.firstWhere(
      (item) => item.id == invoice.id,
      orElse: () => invoice,
    );
    return _DetailScaffold(
      view: _InvoiceView.fromLegacy(current),
      payment: _paymentFor(current.number),
      controller: controller,
    );
  }

  Payment? _paymentFor(String invoiceNumber) {
    for (final payment in controller.paymentHistory) {
      if (payment.invoiceNumber == invoiceNumber && payment.isSuccessful) {
        return payment;
      }
    }
    return null;
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.view,
    required this.payment,
    required this.controller,
  });

  final _InvoiceView view;
  final Payment? payment;
  final PaymentController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Invoice details'),
      body: ListView(
        key: const Key('invoice-detail-scroll'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          _InvoiceHero(view: view),
          20.h.heightBox(),
          AppSectionCard(
            title: 'Invoice information',
            child: Column(
              children: [
                AppLabelValueRow(
                  label: 'Invoice number',
                  value: view.invoiceNumber,
                ),
                AppLabelValueRow(
                  label: 'Billing period',
                  value: view.billingPeriod,
                ),
                if (view.unitLabel.isNotEmpty)
                  AppLabelValueRow(label: 'Unit', value: view.unitLabel),
                if (view.invoiceDateLabel.isNotEmpty)
                  AppLabelValueRow(
                    label: 'Invoice date',
                    value: view.invoiceDateLabel,
                  ),
                if (view.dueDateLabel.isNotEmpty)
                  AppLabelValueRow(label: 'Due date', value: view.dueDateLabel),
                AppLabelValueRow(
                  label: 'Status',
                  valueWidget: PaymentStatusBadge(status: view.status),
                ),
              ],
            ),
          ),
          16.h.heightBox(),
          AppSectionCard(
            title: 'Breakdown',
            subtitle: 'Every charge is billed and paid separately.',
            child: Column(
              children: [
                for (final item in view.items)
                  _ItemLine(item: item, currency: view.currency),
                Divider(height: 20),
                AppLabelValueRow(
                  label: 'Invoice total',
                  value: view.money(view.totalAmount),
                ),
                AppLabelValueRow(
                  label: 'Amount paid',
                  value: view.money(view.paidAmount),
                ),
                AppLabelValueRow(
                  label: 'Remaining',
                  value: view.money(view.remainingAmount),
                  emphasize: true,
                ),
              ],
            ),
          ),
          18.h.heightBox(),
          if (view.payableInvoice != null)
            FilledButton.icon(
              key: const Key('invoice-pay-selected'),
              onPressed: () {
                vibrateNow();
                controller.selectInvoice(view.payableInvoice!);
                Get.toNamed(AppRoutes.paymentSummary);
              },
              icon: Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text('Choose items to pay'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.brand,
                foregroundColor: tokens.onBrand,
                minimumSize: const Size.fromHeight(52),
              ),
            )
          else
            _PaidCard(view: view, payment: payment),
          if (view.payableInvoice != null) ...[
            8.h.heightBox(),
            Text(
              'Pay Now never charges the full balance automatically — you pick '
              'exactly which fees to settle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.muted,
                fontSize: 11.sp,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The fields the detail screen renders, independent of where they came from.
///
/// [payableInvoice] is the entity the existing payment selection flow expects;
/// it is null for an invoice that has nothing left to pay.
class _InvoiceView {
  const _InvoiceView({
    required this.invoiceNumber,
    required this.billingPeriod,
    required this.unitLabel,
    required this.invoiceDateLabel,
    required this.dueDateLabel,
    required this.status,
    required this.currency,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.items,
    required this.payableInvoice,
    this.paidDateLabel,
  });

  factory _InvoiceView.fromApi(InvoiceDetail detail) {
    final payable = detail.toInvoice();
    return _InvoiceView(
      invoiceNumber: detail.invoiceNumber,
      billingPeriod: detail.billingPeriodLabel,
      unitLabel: detail.unit?.label ?? '',
      invoiceDateLabel: detail.invoiceDateLabel,
      dueDateLabel: detail.dueDateLabel,
      status: detail.invoiceStatus,
      currency: detail.currency,
      totalAmount: detail.totalAmount,
      paidAmount: detail.paidAmount,
      remainingAmount: detail.remainingAmount,
      paidDateLabel: detail.paidDateLabel.isEmpty ? null : detail.paidDateLabel,
      payableInvoice: payable.isPayable ? payable : null,
      items: detail.items
          .map(
            (item) => _ItemView(
              title: item.name.trim().isNotEmpty
                  ? item.name
                  : invoiceItemTypeFromApi(item.feeType).label,
              description: item.description,
              amount: item.amount,
              isPaid: item.isPaid,
              isMandatory: item.isMandatory,
              isPayable: item.isPayable,
              isZero: item.amount <= 0,
              status: item.status,
              paidDateLabel: item.paidDateLabel,
            ),
          )
          .toList(growable: false),
    );
  }

  factory _InvoiceView.fromLegacy(Invoice invoice) {
    return _InvoiceView(
      invoiceNumber: invoice.number,
      billingPeriod: invoice.billingPeriod,
      unitLabel: invoice.unitLabel,
      invoiceDateLabel: '',
      dueDateLabel: invoice.dueDate,
      status: invoice.status,
      currency: invoice.currency,
      totalAmount: invoice.total,
      paidAmount: invoice.amountPaid,
      remainingAmount: invoice.amountDue,
      paidDateLabel: invoice.paidDate,
      payableInvoice: invoice.isPayable ? invoice : null,
      items: invoice.items
          .map(
            (item) => _ItemView(
              title: item.type.label,
              description: item.note,
              amount: item.amount,
              isPaid: item.isPaid,
              isMandatory: item.mustPaid,
              isPayable: item.isPayable,
              isZero: item.isZero,
              status: item.isPaid ? 'paid' : '',
              paidDateLabel: item.paidDate ?? '',
            ),
          )
          .toList(growable: false),
    );
  }

  final String invoiceNumber;
  final String billingPeriod;
  final String unitLabel;
  final String invoiceDateLabel;
  final String dueDateLabel;
  final String? paidDateLabel;
  final InvoiceStatus status;
  final String currency;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final List<_ItemView> items;
  final Invoice? payableInvoice;

  String money(double value) => currency.trim().isEmpty
      ? AppFormatters.currency(value)
      : AppFormatters.money(value, currency);
}

class _ItemView {
  const _ItemView({
    required this.title,
    required this.description,
    required this.amount,
    required this.isPaid,
    required this.isMandatory,
    required this.isPayable,
    required this.isZero,
    required this.status,
    required this.paidDateLabel,
  });

  final String title;
  final String description;
  final double amount;
  final bool isPaid;
  final bool isMandatory;
  final bool isPayable;
  final bool isZero;
  final String status;
  final String paidDateLabel;

  String get statusLabel {
    final raw = status.trim();
    if (raw.isEmpty) {
      if (isPaid) return 'Paid';
      if (isPayable) return 'Payable';
      return '';
    }
    final normalized = raw.replaceAll('_', ' ');
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }
}

class _InvoiceHero extends StatelessWidget {
  const _InvoiceHero({required this.view});
  final _InvoiceView view;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
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
                  'AMOUNT DUE',
                  style: TextStyle(
                    color: tokens.brandOnDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              PaymentStatusBadge(status: view.status),
            ],
          ),
          14.h.heightBox(),
          Text(
            view.money(view.remainingAmount),
            style: TextStyle(
              color: tokens.onBrand,
              fontSize: 32.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          5.h.heightBox(),
          Text(
            '${view.invoiceNumber} · ${view.billingPeriod}',
            style: TextStyle(color: tokens.brandOnDarkMuted, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, required this.currency});
  final _ItemView item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final tags = <Widget>[
      if (item.isMandatory) _ItemTag(label: 'Mandatory', color: tokens.brand),
      if (!item.isPayable && !item.isPaid && !item.isZero)
        _ItemTag(label: 'Not payable', color: AppPalette.muted),
      if (item.statusLabel.isNotEmpty)
        _ItemTag(
          label: item.statusLabel,
          color: item.isPaid ? AppPalette.success : AppPalette.warning,
        ),
    ];
    final description = item.description.trim();
    final showDescription =
        description.isNotEmpty &&
        description.toLowerCase() != item.title.toLowerCase();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
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
          10.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: item.isPaid ? tokens.muted : tokens.ink,
                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (showDescription) ...[
                  2.h.heightBox(),
                  Text(
                    item.isPaid && item.paidDateLabel.isNotEmpty
                        ? '$description · paid ${item.paidDateLabel}'
                        : description,
                    style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  5.h.heightBox(),
                  Wrap(spacing: 5, runSpacing: 4, children: tags),
                ],
              ],
            ),
          ),
          10.w.widthBox(),
          Text(
            item.isZero ? 'No charge' : _money(item.amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: item.isPaid ? tokens.muted : tokens.ink,
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value, String currency) => currency.trim().isEmpty
      ? AppFormatters.currency(value)
      : AppFormatters.money(value, currency);
}

class _ItemTag extends StatelessWidget {
  const _ItemTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaidCard extends StatelessWidget {
  const _PaidCard({required this.view, required this.payment});
  final _InvoiceView view;
  final Payment? payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: tokens.brandTint,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tokens.brandSoft,
            child: const Icon(Icons.check_rounded, color: AppPalette.success),
          ),
          12.w.widthBox(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paid in full',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppPalette.success,
                  ),
                ),
                4.h.heightBox(),
                Text(
                  view.paidDateLabel == null || view.paidDateLabel!.isEmpty
                      ? 'Payment complete'
                      : 'Paid on ${view.paidDateLabel}',
                  style: TextStyle(color: tokens.mutedStrong, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          if (payment != null)
            Text(
              payment!.transactionId,
              style: TextStyle(
                color: AppPalette.success,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
