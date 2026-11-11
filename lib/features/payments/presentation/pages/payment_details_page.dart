import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_detail.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_record_badge.dart';

class PaymentDetailsPage extends StatefulWidget {
  const PaymentDetailsPage({this.paymentId, super.key});

  final int? paymentId;

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  late final PaymentController controller = Get.find<PaymentController>();

  @override
  void initState() {
    super.initState();
    final id = widget.paymentId;
    if (id != null && id > 0) {
      controller.loadPaymentDetail(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final id = widget.paymentId;
      if (id == null || id <= 0) {
        return _missingPayment();
      }
      final detail = controller.paymentDetail.value;
      final loading = controller.isLoadingPaymentDetail.value;
      final error = controller.paymentDetailError.value;
      if (detail == null || (detail.id != 0 && detail.id != id)) {
        return Scaffold(
          appBar: AppDetailAppBar(
            title: 'Payment details',
            actions: [
              IconButton(
                onPressed: () => controller.loadPaymentDetail(id),
                tooltip: 'Refresh payment',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: loading
              ? Center(
                  child: CircularProgressIndicator(
                    key: const Key('payment-detail-loading'),
                  ),
                )
              : AppStateMessage(
                  title: 'Unable to load payment',
                  message: error ?? 'This payment is not available right now.',
                  icon: Icons.payments_outlined,
                  actionLabel: 'Try again',
                  onAction: () => controller.loadPaymentDetail(id),
                ),
        );
      }
      return _PaymentDetailView(
        detail: detail,
        onRefresh: () => controller.loadPaymentDetail(id),
        onOpenReceipt: (url) => _openReceipt(url),
      );
    });
  }

  Widget _missingPayment() {
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Payment details'),
      body: AppStateMessage(
        title: 'Payment not available',
        message: 'Choose a payment from the payment history.',
        icon: Icons.payments_outlined,
        actionLabel: 'Back',
        onAction: Get.back,
      ),
    );
  }

  Future<void> _openReceipt(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      showAppFeedback(
        context,
        title: 'Receipt',
        message: 'This receipt link is not valid.',
        isError: true,
      );
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showAppFeedback(
          context,
          title: 'Receipt',
          message: 'Unable to open the receipt. Please try again.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppFeedback(
          context,
          title: 'Receipt',
          message: 'Unable to open the receipt. Please try again.',
          isError: true,
        );
      }
    }
  }
}

class _PaymentDetailView extends StatelessWidget {
  const _PaymentDetailView({
    required this.detail,
    required this.onRefresh,
    required this.onOpenReceipt,
  });

  final PaymentDetail detail;
  final VoidCallback onRefresh;
  final Future<void> Function(String url) onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final money = detail.currency.trim().isEmpty
        ? AppFormatters.currency(detail.amount)
        : AppFormatters.money(detail.amount, detail.currency);
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Payment details',
        actions: [
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Refresh payment',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        key: const Key('payment-detail-scroll'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.pageTop,
          AppSpacing.gutter,
          32,
        ),
        children: [
          Container(
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
                        'AMOUNT PAID',
                        style: TextStyle(
                          color: tokens.brandOnDark,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    _PaymentStatusPill(
                      status: detail.status,
                      parsed: detail.paymentStatus,
                    ),
                  ],
                ),
                14.h.heightBox(),
                Text(
                  money,
                  style: TextStyle(
                    color: tokens.onBrand,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                5.h.heightBox(),
                Text(
                  _valueOrDash(detail.paymentNumber),
                  style: TextStyle(
                    color: tokens.brandOnDarkMuted,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          20.h.heightBox(),
          AppSectionCard(
            title: 'Payment information',
            child: Column(
              children: [
                AppLabelValueRow(
                  label: 'Payment number',
                  value: _valueOrDash(detail.paymentNumber),
                ),
                AppLabelValueRow(
                  label: 'Invoice number',
                  value: _valueOrDash(detail.invoiceNumber),
                ),
                AppLabelValueRow(
                  label: 'Amount',
                  value: money,
                  emphasize: true,
                ),
                AppLabelValueRow(
                  label: 'Currency',
                  value: _valueOrDash(detail.currency),
                ),
                AppLabelValueRow(
                  label: 'Payment method',
                  value: _valueOrDash(detail.paymentMethodLabel),
                ),
                AppLabelValueRow(
                  label: 'Transaction reference',
                  value: _valueOrDash(detail.transactionReference),
                ),
                AppLabelValueRow(
                  label: 'Status',
                  valueWidget: _PaymentStatusPill(
                    status: detail.status,
                    parsed: detail.paymentStatus,
                  ),
                ),
                AppLabelValueRow(
                  label: 'Paid date/time',
                  value: _valueOrDash(detail.paidAtLabel),
                ),
              ],
            ),
          ),
          16.h.heightBox(),
          AppSectionCard(
            title: 'Receipt',
            child: _ReceiptSection(
              receipt: detail.receipt,
              onOpenReceipt: onOpenReceipt,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({required this.receipt, required this.onOpenReceipt});

  final PaymentReceiptInfo? receipt;
  final Future<void> Function(String url) onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final value = receipt;
    if (value == null || value.isEmpty) {
      return Row(
        children: [
          Icon(Icons.receipt_long_outlined, size: 20, color: tokens.muted),
          10.w.widthBox(),
          Expanded(
            child: Text(
              'No receipt is available for this payment.',
              style: TextStyle(color: tokens.muted, fontSize: 12.sp),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppLabelValueRow(
          label: 'Receipt number',
          value: _valueOrDash(value.receiptNumber),
        ),
        if (value.hasDownloadUrl) ...[
          12.h.heightBox(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('payment-receipt-download'),
              onPressed: () {
                vibrateNow();
                onOpenReceipt(value.downloadUrl);
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download receipt'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.brand,
                foregroundColor: tokens.onBrand,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ] else ...[
          8.h.heightBox(),
          Text(
            'This receipt has no downloadable file.',
            style: TextStyle(color: tokens.muted, fontSize: 11.sp),
          ),
        ],
      ],
    );
  }
}

class _PaymentStatusPill extends StatelessWidget {
  const _PaymentStatusPill({required this.status, required this.parsed});

  final String status;
  final PaymentStatus? parsed;

  @override
  Widget build(BuildContext context) {
    final value = parsed;
    if (value != null) {
      return PaymentRecordBadge(status: value);
    }
    final tokens = AppThemeTokens.of(context);
    final label = paymentStatusLabelFromApi(status);
    final normalized = status.trim().toLowerCase();
    final color = switch (normalized) {
      'failed' || 'declined' || 'error' => AppPalette.danger,
      'pending' || 'processing' || 'awaiting' => AppPalette.warning,
      _ => tokens.muted,
    };
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

String _valueOrDash(String value) => value.trim().isEmpty ? '—' : value;
