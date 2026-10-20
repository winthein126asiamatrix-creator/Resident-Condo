import 'package:test/core/utils/sized_box_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';

import '../../../../core/theme/app_theme_tokens.dart';

import '../../../../core/theme/app_spacing.dart';

import '../../../../core/utils/app_formatters.dart';

import '../../../../core/widgets/app_card.dart';

import '../../../../core/widgets/app_detail_app_bar.dart';

import '../../../../core/widgets/app_dialogs.dart';

import '../../../../core/widgets/app_primary_action.dart';

import '../../../../core/widgets/app_buttons.dart';

import '../../domain/entities/store_product.dart';

import '../controllers/store_controller.dart';

import '../widgets/store_cards.dart';

import '../widgets/store_widgets.dart';

/// Everything about one store order: what was bought, where it is going and
/// where it has got to.
class StoreOrderDetailPage extends GetView<StoreController> {
  const StoreOrderDetailPage({required this.order, super.key});

  final StoreOrder order;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppDetailAppBar(title: 'Order details'),
      body: Obx(() {
        // Follow the live copy so a status change is reflected here.
        final current = _currentOrder();
        return ListView(
          key: Key('store-order-detail-scroll'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.pageTop,
            AppSpacing.gutter,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _OrderHeader(order: current),
            16.h.heightBox(),
            StoreOrderTrackerCard(order: current),
            16.h.heightBox(),
            AppCard(
              key: Key('store-order-items'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchased items',
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  8.h.heightBox(),
                  for (final line in current.items)
                    StoreOrderLineRow(line: line),
                ],
              ),
            ),
            16.h.heightBox(),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery',
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  10.h.heightBox(),
                  _InfoLine(
                    label: 'Method',
                    value: current.deliveryMethod.label,
                  ),
                  _InfoLine(label: 'Location', value: current.deliveryLocation),
                  _InfoLine(label: 'Time', value: current.deliveryTime),
                  _InfoLine(
                    label: 'Assigned to',
                    value: current.assignedTo.isEmpty
                        ? 'Not assigned yet'
                        : current.assignedTo,
                  ),
                ],
              ),
            ),
            16.h.heightBox(),
            StoreCheckoutSummaryCard(
              keyName: 'store-order-total',
              subtotal: current.subtotal,
              deliveryFee: current.deliveryFee,
              total: current.total,
              itemCount: current.itemCount,
            ),
            16.h.heightBox(),
            StoreFeeNotice(),
            // A resident settles an outstanding Store Fee and can call off their
            // own order. Moving an order along the pipeline is the store's job,
            // so the order here is read-only apart from those two.
            if (current.paymentStatus == StorePaymentStatus.pending &&
                !current.status.isFinished) ...[
              20.h.heightBox(),
              AppPrimaryAction(
                key: Key('store-order-pay-now'),
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => controller.markOrderPaid(current),
                isLoading: controller.isSubmitting.value,
                label: 'Pay for Order Now',
                icon: Icons.payments_rounded,
                backgroundColor: tokens.brand,
              ),
            ],
            if (current.status.canCancel) ...[
              10.h.heightBox(),
              AppOutlinedButton(
                key: Key('store-order-cancel'),
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _cancel(context, current),
                label: 'Cancel order',
                icon: Icons.cancel_outlined,
                foregroundColor: AppPalette.danger,
              ),
            ],
          ],
        );
      }),
    );
  }

  /// The live copy if it is still loaded, otherwise the one passed in.
  StoreOrder _currentOrder() {
    for (final candidate in controller.orders) {
      if (candidate.id == order.id) {
        return candidate;
      }
    }
    return order;
  }

  /// Cancelling gives up an order, so it is confirmed first.
  Future<void> _cancel(BuildContext context, StoreOrder order) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel ${order.id}?',
      message:
          'This calls the order off. It can only be done before the '
          'store hands it over for delivery.',
      confirmLabel: 'Cancel order',
      destructive: true,
    );
    if (confirmed) {
      await controller.cancelOrder(order);
    }
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final StoreOrder order;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order ID',
                  style: TextStyle(
                    color: tokens.muted,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                order.id,
                key: Key('store-order-id'),
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          12.h.heightBox(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Placed on',
                  style: TextStyle(
                    color: tokens.muted,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                order.placedOn,
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          14.h.heightBox(),
          Row(
            children: [
              StoreOrderStatusPill(status: order.status, dense: false),
              8.w.widthBox(),
              StorePaymentPill(payment: order.paymentStatus),
              Spacer(),
              Text(
                AppFormatters.currency(order.total),
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: tokens.muted, fontSize: 12.5.sp),
            ),
          ),
          10.w.widthBox(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tokens.ink,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
