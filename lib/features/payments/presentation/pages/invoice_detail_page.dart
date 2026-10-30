import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';

import '../../../../core/errors/app_exception.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/utils/app_formatters.dart';

import '../../../../core/widgets/app_section.dart';

import '../../../../core/widgets/app_state_message.dart';

import '../../domain/entities/invoice.dart';

import '../../domain/entities/payment.dart';

import '../controllers/payment_controller.dart';

import '../widgets/payment_status_badge.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/theme/app_spacing.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  final invoice = Rxn<Invoice>();
  final isLoading = true.obs;
  final errorMessage = RxnString();

  late final PaymentController controller;
  var _requestToken = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.find<PaymentController>();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    final requestToken = ++_requestToken;
    isLoading.value = true;
    errorMessage.value = null;

    final loaded = _loadedInvoice();
    if (loaded != null) {
      invoice.value = loaded;
      isLoading.value = false;
      return;
    }

    try {
      final result = await controller.getInvoice(widget.invoiceId);
      if (!mounted || requestToken != _requestToken) {
        return;
      }
      invoice.value = result;
      if (result == null) {
        errorMessage.value = 'The invoice could not be found.';
      }
    } on AppException catch (error) {
      if (!mounted || requestToken != _requestToken) {
        return;
      }
      errorMessage.value = error.message;
    } catch (_) {
      if (!mounted || requestToken != _requestToken) {
        return;
      }
      errorMessage.value = 'Unable to load the invoice.';
    } finally {
      if (mounted && requestToken == _requestToken) {
        isLoading.value = false;
      }
    }
  }

  Invoice? _loadedInvoice() {
    for (final item in controller.invoices) {
      if (item.id == widget.invoiceId) {
        return item;
      }
    }
    return null;
  }

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

  Widget _buildBody(BuildContext context, Invoice? currentInvoice) {
    if (isLoading.value && currentInvoice == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (currentInvoice == null) {
      final message = errorMessage.value;
      return AppStateMessage(
        title: message == null ? 'Invoice not found' : 'Unable to load invoice',
        message: message ?? 'This invoice is no longer available.',
        icon: Icons.receipt_long_outlined,
        actionLabel: message == null ? null : 'Try again',
        onAction: message == null ? null : _loadInvoice,
      );
    }
    final tokens = AppThemeTokens.of(context);
    return ListView(
      key: Key('invoice-detail-scroll'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.pageTop,
        AppSpacing.gutter,
        32,
      ),
      children: [
        _InvoiceHero(invoice: currentInvoice),
        20.h.heightBox(),
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
        16.h.heightBox(),
        AppSectionCard(
          title: 'Breakdown',
          subtitle: 'Every charge is billed and paid separately.',
          child: Column(
            children: [
              for (final item in currentInvoice.items) _ItemLine(item: item),
              Divider(height: 20),
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
        18.h.heightBox(),
        if (currentInvoice.isPayable)
          FilledButton.icon(
            key: Key('invoice-pay-selected'),
            onPressed: () {
              vibrateNow();
              controller.selectInvoice(currentInvoice);
              Get.toNamed(AppRoutes.paymentSummary);
            },
            icon: Icon(Icons.lock_outline_rounded, size: 18),
            label: Text('Choose items to pay'),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.brand,
              foregroundColor: tokens.onBrand,
              minimumSize: Size.fromHeight(52),
            ),
          )
        else
          _PaidCard(
            invoice: currentInvoice,
            payment: _paymentFor(currentInvoice),
          ),
        if (currentInvoice.isPayable) ...[
          8.h.heightBox(),
          Text(
            'Pay Now never charges the full balance automatically â€” you pick '
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
    );
  }

  Invoice? _currentInvoice() {
    final loaded = _loadedInvoice();
    if (loaded != null) {
      return loaded;
    }
    return invoice.value;
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
              PaymentStatusBadge(status: invoice.status),
            ],
          ),
          14.h.heightBox(),
          Text(
            AppFormatters.currency(invoice.amountDue),
            style: TextStyle(
              color: tokens.onBrand,
              fontSize: 32.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          5.h.heightBox(),
          Text(
            '${invoice.number} Â· ${invoice.billingPeriod}',
            style: TextStyle(color: tokens.brandOnDarkMuted, fontSize: 12.sp),
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
                  item.type.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: item.isPaid ? tokens.muted : tokens.ink,
                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.note.isNotEmpty) ...[
                  2.h.heightBox(),
                  Text(
                    item.isPaid && item.paidDate != null
                        ? '${item.note} Â· paid ${item.paidDate}'
                        : item.note,
                    style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                  ),
                ],
              ],
            ),
          ),
          10.w.widthBox(),
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
            child: Icon(Icons.check_rounded, color: AppPalette.success),
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
                  invoice.paidDate == null
                      ? 'Payment complete'
                      : 'Paid on ${invoice.paidDate}',
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
