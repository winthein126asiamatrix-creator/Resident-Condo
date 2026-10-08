import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_action.dart';
import '../../../../core/widgets/app_step_progress.dart';
import '../../domain/entities/store_product.dart';
import '../controllers/store_controller.dart';
import 'store_widgets.dart';

/// Totals block for the basket and for the checkout review.
///
/// The store fee is called out on its own so it is never mistaken for part of
/// the monthly condo fee.
class StoreCheckoutSummaryCard extends StatelessWidget {
  const StoreCheckoutSummaryCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.itemCount,
    this.keyName,
    super.key,
  });

  final double subtotal;
  final double deliveryFee;
  final double total;
  final int itemCount;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      key: keyName == null ? null : Key(keyName!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: tokens.brand,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Order summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TotalRow(
            label: 'Subtotal',
            value: AppFormatters.currency(subtotal),
          ),
          _TotalRow(
            label: 'Delivery',
            value: deliveryFee == 0
                ? 'Free'
                : AppFormatters.currency(deliveryFee),
            muted: deliveryFee == 0,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: tokens.border),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Store Fee total',
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                AppFormatters.currency(total),
                key: const Key('store-total'),
                style: TextStyle(
                  color: tokens.brand,
                  fontSize: 18,
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

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: muted ? AppPalette.success : tokens.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: muted ? AppPalette.success : tokens.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Order progress, driven by the order's real status.
class StoreOrderTrackerCard extends StatelessWidget {
  const StoreOrderTrackerCard({required this.order, super.key});

  final StoreOrder order;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == StoreOrderStatus.cancelled;
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      key: const Key('store-order-tracker'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order progress',
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StoreOrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.id,
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (cancelled)
            // A cancelled order has no happy path to walk through.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                'This order was cancelled. Any Store Fee for it has been '
                'released back to your statement.',
                style: TextStyle(
                  color: AppPalette.danger,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            AppStepProgress(
              steps: [
                for (final status in order.status.timeline)
                  AppProgressStep(title: status.label),
              ],
              // The handover step is reached as soon as the order leaves the
              // store, so it counts as the current step for both variants.
              currentIndex: _currentIndex(order),
            ),
        ],
      ),
    );
  }

  /// Where the highlight sits on the timeline for this order's status.
  static int _currentIndex(StoreOrder order) {
    final steps = order.status.timeline;
    final done = switch (order.status) {
      StoreOrderStatus.submitted => 0,
      StoreOrderStatus.confirmed => 1,
      StoreOrderStatus.preparing => 2,
      // Out for delivery and ready for pick-up are the handover step.
      StoreOrderStatus.outForDelivery => 3,
      StoreOrderStatus.readyForPickup => 3,
      // Completed means the last step is the one that happened.
      StoreOrderStatus.completed => steps.length - 1,
      StoreOrderStatus.cancelled => 0,
    };
    return done.clamp(0, steps.length - 1);
  }
}

/// A single order in the resident's list, ready to open.
class StoreOrderTrackerListCard extends StatelessWidget {
  const StoreOrderTrackerListCard({
    required this.order,
    required this.onTap,
    super.key,
  });

  final StoreOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      key: Key('store-order-${order.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: storeOrderStatusColor(order.status, tokens).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  storeOrderStatusIcon(order.status),
                  color: storeOrderStatusColor(order.status, tokens),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id,
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} · ${order.deliveryMethod.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.currency(order.total),
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  StorePaymentPill(payment: order.paymentStatus),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.deliveryTime,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.mutedStrong, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Explains that a store fee is its own charge, kept away from the condo fee.
class StoreFeeNotice extends StatelessWidget {
  const StoreFeeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('store-fee-notice'),
      color: AppPalette.amberSoft,
      borderColor: const Color(0xFFF2E0B8),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This is a Store Fee. It is billed as its own line and is never '
              'added to your monthly condo fee, rent, utilities or any fine.',
              style: TextStyle(
                color: Color(0xFF7A4A0B),
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirms that an item landed in the basket.
///
/// The card's stepper already changes in place, so this is the second half of
/// the feedback: a small confirmation that names the item and how many are now
/// in the basket, so a tap is never silently swallowed. It floats above the
/// list and retires itself.
void showStoreAddedToBasket(
  BuildContext context, {
  required StoreProduct product,
  required int quantity,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  final tokens = AppThemeTokens.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        key: const Key('store-added-snackbar'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.ink,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        duration: const Duration(milliseconds: 1600),
        content: Row(
          children: [
            StoreProductImage(product: product, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Added to your basket · $quantity in basket',
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF6EE7B7),
              size: 20,
            ),
          ],
        ),
      ),
    );
}

/// Basket's way through to checkout.
///
/// One button so the affordance is identical from the basket and from the
/// product sheet.
class StoreCheckoutButton extends StatelessWidget {
  const StoreCheckoutButton({
    required this.controller,
    this.addFirst = false,
    this.label,
    super.key,
  });

  final StoreController controller;

  /// Used by the product sheet, where the button adds the product first.
  final bool addFirst;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isSubmitting = controller.isSubmitting.value;
    final canGo = controller.canCheckout || addFirst;
    return AppPrimaryAction(
      key: const Key('store-checkout'),
      onPressed: canGo && !isSubmitting
          ? () {
              if (addFirst) {
                final product = controller.selectedProduct.value;
                if (product != null) {
                  controller.addToCart(product);
                }
              }
              controller.selectTab(StoreTab.basket);
              Get.toNamed(AppRoutes.storeCheckout);
            }
          : null,
      isLoading: isSubmitting,
      label:
          label ??
          (controller.cart.isEmpty
              ? 'Choose a delivery time'
              : 'Review & checkout · ${controller.cartCount}'),
      icon: Icons.shopping_cart_checkout_rounded,
    );
  }
}

/// Keeps the catalogue honest about what is on the shelf.
class StoreCartBadge extends StatelessWidget {
  const StoreCartBadge({required this.count, required this.onTap, super.key});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = count == 0;
    final tokens = AppThemeTokens.of(context);
    return Semantics(
      button: true,
      label: empty
          ? 'Basket, empty'
          : 'Basket, $count ${count == 1 ? 'item' : 'items'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          key: const Key('store-cart-badge'),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: empty ? tokens.surface : tokens.brand,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: empty ? tokens.border : tokens.brand),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_basket_outlined,
                size: 19,
                color: empty ? tokens.muted : tokens.onBrand,
              ),
              const SizedBox(width: 7),
              Text(
                empty ? 'Basket' : '$count',
                style: TextStyle(
                  color: empty ? tokens.muted : tokens.onBrand,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
