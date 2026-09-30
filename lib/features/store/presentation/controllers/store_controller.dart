import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../domain/entities/store_product.dart';
import '../../domain/usecases/store_usecases.dart';

/// What the resident is looking at inside the store.
enum StoreTab { shop, basket, orders }

extension StoreTabIndex on StoreTab {
  /// Position in the tab strip, used to drive the page view.
  int get index => StoreTab.values.indexOf(this);

  String get label {
    switch (this) {
      case StoreTab.shop:
        return 'Shop';
      case StoreTab.basket:
        return 'Basket';
      case StoreTab.orders:
        return 'Orders';
    }
  }
}

/// How a store fee gets settled.
enum StorePaymentChoice {
  /// Settled straight away at checkout.
  payNow,

  /// Left open and added to the resident's statement, to pay alongside their
  /// other charges.
  payWithStatement,
}

class StoreController extends GetxController {
  StoreController(this.useCases);

  /// Free over this basket value, which is why a delivery fee can be zero.
  static const freeDeliveryOver = 50.0;
  static const standardDeliveryFee = 2.50;
  static const doorstepLocation = 'Tower A · Unit 1205';
  static const lobbyLocation = 'Management store · Lobby';

  final StoreUseCases useCases;

  final products = <StoreProduct>[].obs;
  final orders = <StoreOrder>[].obs;
  final cart = <StoreCartLine>[].obs;

  final selectedCategory = Rxn<StoreCategory>();
  final selectedProduct = Rxn<StoreProduct>();
  final selectedOrder = Rxn<StoreOrder>();
  final searchQuery = ''.obs;

  final tab = StoreTab.shop.obs;
  final deliveryMethod = StoreDeliveryMethod.doorstep.obs;
  final paymentChoice = StorePaymentChoice.payNow.obs;
  final selectedMethod = Rxn<StorePaymentMethod>();
  final selectedSavedMethod = Rxn<StoreSavedMethod>();
  final deliveryTime = 'Today · 6:00 PM – 7:00 PM'.obs;

  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final isPaying = false.obs;
  final errorMessage = RxnString();

  /// Methods this resident has used before, offered alongside the full list.
  ///
  /// A short list on purpose: this is a convenience, not the main list.
  static const savedMethods = <StoreSavedMethod>[
    StoreSavedMethod(
      id: 'saved-card-4242',
      method: StorePaymentMethod.card,
      title: 'Visa ···· 4242',
      subtitle: 'Expires 08/29',
      isDefault: true,
    ),
    StoreSavedMethod(
      id: 'saved-kbz-09',
      method: StorePaymentMethod.kbzPay,
      title: 'KBZPay ···· 0912',
      subtitle: '09 77 261 1100',
    ),
    StoreSavedMethod(
      id: 'saved-wave-55',
      method: StorePaymentMethod.wavePay,
      title: 'WavePay ···· 5531',
      subtitle: '09 77 261 1100',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  // ---------------------------------------------------------------- catalogue

  /// Products matching the current aisle and search text.
  ///
  /// Both filters apply together, so typing in a chosen aisle narrows within
  /// that aisle rather than jumping back to the whole shop.
  List<StoreProduct> get visibleProducts {
    final category = selectedCategory.value;
    final query = searchQuery.value.trim().toLowerCase();
    return products.where((product) {
      if (category != null && product.category != category) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return product.name.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();
  }

  /// True when a search or aisle is narrowing the shelf, which the empty state
  /// uses to say so.
  bool get isFiltering =>
      searchQuery.value.trim().isNotEmpty || selectedCategory.value != null;

  /// Clears both filters.
  void clearFilters() {
    searchQuery.value = '';
    selectedCategory.value = null;
  }

  int get cartCount => cart.fold(0, (total, line) => total + line.quantity);

  double get cartSubtotal =>
      cart.fold(0, (total, line) => total + line.lineTotal);

  double get deliveryFee =>
      cart.isEmpty || cartSubtotal >= freeDeliveryOver ? 0 : standardDeliveryFee;

  /// What the resident pays: the goods plus delivery.
  double get cartTotal => cartSubtotal + deliveryFee;

  List<StoreOrder> get activeOrders => orders
      .where((order) => !order.status.isFinished)
      .toList();

  List<StoreOrder> get pastOrders => orders
      .where((order) => order.status.isFinished)
      .toList();

  /// Store fees still owed, which appear on the statement as their own line.
  double get outstandingStoreFee => orders
      .where((order) => order.paymentStatus == StorePaymentStatus.pending)
      .fold(0, (total, order) => total + order.storeFee);

  void selectTab(StoreTab value) => tab.value = value;

  void selectCategory(StoreCategory? category) =>
      selectedCategory.value = category;

  void selectProduct(StoreProduct product) {
    selectedProduct.value = _findProduct(product.id) ?? product;
    errorMessage.value = null;
  }

  void selectOrder(StoreOrder order) {
    selectedOrder.value = _findOrder(order.id) ?? order;
  }

  void selectDeliveryMethod(StoreDeliveryMethod method) {
    deliveryMethod.value = method;
    if (method == StoreDeliveryMethod.doorstep) {
      deliveryTime.value = 'Today · 6:00 PM – 7:00 PM';
    } else {
      deliveryTime.value = 'Today · 5:00 PM – 6:00 PM';
    }
  }

  void selectDeliveryTime(String value) => deliveryTime.value = value;

  void selectPaymentChoice(StorePaymentChoice choice) {
    paymentChoice.value = choice;
    // A method chosen for a different choice is not carried over, so the
    // button can never quote one the resident did not pick.
    if (choice != StorePaymentChoice.payNow) {
      selectedMethod.value = null;
      selectedSavedMethod.value = null;
    }
  }

  /// Picks a method to pay with, which may be a saved one or a new one.
  void selectMethod(
    StorePaymentMethod method, {
    StoreSavedMethod? saved,
  }) {
    paymentChoice.value = StorePaymentChoice.payNow;
    selectedMethod.value = method;
    selectedSavedMethod.value = saved;
    errorMessage.value = null;
  }

  /// Set when paying now but no method has been chosen yet, so the page can ask
  /// for one rather than quietly guessing.
  String? get paymentMethodError {
    if (paymentChoice.value != StorePaymentChoice.payNow) {
      return null;
    }
    if (selectedMethod.value == null) {
      return 'Choose how you want to pay.';
    }
    return null;
  }

  void search(String query) => searchQuery.value = query;

  // -------------------------------------------------------------------- cart

  Future<void> loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loadedProducts = await useCases.getProducts();
      final loadedOrders = await useCases.getOrders();
      products.assignAll(loadedProducts);
      orders.assignAll(loadedOrders);
      // Keep the basket in step with the shelf after a reload.
      cart.assignAll(
        cart
            .map((line) {
              final fresh = _findProduct(line.product.id);
              return fresh == null
                  ? null
                  : StoreCartLine(
                      product: fresh,
                      quantity: line.quantity.clamp(0, fresh.stock),
                    );
            })
            .whereType<StoreCartLine>(),
      );
      final product = selectedProduct.value;
      if (product != null) {
        selectedProduct.value = _findProduct(product.id) ?? product;
      }
      final order = selectedOrder.value;
      if (order != null) {
        selectedOrder.value = _findOrder(order.id) ?? order;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load the store.';
    } finally {
      isLoading.value = false;
    }
  }

  void addToCart(StoreProduct product, {int quantity = 1}) {
    final fresh = _findProduct(product.id) ?? product;
    if (!fresh.isInStock) {
      errorMessage.value = '${fresh.name} is out of stock.';
      return;
    }
    final index = cart.indexWhere((line) => line.key == fresh.id);
    final current = index == -1 ? 0 : cart[index].quantity;
    if (current + quantity > fresh.stock) {
      errorMessage.value = 'Only ${fresh.stock} left of ${fresh.name}.';
      return;
    }
    errorMessage.value = null;
    if (index == -1) {
      cart.add(StoreCartLine(product: fresh, quantity: quantity));
    } else {
      cart[index] = cart[index].copyWith(quantity: current + quantity);
    }
  }

  void removeFromCart(String productId) {
    cart.removeWhere((line) => line.key == productId);
  }

  void setCartQuantity(String productId, int quantity) {
    final index = cart.indexWhere((line) => line.key == productId);
    if (index == -1) {
      return;
    }
    if (quantity <= 0) {
      cart.removeAt(index);
      return;
    }
    final stock = cart[index].product.stock;
    cart[index] = cart[index].copyWith(quantity: quantity.clamp(1, stock));
  }

  void clearCart() => cart.clear();

  int quantityInCart(String productId) {
    for (final line in cart) {
      if (line.key == productId) {
        return line.quantity;
      }
    }
    return 0;
  }

  // ---------------------------------------------------------------- checkout

  /// Where the order is going, which depends on the delivery method.
  String get deliveryLocation => deliveryMethod.value ==
          StoreDeliveryMethod.doorstep
      ? doorstepLocation
      : lobbyLocation;

  /// An order can only be placed once there is something in the basket.
  bool get canCheckout => cart.isNotEmpty;

  /// The payments controller, when it is registered. Statement-paid store fees
  /// are written through it so the invoice and the order stay in step.
  PaymentController? get _paymentController {
    if (!Get.isRegistered<PaymentController>()) {
      return null;
    }
    return Get.find<PaymentController>();
  }

  /// Places the order, settling the Store Fee first when paying now.
  ///
  /// Passing [method] means the resident is paying at checkout: the order is
  /// created already marked Paid and never touches the statement. Without it
  /// the order is left Pending and the fee is billed to the statement.
  Future<StoreOrder?> checkout({
    required String residentName,
    required String unitLabel,
    StorePaymentMethod? method,
  }) async {
    if (cart.isEmpty) {
      errorMessage.value = 'Your basket is empty.';
      return null;
    }
    if (method != null) {
      isPaying.value = true;
    } else {
      isSubmitting.value = true;
    }
    errorMessage.value = null;
    try {
      final payNow = method != null;
      final order = await useCases.placeOrder(
        StoreOrder(
          id: '',
          items: cart
              .map(
                (line) => StoreCartLine(product: line.product, quantity: line.quantity),
              )
              .toList(),
          deliveryMethod: deliveryMethod.value,
          deliveryLocation: deliveryLocation,
          deliveryTime: deliveryTime.value,
          status: StoreOrderStatus.submitted,
          paymentStatus: payNow
              ? StorePaymentStatus.paid
              : StorePaymentStatus.pending,
          subtotal: cartSubtotal,
          deliveryFee: deliveryFee,
          total: cartTotal,
          residentName: residentName,
          unitLabel: unitLabel,
          placedOn: AppDates.format(DateTime.now()),
        ),
      );

      // Paying with the statement leaves the store fee open on the resident's
      // invoice, so it is picked up on the Outstanding Payments screen. The
      // order is already saved at this point, so a failure here has to unwind it
      // rather than leave a half-placed order behind. Paying at checkout needs
      // nothing further: the fee is already settled.
      var placed = order;
      if (!payNow) {
        final paymentController = _paymentController;
        if (paymentController == null) {
          placed = await _unwindPlacedOrder(order, StoreOrderStatus.cancelled);
          errorMessage.value =
              'Store orders are unavailable right now. Please try again.';
          return null;
        }
        try {
          await paymentController.addStoreFee(
            amount: placed.total,
            reference: placed.id,
          );
        } on AppException catch (error) {
          placed = await _unwindPlacedOrder(order, StoreOrderStatus.cancelled);
          errorMessage.value = error.message;
          return null;
        }
      }

      orders.insert(0, placed);
      selectedOrder.value = placed;
      clearCart();
      return placed;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to place this store order.';
      return null;
    } finally {
      isSubmitting.value = false;
      isPaying.value = false;
    }
  }

  /// Rolls a just-saved order back to a status the resident can see, so a
  /// failure part-way through checkout never leaves a phantom order behind.
  Future<StoreOrder> _unwindPlacedOrder(
    StoreOrder order,
    StoreOrderStatus status,
  ) async {
    try {
      return await useCases.updateOrderStatus(order, status);
    } on AppException {
      return order.copyWith(status: status);
    }
  }

  // ------------------------------------------------------------------ orders

  /// A resident can call off their own order, but only while it is still
  /// inside the store. Everything else on an order is the store's to do.
  Future<StoreOrder?> cancelOrder(StoreOrder order) async {
    if (!order.status.canCancel) {
      errorMessage.value = 'This order can no longer be cancelled.';
      return null;
    }
    return _runOrder(
      order,
      () => useCases.updateOrderStatus(order, StoreOrderStatus.cancelled),
    );
  }

  /// Settles an order that was left on the statement.
  Future<StoreOrder?> markOrderPaid(StoreOrder order) => _runOrder(
    order,
    () => useCases.updateOrderPayment(order, StorePaymentStatus.paid),
  );

  Future<StoreOrder?> _runOrder(
    StoreOrder order,
    Future<StoreOrder> Function() action,
  ) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await action();
      final index = orders.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        orders[index] = updated;
      }
      selectedOrder.value = updated;
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to update this store order.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  StoreProduct? _findProduct(String id) {
    for (final product in products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  StoreOrder? _findOrder(String id) {
    for (final order in orders) {
      if (order.id == id) {
        return order;
      }
    }
    return null;
  }
}
