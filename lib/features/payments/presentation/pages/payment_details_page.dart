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
import '../../../../core/widgets/app_image_preview.dart';
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
        onDownloadReceipt: () => _downloadReceipt(detail),
        isDownloadingReceipt: controller.isDownloadingReceipt.value,
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

  Future<void> _downloadReceipt(PaymentDetail detail) async {
    if (controller.isDownloadingReceipt.value) {
      return;
    }
    try {
      final result = await controller.downloadReceipt(detail);
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        title: 'Receipt',
        message: result.message,
        isError: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        title: 'Receipt',
        message: _receiptErrorMessage(error),
        isError: true,
      );
    }
  }

  String _receiptErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission')) {
      return 'Storage permission is required to save the receipt. '
          'Please allow it in settings.';
    }
    if (text.contains('space')) {
      return 'Not enough storage space to save the receipt.';
    }
    if (text.contains('already in progress')) {
      return 'A receipt download is already in progress.';
    }
    if (text.contains('unsupported') ||
        text.contains('not a valid') ||
        text.contains('empty') ||
        text.contains('invalid')) {
      return 'The receipt file could not be verified. Please try again.';
    }
    if (text.contains('network') || text.contains('timeout')) {
      return 'Network error. Please try again.';
    }
    return 'Unable to save the receipt. Please try again.';
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
    required this.onDownloadReceipt,
    required this.isDownloadingReceipt,
  });

  final PaymentDetail detail;
  final VoidCallback onRefresh;
  final Future<void> Function() onDownloadReceipt;
  final bool isDownloadingReceipt;

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
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
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
                  label: 'Submitted At',
                  value: _valueOrDash(detail.submittedAtLabel),
                ),
                AppLabelValueRow(
                  label: 'Paid date/time',
                  value: _valueOrDash(detail.paidAtLabel),
                ),
              ],
            ),
          ),
          if (detail.hasProofImage) ...[
            16.h.heightBox(),
            AppSectionCard(
              title: 'Payment Proof',
              child: AppImagePreview(
                key: const Key('payment-proof-image'),
                path: detail.proofImageUrl!,
                caption: 'Payment proof',
                height: 220,
                fit: BoxFit.contain,
              ),
            ),
          ],
          16.h.heightBox(),
          AppSectionCard(
            title: 'Receipt',
            child: _ReceiptSection(
              receipt: detail.receipt,
              status: detail.status,
              isDownloading: isDownloadingReceipt,
              onDownloadReceipt: onDownloadReceipt,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({
    required this.receipt,
    required this.status,
    required this.isDownloading,
    required this.onDownloadReceipt,
  });

  final PaymentReceiptInfo? receipt;
  final String status;
  final bool isDownloading;
  final Future<void> Function() onDownloadReceipt;

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
    final isPaid = paymentStatusFromApi(status) == PaymentStatus.successful;
    final canDownload = isPaid && value.hasDownloadUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppLabelValueRow(
          label: 'Receipt number',
          value: _valueOrDash(value.receiptNumber),
        ),
        if (canDownload) ...[
          12.h.heightBox(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('payment-receipt-download'),
              onPressed: isDownloading
                  ? null
                  : () {
                      vibrateNow();
                      onDownloadReceipt();
                    },
              icon: isDownloading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.onBrand,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                isDownloading ? 'Downloading...' : 'Download receipt',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.brand,
                foregroundColor: tokens.onBrand,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ] else if (value.hasDownloadUrl) ...[
          8.h.heightBox(),
          Text(
            'Receipt download is available after payment is confirmed.',
            style: TextStyle(color: tokens.muted, fontSize: 11.sp),
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
  const _PaymentStatusPill({required this.status, required this.parsed, this.backgroundColor});

  final String status;
  final PaymentStatus? parsed;
  final Color? backgroundColor;

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
        color:backgroundColor?? color.withValues(alpha: 0.12),
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
