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
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_list.dart';
import '../controllers/payment_controller.dart';
import '../widgets/payment_status_badge.dart';

/// The resident's invoices, opened from the payment dashboard's "View all".
///
/// The first page is read from the device cache and then refreshed from the API
/// in the background. Only the first page is ever written back, capped at the
/// newest ten invoices, so pagination never grows the offline snapshot.
class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  static const _filters = <AppSegmentedTab>[
    AppSegmentedTab(
      name: 'all',
      label: 'All',
      icon: Icons.receipt_long_outlined,
    ),
    AppSegmentedTab(
      name: 'unpaid',
      label: 'Unpaid',
      icon: Icons.schedule_rounded,
    ),
    AppSegmentedTab(
      name: 'partial',
      label: 'Partial',
      icon: Icons.timelapse_rounded,
    ),
    AppSegmentedTab(
      name: 'paid',
      label: 'Paid',
      icon: Icons.check_circle_outline,
    ),
  ];

  late final PaymentController controller = Get.find<PaymentController>();

  @override
  void initState() {
    super.initState();
    controller.loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Invoices',
        subtitle: 'Statement history and outstanding balances',
        actions: [
          IconButton(
            onPressed: () => controller.loadInvoices(refresh: true),
            tooltip: 'Refresh invoices',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        final items = controller.invoiceList;
        final loading = controller.isLoadingInvoiceList.value;
        final error = controller.invoiceListError.value;
        final filtering = controller.invoiceListStatus.value != 'all';

        final statusIndex = _filters.indexWhere(
          (tab) => tab.name == controller.invoiceListStatus.value,
        );
        return RefreshIndicator(
          onRefresh: () => controller.loadInvoices(refresh: true),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 220) {
                controller.loadMoreInvoices();
              }
              return false;
            },
            child: ListView(
              key: const Key('invoice-list-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.pageTop,
                AppSpacing.gutter,
                32,
              ),
              children: [
                // Always keep the filter strip on screen. Replacing the whole
                // page with a spinner or an error previously made Partial and
                // Paid look unreachable while their first page was loading.
                AppSegmentedTabs(
                  tabs: _filters,
                  selectedIndex: statusIndex < 0 ? 0 : statusIndex,
                  onSelect: (index) =>
                      controller.selectInvoiceListStatus(_filters[index].name),
                  keyPrefix: 'invoice-filter',
                ),
                if (controller.isShowingCachedInvoices.value) ...[
                  10.h.heightBox(),
                  _CacheNotice(updatedAt: controller.invoiceListUpdatedLabel),
                ],
                14.h.heightBox(),
                if (loading && items.isEmpty)
                  SizedBox(
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(
                        key: const Key('invoice-list-loading'),
                      ),
                    ),
                  )
                else if (error != null && items.isEmpty)
                  AppStateMessage(
                    title: 'Unable to load invoices',
                    message: error,
                    icon: Icons.receipt_long_outlined,
                    actionLabel: 'Try again',
                    onAction: () => controller.loadInvoices(refresh: true),
                  )
                else if (items.isEmpty)
                  AppStateMessage(
                    title: 'No invoices',
                    message: filtering
                        ? 'No invoices match this filter.'
                        : 'Your invoices will appear here.',
                    icon: Icons.receipt_long_outlined,
                  )
                else
                  for (final invoice in items)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _InvoiceCard(
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
                if (controller.isLoadingMoreInvoices.value) ...[
                  8.h.heightBox(),
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap});

  final InvoiceListItem invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final settled = invoice.invoiceStatus == InvoiceStatus.paid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconTile(
              icon: settled
                  ? Icons.receipt_long_rounded
                  : Icons.receipt_long_outlined,
              color: settled ? AppPalette.success : tokens.brand,
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
                  3.h.heightBox(),
                  Text(
                    invoice.billingPeriodLabel,
                    style: TextStyle(color: tokens.muted, fontSize: 12.sp),
                  ),
                  if (invoice.invoiceDate != null ||
                      invoice.dueDate != null) ...[
                    4.h.heightBox(),
                    Text(
                      [
                        if (invoice.invoiceDateLabel.isNotEmpty)
                          'Issued ${invoice.invoiceDateLabel}',
                        if (invoice.dueDateLabel.isNotEmpty)
                          'Due ${invoice.dueDateLabel}',
                      ].join(' · '),
                      style: TextStyle(color: tokens.muted, fontSize: 11.sp),
                    ),
                  ],
                  6.h.heightBox(),
                  Text(
                    'Total ${_money(invoice.totalAmount, invoice.currency)} · '
                    'Paid ${_money(invoice.paidAmount, invoice.currency)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.mutedStrong,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            10.w.widthBox(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(invoice.remainingAmount, invoice.currency),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                3.h.heightBox(),
                Text(
                  'Remaining',
                  style: TextStyle(color: tokens.muted, fontSize: 10.sp),
                ),
                6.h.heightBox(),
                PaymentStatusBadge(status: invoice.invoiceStatus),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.faint),
          ],
        ),
      ),
    );
  }

  String _money(double value, String currency) => currency.trim().isEmpty
      ? AppFormatters.currency(value)
      : AppFormatters.money(value, currency);
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
