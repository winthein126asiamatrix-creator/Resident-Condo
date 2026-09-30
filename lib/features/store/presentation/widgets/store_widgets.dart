import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/store_product.dart';

/// Aisle icon for a category, so the catalogue reads at a glance.
IconData storeCategoryIcon(StoreCategory category) {
  switch (category) {
    case StoreCategory.snacks:
      return Icons.cookie_outlined;
    case StoreCategory.beverages:
      return Icons.local_drink_outlined;
    case StoreCategory.instantFood:
      return Icons.ramen_dining_outlined;
    case StoreCategory.freshProduce:
      return Icons.eco_outlined;
    case StoreCategory.household:
      return Icons.cleaning_services_outlined;
    case StoreCategory.combos:
      return Icons.local_offer_outlined;
  }
}

/// Icon for a checkout payment method.
IconData storePaymentMethodIcon(StorePaymentMethod method) {
  switch (method) {
    case StorePaymentMethod.card:
      return Icons.credit_card_rounded;
    case StorePaymentMethod.kbzPay:
      return Icons.smartphone_rounded;
    case StorePaymentMethod.wavePay:
      return Icons.waves_rounded;
    case StorePaymentMethod.bankTransfer:
      return Icons.account_balance_rounded;
  }
}

Color storeStockColor(StoreStockStatus status) {
  switch (status) {
    case StoreStockStatus.inStock:
      return AppPalette.success;
    case StoreStockStatus.lowStock:
      return AppPalette.warning;
    case StoreStockStatus.outOfStock:
      return AppPalette.faint;
  }
}

IconData storeStockIcon(StoreStockStatus status) {
  switch (status) {
    case StoreStockStatus.inStock:
      return Icons.check_circle_outline_rounded;
    case StoreStockStatus.lowStock:
      return Icons.error_outline_rounded;
    case StoreStockStatus.outOfStock:
      return Icons.remove_circle_outline_rounded;
  }
}

Color storeOrderStatusColor(StoreOrderStatus status) {
  switch (status) {
    case StoreOrderStatus.submitted:
      return AppPalette.info;
    case StoreOrderStatus.confirmed:
      return AppPalette.info;
    case StoreOrderStatus.preparing:
      return AppPalette.warning;
    case StoreOrderStatus.outForDelivery:
    case StoreOrderStatus.readyForPickup:
      return AppPalette.brand;
    case StoreOrderStatus.completed:
      return AppPalette.success;
    case StoreOrderStatus.cancelled:
      return AppPalette.danger;
  }
}

IconData storeOrderStatusIcon(StoreOrderStatus status) {
  switch (status) {
    case StoreOrderStatus.submitted:
      return Icons.receipt_long_rounded;
    case StoreOrderStatus.confirmed:
      return Icons.task_alt_rounded;
    case StoreOrderStatus.preparing:
      return Icons.soup_kitchen_outlined;
    case StoreOrderStatus.outForDelivery:
      return Icons.delivery_dining_rounded;
    case StoreOrderStatus.readyForPickup:
      return Icons.shopping_bag_outlined;
    case StoreOrderStatus.completed:
      return Icons.check_circle_rounded;
    case StoreOrderStatus.cancelled:
      return Icons.cancel_rounded;
  }
}

/// Order status badge: an icon and a word as well as a colour.
class StoreOrderStatusPill extends StatelessWidget {
  const StoreOrderStatusPill({required this.status, this.dense = true, super.key});

  final StoreOrderStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: storeOrderStatusColor(status),
      icon: storeOrderStatusIcon(status),
      dense: dense,
    );
  }
}

/// Stock badge for a product.
class StoreStockPill extends StatelessWidget {
  const StoreStockPill({required this.status, this.dense = true, super.key});

  final StoreStockStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: switch (status) {
        StoreStockStatus.inStock => 'In Stock',
        StoreStockStatus.lowStock => 'Low Stock',
        StoreStockStatus.outOfStock => 'Out of Stock',
      },
      color: storeStockColor(status),
      icon: storeStockIcon(status),
      dense: dense,
    );
  }
}

/// Payment state for a store fee.
class StorePaymentPill extends StatelessWidget {
  const StorePaymentPill({required this.payment, super.key});

  final StorePaymentStatus payment;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: payment.label,
      color: payment == StorePaymentStatus.paid
          ? AppPalette.success
          : AppPalette.warning,
      icon: payment == StorePaymentStatus.paid
          ? Icons.check_circle_outline_rounded
          : Icons.schedule_rounded,
      dense: true,
    );
  }
}

/// Photography of the actual product, in a square frame.
///
/// Residents shop by recognising the item, so a card leads with a photograph
/// rather than a glyph. The frame is a fixed 1:1 square with the photo cropped
/// to fill it and clipped to 12 px corners. A soft tinted placeholder holds the
/// space while the photo loads, and a neutral one stands in if the network or
/// the photo itself fails, so a card is never left ragged.
class StoreProductImage extends StatelessWidget {
  const StoreProductImage({required this.product, this.size = 64, super.key});

  final StoreProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: product.imageUrl.isEmpty
            ? _Placeholder(size: size, icon: storeCategoryIcon(product.category))
            : Image.network(
                product.imageUrl,
                key: Key('store-photo-${product.id}'),
                fit: BoxFit.cover,
                width: size,
                height: size,
                // The placeholder holds the frame until the bytes arrive, then
                // cross-fades so the swap is not abrupt.
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _Placeholder(key: const ValueKey('loading'), size: size),
                  );
                },
                errorBuilder: (_, _, _) => _Placeholder(
                  size: size,
                  icon: storeCategoryIcon(product.category),
                ),
              ),
      ),
    );
  }
}

/// Tinted stand-in shown while a photo loads or if it cannot be fetched.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, this.icon, super.key});

  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.brandTint,
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(icon, color: AppPalette.brand, size: size * 0.4),
            ),
    );
  }
}

/// One line in a receipt style list: quantity, name and unit price.
class StoreOrderLineRow extends StatelessWidget {
  const StoreOrderLineRow({required this.line, super.key});

  final StoreCartLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.brandTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${line.quantity}×',
              style: const TextStyle(
                color: AppPalette.brand,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.product.name,
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppFormatters.currency(line.lineTotal),
            style: const TextStyle(
              color: AppPalette.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
