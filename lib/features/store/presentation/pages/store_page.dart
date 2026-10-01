import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/store_product.dart';
import '../controllers/store_controller.dart';
import '../widgets/store_cards.dart';
import '../widgets/store_product_card.dart';
import '../widgets/store_widgets.dart';

/// The Convenience Store: browse by aisle, fill a basket, follow the order.
///
/// The three tabs live in a page view so switching slides between them and each
/// tab keeps its own scroll position, instead of one list being torn down and
/// rebuilt under the resident's thumb.
class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late final PageController _pages = PageController();
  final StoreController controller = Get.find<StoreController>();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Drives the strip and the page view from one place, so the highlight and the
  /// visible page can never disagree.
  void _selectTab(StoreTab tab) {
    if (controller.tab.value == tab) {
      return;
    }
    controller.selectTab(tab);
    _pages.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// Keeps the page view in step when the tab is changed from elsewhere, such
  /// as the basket badge in the app bar.
  void _syncFromController(StoreTab tab) {
    if (_pages.hasClients && _pages.page != tab.index) {
      _pages.jumpToPage(tab.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppDetailAppBar(
        title: 'Convenience Store',
        actions: [
          // Its own Obx, so the header count follows the basket the moment it
          // changes rather than waiting for the body to rebuild.
          Obx(
            () => StoreCartBadge(
              count: controller.cartCount,
              onTap: () => _selectTab(StoreTab.basket),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        final tab = controller.tab.value;
        if (controller.isLoading.value && controller.products.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.products.isEmpty) {
          return AppStateMessage(
            title: 'Unable to load the store',
            message: controller.errorMessage.value!,
            icon: Icons.storefront_outlined,
            actionLabel: 'Try again',
            onAction: controller.loadAll,
          );
        }
        _syncFromController(tab);
        return Column(          children: [
            _StoreTabs(controller: controller, onSelect: _selectTab),
            Expanded(
              // Not scrollable by gesture: the strip is the only way between
              // tabs, so a swipe can never fight the list inside a tab.
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StoreTabPage(
                    scrollKey: const Key('store-scroll'),
                    onRefresh: controller.loadAll,
                    child: Column(children: _shop(context)),
                  ),
                  _StoreTabPage(
                    scrollKey: const Key('store-basket-scroll'),
                    onRefresh: controller.loadAll,
                    child: Column(children: _basket(context)),
                  ),
                  _StoreTabPage(
                    scrollKey: const Key('store-orders-scroll'),
                    onRefresh: controller.loadAll,
                    child: Column(children: _orders(context)),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  List<Widget> _shop(BuildContext context) {
    final products = controller.visibleProducts;
    return [
      _StoreHero(controller: controller),
      const SizedBox(height: 16),
      _StoreSearch(controller: controller),
      const SizedBox(height: 14),
      _CategoryRow(controller: controller),
      const SizedBox(height: 16),
      if (products.isEmpty)
        AppStateMessage(
          title: controller.isFiltering
              ? 'Nothing matches'
              : 'Nothing on this shelf',
          message: controller.isFiltering
              ? 'Try a different search or another aisle.'
              : 'Ask the store team to restock this aisle.',
          icon: controller.isFiltering
              ? Icons.search_off_rounded
              : Icons.inventory_2_outlined,
          actionLabel: controller.isFiltering ? 'Clear search' : null,
          onAction: controller.isFiltering ? controller.clearFilters : null,
        )
      else ...[
        if (controller.isFiltering) ...[
          AppSectionHeader(
            title: 'Results',
            count: products.length,
          ),
          const SizedBox(height: 12),
        ],
        for (final product in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StoreProductCard(
              product: product,
              inCartQuantity: controller.quantityInCart(product.id),
              onAdd: () => _addToBasket(context, product),
              onRemove: () => controller.setCartQuantity(
                product.id,
                controller.quantityInCart(product.id) - 1,
              ),
              onOpen: () {
                controller.selectProduct(product);
                showStoreProductDetail(context, controller: controller);
              },
            ),
          ),
      ],
    ];
  }

  /// Adds to the basket and confirms it, so the tap always has a visible
  /// result even when the card's own stepper is what changed.
  void _addToBasket(BuildContext context, StoreProduct product) {
    final before = controller.quantityInCart(product.id);
    controller.addToCart(product);
    // addToCart refuses to go past the shelf, so only confirm a real change.
    if (controller.quantityInCart(product.id) > before) {
      showStoreAddedToBasket(
        context,
        product: product,
        quantity: controller.quantityInCart(product.id),
      );
    }
  }

  List<Widget> _basket(BuildContext context) {
    if (controller.cart.isEmpty) {
      return const [
        AppStateMessage(
          key: Key('store-basket-empty'),
          title: 'Your basket is empty',
          message: 'Add snacks, drinks or household essentials to get started.',
          icon: Icons.shopping_basket_outlined,
        ),
      ];
    }
    return [
      _BasketLines(controller: controller),
      const SizedBox(height: 14),
      StoreCheckoutSummaryCard(
        keyName: 'store-basket-summary',
        subtotal: controller.cartSubtotal,
        deliveryFee: controller.deliveryFee,
        total: controller.cartTotal,
        itemCount: controller.cartCount,
      ),
      const SizedBox(height: 14),
      const StoreFeeNotice(),
      const SizedBox(height: 18),
      StoreCheckoutButton(controller: controller),
    ];
  }

  List<Widget> _orders(BuildContext context) {
    if (controller.orders.isEmpty) {
      return const [
        AppStateMessage(
          title: 'No store orders yet',
          message: 'Once you order from the Convenience Store it shows up here.',
          icon: Icons.receipt_long_outlined,
        ),
      ];
    }
    return [
      if (controller.outstandingStoreFee > 0) ...[
        AppCard(
          key: const Key('store-outstanding-fee'),
          color: AppPalette.amberSoft,
          borderColor: const Color(0xFFF2E0B8),
          child: Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${AppFormatters.currency(controller.outstandingStoreFee)} of '
                  'Store Fee is still on your statement.',
                  style: const TextStyle(
                    color: Color(0xFF7A4A0B),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      AppSectionHeader(
        title: 'Active',
        count: controller.activeOrders.length,
      ),
      const SizedBox(height: 10),
      for (final order in controller.activeOrders)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: StoreOrderTrackerListCard(
            order: order,
            onTap: () {
              controller.selectOrder(order);
              Get.toNamed(AppRoutes.storeOrderDetail, arguments: order);
            },
          ),
        ),
      if (controller.pastOrders.isNotEmpty) ...[
        const SizedBox(height: 16),
        AppSectionHeader(
          title: 'History',
          count: controller.pastOrders.length,
        ),
        const SizedBox(height: 10),
        for (final order in controller.pastOrders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StoreOrderTrackerListCard(
              order: order,
              onTap: () {
                controller.selectOrder(order);
                Get.toNamed(AppRoutes.storeOrderDetail, arguments: order);
              },
            ),
          ),
      ],
    ];
  }
}

/// Search across the whole shop.
///
/// Matching is live, so typing narrows the shelf as the resident goes, and
/// clearing the field puts everything back.
class _StoreSearch extends StatelessWidget {
  const _StoreSearch({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('store-search'),
      onChanged: controller.search,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        color: AppPalette.ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: 'Search the Convenience Store',
        hintStyle: const TextStyle(
          color: AppPalette.faint,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppPalette.muted,
          size: 21,
        ),
        suffixIcon: Obx(() {
          if (controller.searchQuery.value.isEmpty) {
            return const SizedBox.shrink();
          }
          return IconButton(
            key: const Key('store-search-clear'),
            onPressed: () => controller.search(''),
            tooltip: 'Clear search',
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
              color: AppPalette.muted,
            ),
          );
        }),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0x14000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0x14000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppPalette.brand, width: 1.4),
        ),
      ),
    );
  }
}
/// One tab's scrollable body.
///
/// Wrapping keeps the key on the scroll view itself, so the visible tab is
/// addressable, and gives the page a stable identity across rebuilds so a basket
/// change does not reset the reader's place.
class _StoreTabPage extends StatelessWidget {
  const _StoreTabPage({
    required this.scrollKey,
    required this.onRefresh,
    required this.child,
  });

  final Key scrollKey;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: scrollKey,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          14,
          AppSpacing.gutter,
          32,
        ),
        children: [child],
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppPalette.brandTint,
      borderColor: AppPalette.brandSoft,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppPalette.brand,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lobby store',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.products.length} products · '
                  'deliver to ${StoreController.doorstepLocation}',
                  style: const TextStyle(
                    color: AppPalette.mutedStrong,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreTabs extends StatelessWidget {
  const _StoreTabs({required this.controller, required this.onSelect});

  final StoreController controller;
  final ValueChanged<StoreTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        12,
        AppSpacing.gutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppPalette.brandTint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (final tab in StoreTab.values)
              Expanded(
                child: GestureDetector(
                  key: Key('store-tab-${tab.name}'),
                  onTap: () => onSelect(tab),
                  // Opaque so the whole segment is tappable, not just the glyph
                  // the text happens to cover.
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: controller.tab.value == tab
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: controller.tab.value == tab
                          ? [
                              BoxShadow(
                                color: AppPalette.brand.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: controller.tab.value == tab
                            ? AppPalette.brand
                            : AppPalette.mutedStrong,
                      ),
                      child: Text(
                        tab.label,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        key: const Key('store-category-scroll'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          _CategoryPill(
            key: const Key('store-category-all'),
            label: 'All aisles',
            selected: controller.selectedCategory.value == null,
            onTap: () => controller.selectCategory(null),
          ),
          for (final category in StoreCategory.values)
            _CategoryPill(
              key: Key('store-category-${category.name}'),
              label: category.shortLabel,
              selected: controller.selectedCategory.value == category,
              onTap: () => controller.selectCategory(category),
            ),
        ],
      ),
    );
  }
}

/// Aisle pill.
///
/// The active pill inverts to the deep brand colour with white text and a soft
/// drop shadow, so the current aisle reads instantly. Inactive pills sit on a
/// pale surface with no border at all, which keeps the row calm and stops it
/// looking like a row of boxes.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppPalette.brand : AppPalette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.brand.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppPalette.mutedStrong,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: selected ? 0.1 : 0,
                  ),
                  child: Text(label, maxLines: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BasketLines extends StatelessWidget {
  const _BasketLines({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your basket',
                style: TextStyle(
                  color: AppPalette.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                key: const Key('store-clear-basket'),
                onPressed: controller.clearCart,
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final line in controller.cart)
            _BasketLine(controller: controller, line: line),
        ],
      ),
    );
  }
}

class _BasketLine extends StatelessWidget {
  const _BasketLine({required this.controller, required this.line});

  final StoreController controller;
  final StoreCartLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          StoreProductImage(product: line.product, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _QuantityButton(
                      key: Key('store-qty-down-${line.product.id}'),
                      icon: Icons.remove_rounded,
                      onTap: () => controller.setCartQuantity(
                        line.product.id,
                        line.quantity - 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${line.quantity}',
                        key: Key('store-qty-${line.product.id}'),
                        style: const TextStyle(
                          color: AppPalette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QuantityButton(
                      key: Key('store-qty-up-${line.product.id}'),
                      icon: Icons.add_rounded,
                      onTap: () => controller.setCartQuantity(
                        line.product.id,
                        line.quantity + 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      AppFormatters.currency(line.lineTotal),
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      key: Key('store-remove-${line.product.id}'),
                      onPressed: () => controller.removeFromCart(line.product.id),
                      tooltip: 'Remove ${line.product.name}',
                      iconSize: 18,
                      color: AppPalette.muted,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.brandTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: AppPalette.brand),
        ),
      ),
    );
  }
}


/// Larger product view, opened from a catalogue tile.
void showStoreProductDetail(
  BuildContext context, {
  required StoreController controller,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Obx(() {
      final product = controller.selectedProduct.value;
      if (product == null) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: StoreProductImage(product: product, size: 132),
              ),
              const SizedBox(height: 18),
              Text(
                product.name,
                key: const Key('store-product-detail-name'),
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.category.label,
                style: const TextStyle(color: AppPalette.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  StoreStockPill(status: product.stockStatus),
                  const Spacer(),
                  Text(
                    AppFormatters.currency(product.price),
                    style: const TextStyle(
                      color: AppPalette.brand,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                product.description,
                style: const TextStyle(
                  color: AppPalette.mutedStrong,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${product.unit} · ${product.stock} on the shelf',
                style: const TextStyle(color: AppPalette.faint, fontSize: 12),
              ),
              const SizedBox(height: 20),
              StoreCheckoutButton(
                controller: controller,
                addFirst: true,
                label: product.isInStock
                    ? 'Add to Cart · ${AppFormatters.currency(product.price)}'
                    : 'Out of stock',
              ),
            ],
          ),
        ),
      );
    }),
  );
}
