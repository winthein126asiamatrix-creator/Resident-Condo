import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:test/app/routes/app_routes.dart';
import 'package:test/app/theme/app_theme.dart';
import 'package:test/core/utils/app_formatters.dart';
import 'package:test/core/widgets/app_primary_action.dart';
import 'package:test/features/payments/data/datasources/payment_local_data_source.dart';
import 'package:test/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:test/features/payments/domain/usecases/payment_usecases.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';
import 'package:test/features/store/domain/entities/store_product.dart';
import 'package:test/features/store/presentation/bindings/store_binding.dart';
import 'package:test/features/store/presentation/controllers/store_controller.dart';
import 'package:test/features/store/presentation/pages/store_checkout_page.dart';
import 'package:test/features/store/presentation/pages/store_order_detail_page.dart';
import 'package:test/features/store/presentation/pages/store_page.dart';

/// Walks the whole Convenience Store: browse, basket, checkout, then track the order.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  /// The store plus a payments controller, so statement-paid store fees have
  /// somewhere to land.
  Future<void> pumpStore(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const StorePage(),
        initialBinding: StoreBinding(),
        getPages: [
          GetPage<dynamic>(
            name: AppRoutes.storeCheckout,
            page: () => const StoreCheckoutPage(),
            binding: StoreBinding(),
          ),
          GetPage<dynamic>(
            name: AppRoutes.storeOrderDetail,
            page: () => StoreOrderDetailPage(
              order: Get.arguments as StoreOrder,
            ),
            binding: StoreBinding(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // Payments register separately in the real app, so a statement-paid store
    // fee needs the controller here too.
    if (!Get.isRegistered<PaymentController>()) {
      Get.put(PaymentController(PaymentUseCases(PaymentRepositoryImpl(PaymentLocalDataSource()))));
    }
    await tester.pumpAndSettle();
  }

  /// Scrolls the checkout page until [target] is genuinely on screen.
  ///
  /// Merely being built is not enough: a long list builds the next widget just
  /// past the fold, where a tap would miss it.
  Future<void> scrollCheckoutTo(WidgetTester tester, Finder target) async {
    final scroll = find.byKey(const Key('store-checkout-scroll'));
    for (var i = 0; i < 15; i++) {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target.first);
        await tester.pumpAndSettle();
        if (target.first.hitTestable().evaluate().isNotEmpty) {
          return;
        }
      }
      await tester.drag(scroll, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
  }

  /// Scrolls whatever scrollable currently holds [target] until it is on
  /// screen. Used for the long pages and the product sheet, where the control
  /// can sit below the fold.
  Future<void> bringIntoView(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 12; i++) {
      if (target.evaluate().isEmpty) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
        await tester.pumpAndSettle();
        continue;
      }
      await tester.ensureVisible(target.first);
      await tester.pumpAndSettle();
      if (target.first.hitTestable().evaluate().isNotEmpty) {
        return;
      }
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapByKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await bringIntoView(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// The basket lines and the checkout button only exist on the basket tab, so
  /// tests that touch them have to go there first.
  Future<void> goToBasket(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('store-tab-basket')));
    await tester.pumpAndSettle();
  }

  /// Scrolls the basket down to the checkout button, which sits below the
  /// summary card.
  Future<void> goToCheckout(WidgetTester tester) async {
    await goToBasket(tester);
    await tapByKey(tester, 'store-checkout');
  }

  testWidgets('browses, filters and adds a product to the basket', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    expect(controller.products, isNotEmpty);
    expect(find.text("Lay's Potato Chips"), findsOneWidget);

    // Filtering narrows the shelf to one aisle.
    controller.selectCategory(StoreCategory.beverages);
    await tester.pumpAndSettle();
    expect(find.text('Mineral Water 1.5L Pack'), findsOneWidget);
    expect(find.text("Lay's Potato Chips"), findsNothing);

    controller.selectCategory(null);
    await tester.pumpAndSettle();

    final add = find.byKey(const Key('add-to-cart-store-lays-chips'));
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(controller.cartCount, 1);
    expect(controller.cartSubtotal, 2.50);
  });

  testWidgets('a second add of the same product raises the quantity',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();

    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    // The second one comes off the stepper, which has replaced the Add button.
    await tapByKey(tester, 'cart-plus-store-lays-chips');

    expect(controller.cartCount, 2);
    expect(controller.cartSubtotal, 5.00);
  });

  testWidgets('an out of stock product cannot be added', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final soldOut = controller.products.firstWhere(
      (product) => product.stock == 0,
      orElse: () => controller.products.first,
    );
    if (soldOut.stock == 0) {
      controller.addToCart(soldOut);
      expect(controller.cartCount, 0);
      expect(controller.errorMessage.value, contains('out of stock'));
    }
  });

  testWidgets('the basket cannot be pushed past the stock on the shelf',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final scarce = controller.products.firstWhere(
      (product) => product.stock > 0 && product.stock <= 3,
    );

    for (var i = 0; i < scarce.stock + 2; i++) {
      controller.addToCart(scarce);
    }

    expect(controller.quantityInCart(scarce.id), scarce.stock);
    expect(controller.errorMessage.value, contains('left'));
  });

  testWidgets('quantity controls and removal keep the basket consistent',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    // The Add button is gone now, so the second unit comes off the stepper.
    await tapByKey(tester, 'cart-plus-store-lays-chips');
    expect(controller.cartCount, 2);

    await goToBasket(tester);
    await tapByKey(tester, 'store-qty-down-store-lays-chips');
    expect(controller.cartCount, 1);

    await tapByKey(tester, 'store-remove-store-lays-chips');
    expect(controller.cart, isEmpty);
    expect(controller.canCheckout, isFalse);
  });

  testWidgets('delivery is free above the threshold and priced below it',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();

    final cheap = controller.products.firstWhere(
      (product) => product.stock > 0 && product.price < StoreController.freeDeliveryOver,
    );
    controller.addToCart(cheap);
    expect(controller.deliveryFee, StoreController.standardDeliveryFee);
    expect(
      controller.cartTotal,
      closeTo(controller.cartSubtotal + StoreController.standardDeliveryFee, 0.001),
    );

    // Fill the basket past the free-delivery line.
    final total = controller.cartSubtotal;
    for (final product in controller.products) {
      if (total >= StoreController.freeDeliveryOver) break;
      if (product.id == cheap.id) continue;
      controller.addToCart(product);
    }
    expect(controller.cartSubtotal, greaterThanOrEqualTo(StoreController.freeDeliveryOver));
    expect(controller.deliveryFee, 0);
    expect(controller.cartTotal, controller.cartSubtotal);
  });

  testWidgets('the delivery method decides where the order goes',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');

    expect(controller.deliveryMethod.value, StoreDeliveryMethod.doorstep);
    expect(controller.deliveryLocation, StoreController.doorstepLocation);

    controller.selectDeliveryMethod(StoreDeliveryMethod.lobbyPickup);
    await tester.pumpAndSettle();
    expect(controller.deliveryLocation, StoreController.lobbyLocation);
  });

  testWidgets('an empty basket offers no way to check out', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    expect(controller.canCheckout, isFalse);

    await goToBasket(tester);
    expect(find.text('Your basket is empty'), findsOneWidget);
    // No checkout button, so there is nothing to accidentally submit.
    expect(find.byKey(const Key('store-checkout')), findsNothing);
  });

  testWidgets('choosing a delivery slot updates the order', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);


    final slot = 'Today · 7:00 PM – 8:00 PM';
    await scrollCheckoutTo(tester, find.text(slot));
    await tester.tap(find.text(slot));
    await tester.pumpAndSettle();
    expect(controller.deliveryTime.value, slot);
  });

  testWidgets('paying at checkout settles the store fee there and then',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);

    // Paying now needs a method before the button will act.
    await tapByKey(tester, 'store-method-kbzPay');

    final place = find.byKey(const Key('store-place-order'));
    await scrollCheckoutTo(tester, place);
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pay ').last);
    await tester.pumpAndSettle();

    final order = controller.orders.first;
    expect(order.paymentStatus, StorePaymentStatus.paid);
    expect(order.status, StoreOrderStatus.submitted);
    // The order total is the store fee, kept on the order.
    expect(order.storeFee, order.total);
    // A paid order is never added to the statement.
    expect(find.textContaining('Statement'), findsNothing);
  });

  testWidgets('paying with the statement leaves the store fee outstanding',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);


    controller.selectPaymentChoice(StorePaymentChoice.payWithStatement);
    await tester.pumpAndSettle();

    final place = find.byKey(const Key('store-place-order'));
    await scrollCheckoutTo(tester, place);
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    final order = controller.orders.first;
    expect(order.paymentStatus, StorePaymentStatus.pending);
    expect(order.isPaid, isFalse);
  });

  testWidgets('placing an order empties the basket', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    expect(controller.cart, isNotEmpty);

    await goToCheckout(tester);
    // Settle on the statement, which is the path with no method to pick.
    controller.selectPaymentChoice(StorePaymentChoice.payWithStatement);
    await tester.pumpAndSettle();

    final place = find.byKey(const Key('store-place-order'));
    await scrollCheckoutTo(tester, place);
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(controller.cart, isEmpty);
    expect(controller.canCheckout, isFalse);
  });

  /// Scrolls the checkout page until the payment method list is on screen,
  /// since it sits well below the delivery section.
  Future<void> scrollToPaymentMethods(WidgetTester tester) async {
    await scrollCheckoutTo(tester, find.text('Payment method'));
  }

  testWidgets('paying now asks for a method before it will charge',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);

    controller.selectPaymentChoice(StorePaymentChoice.payNow);
    await tester.pumpAndSettle();
    await scrollToPaymentMethods(tester);
    expect(find.text('Payment method'), findsOneWidget);

    // The prompt sits under the button, so bring that into view too.
    await scrollCheckoutTo(tester, find.byKey(const Key('store-place-order')));
    expect(find.byKey(const Key('store-method-required')), findsOneWidget);
    // Until one is picked the button is out of reach, rather than acting and
    // charging nothing.
    final button = tester.widget<AppPrimaryAction>(
      find.byKey(const Key('store-place-order')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('every payment method is offered', (tester) async {
    await pumpStore(tester);
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);
    await scrollToPaymentMethods(tester);

    for (final method in StorePaymentMethod.values) {
      expect(
        find.byKey(Key('store-method-${method.name}')),
        findsOneWidget,
        reason: '${method.label} is missing from the list',
      );
    }
    expect(StorePaymentMethod.values, hasLength(4));
    expect(StoreController.savedMethods, isNotEmpty);
  });

  testWidgets('a saved method can be picked', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);
    await scrollToPaymentMethods(tester);

    final saved = StoreController.savedMethods.firstWhere(
      (method) => method.isDefault,
    );
    await tapByKey(tester, 'store-method-saved-${saved.id}');

    expect(controller.selectedSavedMethod.value?.id, saved.id);
    expect(controller.selectedMethod.value, saved.method);
  });

  testWidgets('the button quotes the exact total and the chosen method',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);
    await scrollToPaymentMethods(tester);

    await tapByKey(tester, 'store-method-kbzPay');
    await scrollCheckoutTo(tester, find.byKey(const Key('store-place-order')));
    final total = AppFormatters.currency(controller.cartTotal);
    expect(
      find.text('Pay $total via KBZPay'),
      findsOneWidget,
      reason: 'the button must name the amount and the method',
    );

    await tapByKey(tester, 'store-method-wavePay');
    await scrollCheckoutTo(tester, find.byKey(const Key('store-place-order')));
    expect(find.text('Pay $total via WavePay'), findsOneWidget);
  });

  testWidgets('a successful payment marks the order paid and skips the statement',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final payments = Get.find<PaymentController>();
    final openBefore = payments.outstandingBalance;

    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);
    await scrollToPaymentMethods(tester);
    await tapByKey(tester, 'store-method-card');

    final place = find.byKey(const Key('store-place-order'));
    await scrollCheckoutTo(tester, place);
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pay ').last);
    await tester.pumpAndSettle();

    final order = controller.orders.first;
    expect(order.paymentStatus, StorePaymentStatus.paid);
    expect(order.isPaid, isTrue);
    // Paid at checkout means nothing was added to the statement.
    expect(payments.outstandingBalance, closeTo(openBefore, 0.001));
  });

  testWidgets('switching to the statement hides the method list',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);
    await scrollToPaymentMethods(tester);

    await tapByKey(tester, 'store-method-kbzPay');
    expect(find.text('Payment method'), findsOneWidget);

    controller.selectPaymentChoice(StorePaymentChoice.payWithStatement);
    await tester.pumpAndSettle();

    // The method picked for pay now is not carried over to the statement.
    expect(controller.selectedMethod.value, isNull);
    expect(controller.selectedSavedMethod.value, isNull);
  });

  testWidgets('the order details can be left again', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    controller.selectPaymentChoice(StorePaymentChoice.payWithStatement);
    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await goToCheckout(tester);

    final place = find.byKey(const Key('store-place-order'));
    await scrollCheckoutTo(tester, place);
    await tester.tap(place);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(find.text('Order details'), findsOneWidget);

    // Placing an order must not strand the resident on the order screen: the
    // store has to stay underneath so back still leads somewhere.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Order details'), findsNothing);
    expect(find.text('Convenience Store'), findsOneWidget);
  });

  testWidgets('an order shows its status and what was bought', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final seeded = controller.orders.firstWhere(
      (order) => order.id == 'ST-20260930-01',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: StoreOrderDetailPage(order: seeded),
        initialBinding: StoreBinding(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('store-order-id')), findsOneWidget);
    expect(find.text('Preparing'), findsWidgets);
    // A store fee is always spelled out as its own charge on the order, so
    // scroll down to where the notice sits.
    final notice = find.byKey(const Key('store-fee-notice'));
    await bringIntoView(tester, notice);
    expect(notice, findsOneWidget);
  });

  testWidgets('an order cannot be cancelled once it leaves the store',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final preparing = controller.orders.firstWhere(
      (order) => order.id == 'ST-20260930-01',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: StoreOrderDetailPage(order: preparing),
        initialBinding: StoreBinding(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('store-order-cancel')), findsNothing);
    // Nor is there any way for a resident to move the order along the
    // pipeline: that is the store's job, not the customer's.
    expect(find.byKey(const Key('store-order-handover')), findsNothing);
    expect(find.byKey(const Key('store-order-advance')), findsNothing);
    expect(find.textContaining('Mark out for delivery'), findsNothing);
    expect(find.textContaining('Move to'), findsNothing);
  });

  testWidgets('a resident can cancel their own order before handover',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    // A fresh order is still `submitted`, which is cancellable. The seeded
    // orders are already preparing and completed, which are not.
    controller.addToCart(controller.products.first);
    final placed = await controller.checkout(
      residentName: 'Alex Johnson',
      unitLabel: controller.deliveryLocation,
    );
    expect(placed, isNotNull);
    expect(placed!.status.canCancel, isTrue);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: StoreOrderDetailPage(order: placed),
        initialBinding: StoreBinding(),
      ),
    );
    await tester.pumpAndSettle();

    final cancel = find.byKey(const Key('store-order-cancel'));
    await bringIntoView(tester, cancel);
    expect(cancel, findsOneWidget);

    await tester.tap(cancel);
    await tester.pumpAndSettle();
    // Cancelling is confirmed rather than happening on a single tap.
    await tester.tap(find.text('Cancel order').last);
    await tester.pumpAndSettle();

    final updated = controller.orders.firstWhere(
      (order) => order.id == placed.id,
    );
    expect(updated.status, StoreOrderStatus.cancelled);
  });

  testWidgets('a pending store fee can be paid from the order',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final pending = controller.orders.firstWhere(
      (order) => order.paymentStatus == StorePaymentStatus.pending,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: StoreOrderDetailPage(order: pending),
        initialBinding: StoreBinding(),
      ),
    );
    await tester.pumpAndSettle();

    await tapByKey(tester, 'store-order-pay-now');

    final updated = controller.orders.firstWhere(
      (order) => order.id == pending.id,
    );
    expect(updated.paymentStatus, StorePaymentStatus.paid);
  });

  testWidgets('the resident view has no staff entry point', (tester) async {
    await pumpStore(tester);

    // No way in to catalogue management, restocking or order dispatch.
    expect(find.byKey(const Key('store-staff-entry')), findsNothing);
    expect(find.text('Store staff'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add a product'), findsNothing);
    expect(find.text('Edit product'), findsNothing);
  });

  testWidgets('search narrows the shelf as the resident types', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final all = controller.visibleProducts.length;

    await tester.enterText(find.byKey(const Key('store-search')), 'milk');
    await tester.pumpAndSettle();

    expect(controller.isFiltering, isTrue);
    expect(controller.visibleProducts, isNotEmpty);
    expect(controller.visibleProducts.length, lessThan(all));
    for (final product in controller.visibleProducts) {
      final haystack =
          '${product.name} ${product.brand} ${product.description}'.toLowerCase();
      expect(haystack, contains('milk'));
    }
  });

  testWidgets('search matches on brand as well as name', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();

    // "Nissin" is the brand on the noodles, not part of the product name.
    await tester.enterText(find.byKey(const Key('store-search')), 'nissin');
    await tester.pumpAndSettle();

    expect(controller.visibleProducts, isNotEmpty);
    expect(
      controller.visibleProducts.map((product) => product.brand),
      contains('Nissin'),
    );
  });

  testWidgets('a search with no matches says so and can be cleared',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();

    await tester.enterText(find.byKey(const Key('store-search')), 'zzzz');
    await tester.pumpAndSettle();

    expect(controller.visibleProducts, isEmpty);
    expect(find.text('Nothing matches'), findsOneWidget);
    expect(find.byKey(const Key('add-to-cart-store-lays-chips')), findsNothing);

    await tapByKey(tester, 'store-search-clear');
    expect(controller.searchQuery.value, isEmpty);
    expect(controller.visibleProducts, isNotEmpty);
  });

  testWidgets('search and the aisle filter narrow together', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();

    controller.selectCategory(StoreCategory.beverages);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('store-search')), 'water');
    await tester.pumpAndSettle();

    for (final product in controller.visibleProducts) {
      expect(product.category, StoreCategory.beverages);
      expect(product.name.toLowerCase(), contains('water'));
    }
    expect(controller.visibleProducts, isNotEmpty);
  });

  testWidgets('a search that cannot match the aisle comes up empty',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();

    // Crisps live in snacks, so asking for crisps while in drinks finds nothing.
    controller.selectCategory(StoreCategory.beverages);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('store-search')), 'chips');
    await tester.pumpAndSettle();

    expect(controller.visibleProducts, isEmpty);
    expect(find.text('Nothing matches'), findsOneWidget);
  });

  testWidgets('the card swaps Add for a live quantity stepper', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    const id = 'store-lays-chips';

    // Before: one wide Add button, no stepper.
    expect(find.byKey(const Key('add-to-cart-$id')), findsOneWidget);
    expect(find.byKey(const Key('cart-plus-$id')), findsNothing);

    await tapByKey(tester, 'add-to-cart-$id');

    // After: the stepper replaces it in place.
    expect(find.byKey(const Key('add-to-cart-$id')), findsNothing);
    expect(find.byKey(const Key('cart-plus-$id')), findsOneWidget);
    expect(find.byKey(const Key('cart-minus-$id')), findsOneWidget);
    expect(controller.cartCount, 1);
  });

  testWidgets('the stepper drives the basket count and the total live',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    const id = 'store-lays-chips';

    await tapByKey(tester, 'add-to-cart-$id');
    expect(controller.cartCount, 1);
    expect(controller.cartTotal, closeTo(2.50 + StoreController.standardDeliveryFee, 0.001));

    await tapByKey(tester, 'cart-plus-$id');
    await tester.pumpAndSettle();
    expect(controller.cartCount, 2);
    expect(controller.cartTotal, closeTo(5.00 + StoreController.standardDeliveryFee, 0.001));

    await tapByKey(tester, 'cart-minus-$id');
    await tester.pumpAndSettle();
    expect(controller.cartCount, 1);
    expect(controller.cartTotal, closeTo(2.50 + StoreController.standardDeliveryFee, 0.001));
  });

  testWidgets('the basket badge in the header follows the stepper',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();

    // No count is shown while the basket is empty.
    expect(find.text('0'), findsNothing);

    await tapByKey(tester, 'add-to-cart-store-lays-chips');
    await tapByKey(tester, 'cart-plus-store-lays-chips');
    await tester.pumpAndSettle();

    expect(controller.cartCount, 2);
    // The badge in the app bar carries the live count.
    expect(
      find.descendant(
        of: find.byKey(const Key('store-cart-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('adding to the basket is confirmed on screen', (tester) async {
    await pumpStore(tester);

    await tapByKey(tester, 'add-to-cart-store-lays-chips');

    expect(find.byKey(const Key('store-added-snackbar')), findsOneWidget);
    expect(find.textContaining('Added to your basket'), findsOneWidget);
  });

  testWidgets('a sold out product cannot be added', (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    final soldOut = controller.products.firstWhere(
      (product) => product.stock == 0,
    );

    final card = find.byKey(Key('store-product-${soldOut.id}'));
    // The card may be below the fold, so scroll it in before inspecting.
    for (var i = 0; i < 15 && card.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byKey(const Key('store-scroll')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
    }

    expect(card, findsOneWidget);
    // A sold-out product has no Add button at all, so it cannot be confirmed
    // or added by mistake.
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(Key('add-to-cart-${soldOut.id}')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text('Out of stock')),
      findsWidgets,
    );
  });

  testWidgets('a product card shows a photo, a price and a stock badge',
      (tester) async {
    await pumpStore(tester);
    final card = find.byKey(const Key('store-product-store-lays-chips'));
    await bringIntoView(tester, card);

    // Real photography, framed in a square.
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(const Key('store-photo-store-lays-chips')),
      ),
      findsOneWidget,
    );
    expect(find.text("Lay's Potato Chips"), findsOneWidget);
    expect(find.text(r'$2.50'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('In Stock')),
      findsOneWidget,
    );
  });

  testWidgets('the plus on a stepper is disabled at the shelf limit',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    // Shampoo is seeded with only 3 left.
    final scarce = controller.products.firstWhere(
      (product) => product.stock == 3,
    );

    await tapByKey(tester, 'add-to-cart-${scarce.id}');
    for (var i = 1; i < scarce.stock; i++) {
      await tapByKey(tester, 'cart-plus-${scarce.id}');
    }
    await tester.pumpAndSettle();
    expect(controller.quantityInCart(scarce.id), scarce.stock);

    // At the limit the plus is inert rather than letting the basket overshoot.
    await tapByKey(tester, 'cart-plus-${scarce.id}');
    await tester.pumpAndSettle();
    expect(controller.quantityInCart(scarce.id), scarce.stock);
  });

  testWidgets('taking the last one off drops the line and restores Add',
      (tester) async {
    await pumpStore(tester);
    final controller = Get.find<StoreController>();
    const id = 'store-lays-chips';

    await tapByKey(tester, 'add-to-cart-$id');
    expect(find.byKey(const Key('cart-minus-$id')), findsOneWidget);

    await tapByKey(tester, 'cart-minus-$id');
    await tester.pumpAndSettle();

    expect(controller.cartCount, 0);
    expect(find.byKey(const Key('add-to-cart-$id')), findsOneWidget);
    expect(find.byKey(const Key('cart-minus-$id')), findsNothing);
  });
}
