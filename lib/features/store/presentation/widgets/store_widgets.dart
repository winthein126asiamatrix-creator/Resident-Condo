import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
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

Color storeStockColor(StoreStockStatus status, AppThemeTokens tokens) {
  switch (status) {
    case StoreStockStatus.inStock:
      return AppPalette.success;
    case StoreStockStatus.lowStock:
      return AppPalette.warning;
    case StoreStockStatus.outOfStock:
      return tokens.faint;
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

Color storeOrderStatusColor(StoreOrderStatus status, AppThemeTokens tokens) {
  switch (status) {
    case StoreOrderStatus.submitted:
      return AppPalette.info;
    case StoreOrderStatus.confirmed:
      return AppPalette.info;
    case StoreOrderStatus.preparing:
      return AppPalette.warning;
    case StoreOrderStatus.outForDelivery:
    case StoreOrderStatus.readyForPickup:
      return tokens.brand;
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
      color: storeOrderStatusColor(status, AppThemeTokens.of(context)),
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
      color: storeStockColor(status, AppThemeTokens.of(context)),
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
///
/// The card paints 34 to 132 logical pixels, so nothing here asks for or decodes
/// the full size photo: the request is trimmed to the frame and the result is
/// decoded at device resolution for that frame. That is the difference between a
/// shelf that scrolls smoothly and one that stutters, because a catalogue photo
/// is small on screen but expensive to decode at its original size.
class StoreProductImage extends StatelessWidget {
  const StoreProductImage({required this.product, this.size = 64, super.key});

  final StoreProduct product;
  final double size;

  /// Sizes the catalogue actually has. A photo is rounded up to the next one, so
  /// a card at 76 px and the same card at 34 px do not each ask for their own
  /// odd sized image.
  static const _pixelBuckets = <int>[96, 128, 192, 256, 384, 512];

  static int _pixelBucket(double physical) {
    for (final bucket in _pixelBuckets) {
      if (physical <= bucket) {
        return bucket;
      }
    }
    return _pixelBuckets.last;
  }

  /// The photo at the size it is painted, for hosts that resize on request.
  ///
  /// The catalogue urls already ask for a square crop from a CDN that takes `w`,
  /// `h`, `fit` and `auto`, so only the size is swapped. A url without those
  /// parameters is returned untouched, since a host that cannot resize must not
  /// be handed a made up query. `auto=format` is left alone, which is what gets
  /// the modern format the device prefers instead of a heavier one.
  static String _atPixels(String url, int pixels) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    final query = uri.queryParameters;
    if (!query.containsKey('w') || !query.containsKey('h')) {
      return url;
    }
    if (query['w'] == '$pixels' && query['h'] == '$pixels') {
      return url;
    }
    return uri
        .replace(queryParameters: {...query, 'w': '$pixels', 'h': '$pixels'})
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final pixels = _pixelBucket(size * MediaQuery.devicePixelRatioOf(context));
    final url = product.imageUrl.isEmpty
        ? ''
        : _atPixels(product.imageUrl, pixels);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? _Placeholder(
                size: size,
                icon: storeCategoryIcon(product.category),
              )
            : Image.network(
                url,
                key: Key('store-photo-${product.id}'),
                fit: BoxFit.cover,
                width: size,
                height: size,
                // Decodes at the size on screen instead of the size the CDN
                // sent, so a thumbnail never carries a full size bitmap around
                // in the image cache.
                cacheWidth: pixels,
                cacheHeight: pixels,
                // Keeps the last frame while a new one is decoded, so returning
                // to the shelf does not flash the placeholder back over photos
                // that are already cached.
                gaplessPlayback: true,
                // Fires once, when the frame is ready, rather than on every
                // chunk of download progress. The two states are different
                // widgets, so the cross fade below actually runs and no
                // neighbouring card is rebuilt along the way.
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) {
                    return child;
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: frame == null
                        ? _Placeholder(
                            key: const ValueKey('pending'),
                            size: size,
                          )
                        : child,
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
    final tokens = AppThemeTokens.of(context);
    return ColoredBox(
      color: tokens.brandTint,
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(icon, color: tokens.brand, size: size * 0.4),
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
    final tokens = AppThemeTokens.of(context);
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
              color: tokens.brandTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${line.quantity}×',
              style: TextStyle(
                color: tokens.brand,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.product.name,
              style: TextStyle(
                color: tokens.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppFormatters.currency(line.lineTotal),
            style: TextStyle(
              color: tokens.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
