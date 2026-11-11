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
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_list.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_record_badge.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  late final PaymentController controller = Get.find<PaymentController>();

  @override
  void initState() {
    super.initState();
    controller.loadPaymentList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Payment history',
        subtitle: 'Every payment recorded on your account',
        actions: [
          IconButton(
            onPressed: () => controller.loadPaymentList(refresh: true),
            tooltip: 'Refresh payments',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        final items = controller.paymentList;
        final loading = controller.isLoadingPaymentList.value;
        final error = controller.paymentListError.value;

        if (loading && items.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              key: const Key('payment-list-loading'),
            ),
          );
        }
        if (error != null && items.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load payments',
            message: error,
            icon: Icons.payments_outlined,
            actionLabel: 'Try again',
            onAction: () => controller.loadPaymentList(refresh: true),
          );
        }
        if (items.isEmpty) {
          return AppStateMessage(
            title: 'No payment history',
            message: 'Completed payments will appear here.',
            icon: Icons.history_rounded,
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadPaymentList(refresh: true),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 220) {
                controller.loadMorePayments();
              }
              return false;
            },
            child: ListView(
              key: const Key('payment-history-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                10,
                AppSpacing.gutter,
                32,
              ),
              children: [
                if (controller.isShowingCachedPayments.value) ...[
                  _CacheNotice(updatedAt: controller.paymentListUpdatedLabel),
                  10.h.heightBox(),
                ],
                for (final payment in items)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _PaymentHistoryCard(
                      payment: payment,
                      onTap: payment.hasValidId
                          ? () {
                              vibrateNow();
                              Get.toNamed(
                                AppRoutes.paymentDetails,
                                arguments: payment.id,
                              );
                            }
                          : null,
                    ),
                  ),
                if (controller.isLoadingMorePayments.value) ...[
                  8.h.heightBox(),
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ] else if (controller.paymentListError.value != null) ...[
                  8.h.heightBox(),
                  _LoadMoreError(
                    message: controller.paymentListError.value!,
                    onRetry: controller.loadMorePayments,
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment, this.onTap});

  final PaymentListItem payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final parsed = payment.paymentStatus;
    final failed = parsed == PaymentStatus.failed;
    final color = failed ? AppPalette.danger : AppPalette.success;
    final amount = payment.currency.trim().isEmpty
        ? AppFormatters.currency(payment.amount)
        : AppFormatters.money(payment.amount, payment.currency);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              failed ? Icons.error_rounded : Icons.check_circle_rounded,
              color: parsed == null ? tokens.muted : color,
            ),
            10.w.widthBox(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.paymentNumber.trim().isEmpty
                        ? 'Payment'
                        : payment.paymentNumber,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (payment.invoiceNumber.trim().isNotEmpty) ...[
                    3.h.heightBox(),
                    Text(
                      payment.invoiceNumber,
                      style: TextStyle(
                        color: tokens.mutedStrong,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                  4.h.heightBox(),
                  Text(
                    [
                      if (payment.paidAtLabel.isNotEmpty) payment.paidAtLabel,
                      if (payment.paymentMethodLabel.isNotEmpty)
                        payment.paymentMethodLabel,
                    ].join(' · '),
                    style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                  ),
                  if (payment.transactionReference.trim().isNotEmpty) ...[
                    3.h.heightBox(),
                    Text(
                      payment.transactionReference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.faint, fontSize: 11.sp),
                    ),
                  ],
                ],
              ),
            ),
            10.w.widthBox(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: parsed == null ? tokens.ink : color,
                  ),
                ),
                6.h.heightBox(),
                if (parsed != null)
                  PaymentRecordBadge(status: parsed)
                else
                  _StatusPill(
                    label: payment.statusLabel,
                    color: _statusColor(payment.status, tokens),
                  ),
              ],
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: tokens.faint),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status, AppThemeTokens tokens) {
    return switch (status.trim().toLowerCase()) {
      'failed' || 'declined' || 'error' => AppPalette.danger,
      'pending' || 'processing' || 'awaiting' => AppPalette.warning,
      _ => tokens.muted,
    };
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

class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: AppPalette.danger),
          8.w.widthBox(),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: tokens.mutedStrong, fontSize: 11.sp),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
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
                  ? 'Showing saved payments'
                  : 'Showing saved payments · Updated $updatedAt',
              style: TextStyle(color: tokens.muted, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }
}
