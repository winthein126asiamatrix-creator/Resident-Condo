import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/store/domain/entities/store_product.dart';
import 'package:test/core/errors/app_exception.dart';
import 'package:test/features/store/data/datasources/store_local_data_source.dart';

void main() {
  late StoreLocalDataSource dataSource;

  setUp(() => dataSource = StoreLocalDataSource());

  group('Store catalogue', () {
    test('carries the products residents actually asked for', () async {
      final products = await dataSource.getProducts();
      final byName = {for (final product in products) product.name: product};

      expect(byName["Lay's Potato Chips"]?.price, 2.50);
      expect(byName["Lay's Potato Chips"]?.isInStock, isTrue);
      expect(byName['Mineral Water 1.5L Pack']?.price, 4.00);
      expect(byName['Mineral Water 1.5L Pack']?.isInStock, isTrue);
      expect(byName['Fresh Milk 1L']?.price, 3.50);
      expect(byName['Fresh Milk 1L']?.isInStock, isTrue);
    });

    test('spreads the catalogue across every store category', () async {
      final products = await dataSource.getProducts();
      final categories = products.map((product) => product.category).toSet();

      expect(categories.length, StoreCategory.values.length);
    });

    test('derives the stock badge from the count, so they cannot disagree', () {
      final empty = _productAt(stock: 0);
      final low = _productAt(stock: 2);
      final healthy = _productAt(stock: 40);

      expect(empty.stockStatus, StoreStockStatus.outOfStock);
      expect(empty.isInStock, isFalse);
      expect(low.stockStatus, StoreStockStatus.lowStock);
      expect(healthy.stockStatus, StoreStockStatus.inStock);
      expect(healthy.maxPerOrder, 40);
    });

    test('every product carries real photography, not an icon', () async {
      final products = await dataSource.getProducts();
      for (final product in products) {
        expect(
          product.imageUrl,
          isNotEmpty,
          reason: '${product.name} has no photo',
        );
        expect(
          product.imageUrl,
          startsWith('https://'),
          reason: '${product.name} must reference a remote photo',
        );
        // A square crop keeps the photo matched to the card's 1:1 frame.
        expect(product.imageUrl, contains('fit=crop'));
      }
    });

    test('photo ids are unique, so no two products share one picture', () async {
      final products = await dataSource.getProducts();
      final ids = products.map((product) => product.imageUrl).toSet();
      expect(ids.length, products.length);
    });
  });

  group('The catalogue is read-only for residents', () {
    test('placing an order takes stock off the shelf but never adds to it', () async {
      final before = (await dataSource.getProducts()).firstWhere(
        (product) => product.id == 'store-lays-chips',
      );

      await dataSource.placeOrder(_order());

      final after = await dataSource.getProduct('store-lays-chips');
      expect(after!.stock, before.stock - 3);
      // The product itself is untouched, only its count moved.
      expect(after.name, before.name);
      expect(after.price, before.price);
    });

    test('the catalogue length never changes from a resident action', () async {
      final before = (await dataSource.getProducts()).length;
      await dataSource.placeOrder(_order());
      expect((await dataSource.getProducts()).length, before);
    });
  });

  group('Store orders', () {
    test('seeds a pending order in preparation', () async {
      final orders = await dataSource.getOrders();
      final order = orders.firstWhere((candidate) => candidate.id == 'ST-20260930-01');

      expect(order.items, hasLength(2));
      expect(order.itemCount, 3);
      expect(order.total, 9.00);
      expect(order.paymentStatus, StorePaymentStatus.pending);
      expect(order.status, StoreOrderStatus.preparing);
    });

    test('a placed order gets a reference in the ST-YYYYMMDD-NN form', () async {
      final placed = await dataSource.placeOrder(_order());
      expect(placed.id, matches(RegExp(r'^ST-\d{8}-\d{2}$')));
      expect(placed.status, StoreOrderStatus.submitted);
    });

    test('advances through the status flow in order', () async {
      var order = await dataSource.placeOrder(_order());

      order = await dataSource.updateOrderStatus(order, order.status.next!);
      expect(order.status, StoreOrderStatus.confirmed);

      order = await dataSource.updateOrderStatus(order, order.status.next!);
      expect(order.status, StoreOrderStatus.preparing);
    });

    test('the handover step depends on how the order is being delivered', () {
      final toDoor = _order();
      final toLobby = _order(deliveryMethod: StoreDeliveryMethod.lobbyPickup);

      expect(
        StoreOrderStatus.outForDelivery.timeline,
        contains(StoreOrderStatus.outForDelivery),
      );
      expect(
        StoreOrderStatus.readyForPickup.timeline,
        contains(StoreOrderStatus.readyForPickup),
      );
      // A doorstep order never shows a pick-up step and vice versa.
      expect(
        StoreOrderStatus.outForDelivery.timeline,
        isNot(contains(StoreOrderStatus.readyForPickup)),
      );
      expect(toDoor.deliveryMethod, StoreDeliveryMethod.doorstep);
      expect(toLobby.deliveryMethod, StoreDeliveryMethod.lobbyPickup);
    });

    test('an order can be called off only before it leaves the store', () {
      expect(StoreOrderStatus.submitted.canCancel, isTrue);
      expect(StoreOrderStatus.confirmed.canCancel, isTrue);
      expect(StoreOrderStatus.preparing.canCancel, isFalse);
      expect(StoreOrderStatus.outForDelivery.canCancel, isFalse);
      expect(StoreOrderStatus.completed.canCancel, isFalse);
    });

    test('finished statuses have no next step', () {
      expect(StoreOrderStatus.completed.next, isNull);
      expect(StoreOrderStatus.cancelled.next, isNull);
      expect(StoreOrderStatus.completed.isFinished, isTrue);
      expect(StoreOrderStatus.cancelled.isFinished, isTrue);
    });

    test('a payment update sticks to the order', () async {
      final placed = await dataSource.placeOrder(_order());
      expect(placed.paymentStatus, StorePaymentStatus.pending);

      final paid = await dataSource.updateOrderPayment(
        placed,
        StorePaymentStatus.paid,
      );
      expect(paid.paymentStatus, StorePaymentStatus.paid);
      expect(paid.isPaid, isTrue);

      final reloaded = await dataSource.getOrders();
      final stored = reloaded.firstWhere((order) => order.id == placed.id);
      expect(stored.paymentStatus, StorePaymentStatus.paid);
    });

    test('cancelling is refused once the order is out for handover', () async {
      final placed = await dataSource.placeOrder(_order());
      final preparing = await dataSource.updateOrderStatus(
        placed,
        StoreOrderStatus.preparing,
      );

      expect(
        () => dataSource.updateOrderStatus(
          preparing,
          StoreOrderStatus.cancelled,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('cancelling is allowed while the order is still inside the store', () async {
      final placed = await dataSource.placeOrder(_order());
      final cancelled = await dataSource.updateOrderStatus(
        placed,
        StoreOrderStatus.cancelled,
      );
      expect(cancelled.status, StoreOrderStatus.cancelled);
    });
  });

  group('The store fee is the order total', () {
    test('never folds delivery or goods into another charge', () {
      final order = _order();

      expect(order.subtotal, 9.00);
      expect(order.deliveryFee, 2.50);
      expect(order.total, 11.50);
      // The store fee is exactly what the resident owes for this order.
      expect(order.storeFee, order.total);
    });

    test('is settled independently of the order status', () {
      final pending = _order();
      final paid = _order(paymentStatus: StorePaymentStatus.paid);

      expect(pending.isPaid, isFalse);
      expect(paid.isPaid, isTrue);
      expect(paid.storeFee, pending.storeFee);
    });
  });
}

const _product = StoreProduct(
  id: 'store-lays-chips',
  name: 'Chips',
  description: 'Classic salted, 60g',
  category: StoreCategory.snacks,
  price: 2.50,
  stock: 24,
  unit: 'per pack',
);

StoreProduct _productAt({
  String id = 'sp-1',
  String name = 'Test item',
  int stock = 10,
}) {
  return StoreProduct(
    id: id,
    name: name,
    description: 'A test product',
    category: StoreCategory.snacks,
    price: 2.50,
    stock: stock,
    unit: 'per pack',
  );
}

StoreOrder _order({
  StoreDeliveryMethod deliveryMethod = StoreDeliveryMethod.doorstep,
  StorePaymentStatus paymentStatus = StorePaymentStatus.pending,
}) {
  return StoreOrder(
    id: '',
    items: const [
      StoreCartLine(product: _product, quantity: 2),
      StoreCartLine(product: _product, quantity: 1),
    ],
    deliveryMethod: deliveryMethod,
    deliveryLocation: 'Tower A · Unit 1205',
    deliveryTime: 'Today · 6:00 PM – 7:00 PM',
    status: StoreOrderStatus.submitted,
    paymentStatus: paymentStatus,
    subtotal: 9.00,
    deliveryFee: 2.50,
    total: 11.50,
    residentName: 'Alex Johnson',
    unitLabel: 'Tower A · 1205',
    placedOn: 'Sep 30, 2026',
  );
}
