import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_detail_app_bar.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_state_message.dart';
import '../../domain/entities/store_product.dart';
import '../controllers/store_controller.dart';
import '../widgets/store_cards.dart';
import '../widgets/store_product_card.dart';
import '../widgets/store_widgets.dart';

final _storeTabs = <AppSegmentedTab>[
  AppSegmentedTab(name: 'shop', label: 'Shop', icon: Icons.storefront_rounded),
  AppSegmentedTab(
    name: 'basket',
    label: 'Basket',
    icon: Icons.shopping_basket_rounded,
  ),
  AppSegmentedTab(
    name: 'orders',
    label: 'Orders',
    icon: Icons.receipt_long_rounded,
  ),
];

/// The Convenience Store: browse by aisle, fill a basket, follow the order.
///
/// The three tabs live in a page view so switching slides between them and each
/// tab keeps its own scroll position, instead of one list being torn down and
/// rebuilt under the resident's thumb.
class StorePage extends StatefulWidget {
  StorePage({super.key});

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
      duration: AppSegmentedTabs.slideDuration,
      curve: AppSegmentedTabs.slideCurve,
    );
  }

  /// Keeps the page view in step when the tab is changed from elsewhere, such
  /// as the basket badge in the app bar.
  void _syncFromController(StoreTab tab) {
    if (!_pages.hasClients || _pages.page == tab.index) {
      return;
    }
    // Started after this frame rather than during the build, so the strip can
    // follow the slide instead of jumping in step with the content.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients || _pages.page == tab.index) {
        return;
      }
      _pages.animateToPage(
        tab.index,
        duration: AppSegmentedTabs.slideDuration,
        curve: AppSegmentedTabs.slideCurve,
      );
    });
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
          SizedBox(width: 8.w),
        ],
      ),
      body: Obx(() {
        final tab = controller.tab.value;
        if (controller.isLoading.value && controller.products.isEmpty) {
          return Center(child: CircularProgressIndicator());
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
        return Column(
          children: [
            AppSegmentedTabs(
              tabs: _storeTabs,
              selectedIndex: controller.tab.value.index,
              pages: _pages,
              keyPrefix: 'store',
              onSelect: (index) => _selectTab(StoreTab.values[index]),
            ),
            Expanded(
              // Not scrollable by gesture: the strip is the only way between
              // tabs, so a swipe can never fight the list inside a tab.
              child: PageView(
                controller: _pages,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _StoreTabPage(
                    scrollKey: Key('store-scroll'),
                    onRefresh: controller.loadAll,
                    child: Column(children: _shop(context)),
                  ),
                  _StoreTabPage(
                    scrollKey: Key('store-basket-scroll'),
                    onRefresh: controller.loadAll,
                    child: Column(children: _basket(context)),
                  ),
                  _StoreTabPage(
                    scrollKey: Key('store-orders-scroll'),
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
      SizedBox(height: 16.h),
      _StoreSearch(controller: controller),
      SizedBox(height: 14.h),
      _CategoryRow(controller: controller),
      SizedBox(height: 16.h),
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
          AppSectionHeader(title: 'Results', count: products.length),
          SizedBox(height: 12.h),
        ],
        for (final product in products)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
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
      return [
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
      SizedBox(height: 14.h),
      StoreCheckoutSummaryCard(
        keyName: 'store-basket-summary',
        subtotal: controller.cartSubtotal,
        deliveryFee: controller.deliveryFee,
        total: controller.cartTotal,
        itemCount: controller.cartCount,
      ),
      SizedBox(height: 14.h),
      StoreFeeNotice(),
      SizedBox(height: 18.h),
      StoreCheckoutButton(controller: controller),
    ];
  }

  List<Widget> _orders(BuildContext context) {
    if (controller.orders.isEmpty) {
      return [
        AppStateMessage(
          title: 'No store orders yet',
          message:
              'Once you order from the Convenience Store it shows up here.',
          icon: Icons.receipt_long_outlined,
        ),
      ];
    }
    return [
      if (controller.outstandingStoreFee > 0) ...[
        AppCard(
          key: Key('store-outstanding-fee'),
          color: AppPalette.amberSoft,
          borderColor: Color(0xFFF2E0B8),
          child: Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Color(0xFFB45309)),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  '${AppFormatters.currency(controller.outstandingStoreFee)} of '
                  'Store Fee is still on your statement.',
                  style: TextStyle(
                    color: Color(0xFF7A4A0B),
                    fontSize: 12.5.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
      ],
      AppSectionHeader(title: 'Active', count: controller.activeOrders.length),
      SizedBox(height: 10.h),
      for (final order in controller.activeOrders)
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: StoreOrderTrackerListCard(
            order: order,
            onTap: () {
              controller.selectOrder(order);
              Get.toNamed(AppRoutes.storeOrderDetail, arguments: order);
            },
          ),
        ),
      if (controller.pastOrders.isNotEmpty) ...[
        SizedBox(height: 16.h),
        AppSectionHeader(title: 'History', count: controller.pastOrders.length),
        SizedBox(height: 10.h),
        for (final order in controller.pastOrders)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
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
  _StoreSearch({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return TextField(
      key: Key('store-search'),
      onChanged: controller.search,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: tokens.ink,
        fontSize: 14.5.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: 'Search the Convenience Store',
        hintStyle: TextStyle(
          color: tokens.faint,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: tokens.muted,
          size: 21,
        ),
        suffixIcon: Obx(() {
          if (controller.searchQuery.value.isEmpty) {
            return SizedBox.shrink();
          }
          return IconButton(
            key: Key('store-search-clear'),
            onPressed: () => controller.search(''),
            tooltip: 'Clear search',
            icon: Icon(
              Icons.close_rounded,
              size: 19,
              color: tokens.muted,
            ),
          );
        }),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 14),
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: Color(0x14000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: Color(0x14000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: tokens.brand, width: 1.4),
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
  _StoreTabPage({
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
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
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
  _StoreHero({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      color: tokens.brandTint,
      borderColor: tokens.brandSoft,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tokens.brand,
              borderRadius: BorderRadius.circular(17.r),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: tokens.onBrand,
              size: 26,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lobby store',
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${controller.products.length} products · '
                  'deliver to ${StoreController.doorstepLocation}',
                  style: TextStyle(
                    color: tokens.mutedStrong,
                    fontSize: 12.sp,
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

class _CategoryRow extends StatelessWidget {
  _CategoryRow({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        key: Key('store-category-scroll'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: BouncingScrollPhysics(),
        children: [
          _CategoryPill(
            key: Key('store-category-all'),
            label: 'All',
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
  _CategoryPill({
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
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? tokens.brand : tokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tokens.brand.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: Offset(0, 4),
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
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 200),
                  style: TextStyle(
                    color: selected ? tokens.onBrand : tokens.mutedStrong,
                    fontSize: 13.5.sp,
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
  _BasketLines({required this.controller});

  final StoreController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your basket',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              TextButton(
                key: Key('store-clear-basket'),
                onPressed: controller.clearCart,
                child: Text('Clear'),
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
  _BasketLine({required this.controller, required this.line});

  final StoreController controller;
  final StoreCartLine line;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          StoreProductImage(product: line.product, size: 46),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
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
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${line.quantity}',
                        key: Key('store-qty-${line.product.id}'),
                        style: TextStyle(
                          color: tokens.ink,
                          fontSize: 14.sp,
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
                    Spacer(),
                    Text(
                      AppFormatters.currency(line.lineTotal),
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      key: Key('store-remove-${line.product.id}'),
                      onPressed: () =>
                          controller.removeFromCart(line.product.id),
                      tooltip: 'Remove ${line.product.name}',
                      iconSize: 18,
                      color: tokens.muted,
                      icon: Icon(Icons.close_rounded),
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
  _QuantityButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Material(
      color: tokens.brandTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9.r)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: tokens.brand),
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
  final tokens = AppThemeTokens.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.canvas,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (sheetContext) => Obx(() {
      final product = controller.selectedProduct.value;
      if (product == null) {
        return SizedBox.shrink();
      }
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Center(child: StoreProductImage(product: product, size: 132)),
              SizedBox(height: 18.h),
              Text(
                product.name,
                key: Key('store-product-detail-name'),
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                product.category.label,
                style: TextStyle(color: tokens.muted, fontSize: 13.sp),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  StoreStockPill(status: product.stockStatus),
                  Spacer(),
                  Text(
                    AppFormatters.currency(product.price),
                    style: TextStyle(
                      color: tokens.brand,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Text(
                product.description,
                style: TextStyle(
                  color: tokens.mutedStrong,
                  fontSize: 13.5.sp,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                '${product.unit} · ${product.stock} on the shelf',
                style: TextStyle(color: tokens.faint, fontSize: 12.sp),
              ),
              SizedBox(height: 20.h),
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
