import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/store_product.dart';
import 'store_widgets.dart';

/// Catalogue tile: photo, name, brand, price, stock and the basket control.
///
/// The action is the same control in two states. With nothing in the basket it
/// is a single wide "Add" button; the moment the product is in the basket it
/// becomes a `- qty +` stepper on the same spot, so a resident never has to
/// look somewhere else to change a quantity. The basket count and the total on
/// the page both react to the same state, so the two can never disagree.
class StoreProductCard extends StatelessWidget {
  const StoreProductCard({
    required this.product,
    required this.onAdd,
    required this.onRemove,
    this.onOpen,
    this.inCartQuantity = 0,
    super.key,
  });

  final StoreProduct product;
  final VoidCallback onAdd;

  /// Takes one off, dropping the line at zero.
  final VoidCallback onRemove;
  final VoidCallback? onOpen;

  /// How many of this product are already in the basket.
  final int inCartQuantity;

  @override
  Widget build(BuildContext context) {
    final outOfStock = !product.isInStock;
    return AppCard(
      key: Key('store-product-${product.id}'),
      onTap: onOpen,
      padding: const EdgeInsets.all(12),
      borderRadius: AppRadius.xl,
      showShadow: true,
      borderColor: const Color(0x0F000000),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreProductImage(product: product, size: 76),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.1,
                  ),
                ),
                if (product.brand.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.faint,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      AppFormatters.currency(product.price),
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 7),
                    // The unit gives way rather than the price: a narrow phone
                    // may not fit both, and the price is what matters.
                    Flexible(
                      child: Text(
                        product.unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.faint,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StoreStockPill(status: product.stockStatus, dense: true),
                const SizedBox(height: 10),
                _BasketControl(
                  product: product,
                  quantity: inCartQuantity,
                  enabled: !outOfStock,
                  onAdd: onAdd,
                  onRemove: onRemove,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The add / stepper control. Same footprint in both states so the card does
/// not jump when an item goes into the basket.
class _BasketControl extends StatelessWidget {
  const _BasketControl({
    required this.product,
    required this.quantity,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final StoreProduct product;
  final int quantity;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  static const _height = 42.0;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _OutOfStockLabel(height: _height);
    }
    // Nothing in the basket yet: one wide Add.
    if (quantity <= 0) {
      return _AddButton(product: product, height: _height, onPressed: onAdd);
    }
    // In the basket: the control swaps to a stepper in the same spot.
    return _QuantityStepper(
      product: product,
      quantity: quantity,
      height: _height,
      onAdd: onAdd,
      onRemove: onRemove,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.product,
    required this.height,
    required this.onPressed,
  });

  final StoreProduct product;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: AppPalette.brand,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('add-to-cart-${product.id}'),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              const Text(
                'Add to basket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
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

/// `- qty +`, plus a one-tap shortcut to the checkout.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.product,
    required this.quantity,
    required this.height,
    required this.onAdd,
    required this.onRemove,
  });

  final StoreProduct product;
  final int quantity;
  final double height;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // At the shelf limit the plus is disabled, so the resident is told the
    // truth rather than being allowed to ask for something that is not there.
    final atLimit = quantity >= product.stock;
    return Row(
      children: [
        _StepButton(
          key: Key('cart-minus-${product.id}'),
          icon: Icons.remove_rounded,
          onTap: onRemove,
          height: height,
          tooltip: 'Remove one ${product.name}',
        ),
        // The count animates on change so the new quantity is noticed.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Container(
            key: ValueKey(quantity),
            width: 44,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.brandTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: AppPalette.brand,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _StepButton(
          key: Key('cart-plus-${product.id}'),
          icon: Icons.add_rounded,
          onTap: atLimit ? null : onAdd,
          height: height,
          tooltip: atLimit
              ? 'Only ${product.stock} left'
              : 'Add one more ${product.name}',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LineTotal(
            height: height,
            text: AppFormatters.currency(product.price * quantity),
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.height,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double height;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: height,
        height: height,
        child: Material(
          color: enabled ? AppPalette.brand : AppPalette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(
              icon,
              size: 19,
              color: enabled ? Colors.white : AppPalette.faint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Running total for this line, so the effect of the stepper is visible
/// without going back to the basket.
class _LineTotal extends StatelessWidget {
  const _LineTotal({required this.height, required this.text});

  final double height;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppPalette.mutedStrong,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OutOfStockLabel extends StatelessWidget {
  const _OutOfStockLabel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Text(
        'Out of stock',
        style: TextStyle(
          color: AppPalette.faint,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
