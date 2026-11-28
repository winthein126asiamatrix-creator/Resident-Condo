import 'package:test/core/utils/haptics.dart';
import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_state_message.dart';

import '../controllers/payment_controller.dart';
import '../widgets/invoice_card.dart';

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
                    child: InvoiceCard.fromInvoiceListItem(
                      key: Key('payable-invoice-${invoice.id}'),
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
