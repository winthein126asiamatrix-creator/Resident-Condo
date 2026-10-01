import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/store_product.dart';
import '../models/store_model.dart';

/// In-memory Convenience Store shelf and order book.
///
/// The catalogue is fixed for the resident app. Restocking and pricing are
/// management concerns, so there is deliberately no write path for products
/// here: residents can only read the shelf and act on their own orders.
class StoreLocalDataSource {
  StoreLocalDataSource()
      : _products = List<StoreProductModel>.of(_initialProducts),
        _orders = List<StoreOrderModel>.of(_initialOrders);

  final List<StoreProductModel> _products;
  final List<StoreOrderModel> _orders;

  static const _unitLabel = 'Tower A · Unit 1205';

  /// Server-side square crop at a sensible delivery size.
  ///
  /// Asking the CDN for a square means the photo already matches the 1:1 card
  /// frame, so nothing is stretched or letterboxed on screen.
  static const _photoQuery = '?w=800&h=800&fit=crop&auto=format&q=80';

  static final List<StoreProductModel> _initialProducts = [
    const StoreProductModel(
      id: 'store-lays-chips',
      name: "Lay's Potato Chips",
      category: StoreCategory.snacks,
      description:
          'Classic salted potato crisps, 60 g bag. The lobby shelf favourite.',
      price: 2.50,
      stock: 48,
      unit: 'per bag',
      brand: "Lay's",
      imageUrl:
          'https://images.unsplash.com/photo-1613919113640-25732ec5e61f$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-mineral-water',
      name: 'Mineral Water 1.5L Pack',
      category: StoreCategory.beverages,
      description:
          'Six 1.5 L bottles of still mineral water, chilled on arrival.',
      price: 4.00,
      stock: 30,
      unit: 'per pack',
      brand: 'Nestle Pure Life',
      imageUrl:
          'https://images.unsplash.com/photo-1602143407151-7111542de6e8$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-fresh-milk',
      name: 'Fresh Milk 1L',
      category: StoreCategory.freshProduce,
      description: 'Full cream milk, delivered chilled. Best within 3 days.',
      price: 3.50,
      stock: 24,
      unit: 'per carton',
      brand: 'Farm Fresh',
      imageUrl:
          'https://images.unsplash.com/photo-1550583724-b2692b85b150$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-instant-noodles',
      name: 'Instant Noodles 5-Pack',
      category: StoreCategory.instantFood,
      description: 'Chicken flavour instant noodles, five 75 g packets.',
      price: 5.25,
      stock: 26,
      unit: 'per pack',
      brand: 'Nissin',
      imageUrl:
          'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-sourdough',
      name: 'Sourdough Loaf',
      category: StoreCategory.instantFood,
      description: 'Baked this morning in the lobby bakery. Ask for it warm.',
      price: 4.80,
      stock: 6,
      unit: 'per loaf',
      brand: 'Lobby Bakery',
      imageUrl:
          'https://images.unsplash.com/photo-1613396874083-2d5fbe59ae79$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-coffee-beans',
      name: 'Coffee Beans 250g',
      category: StoreCategory.beverages,
      description: 'Medium roast arabica beans, ground to order on request.',
      price: 9.90,
      stock: 12,
      unit: 'per bag',
      brand: 'Highland Roasters',
      imageUrl:
          'https://images.unsplash.com/photo-1447933601403-0c6688de566e$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-orange-juice',
      name: 'Orange Juice 1L',
      category: StoreCategory.beverages,
      description: 'Not-from-concentrate orange juice.',
      price: 4.50,
      stock: 15,
      unit: 'per carton',
      brand: 'Sunny Grove',
      imageUrl:
          'https://images.unsplash.com/photo-1600271886742-f049cd451bba$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-apples',
      name: 'Red Apples (4 pack)',
      category: StoreCategory.freshProduce,
      description: 'Crisp seasonal apples, four to a pack.',
      price: 3.20,
      stock: 18,
      unit: 'per pack',
      imageUrl:
          'https://images.unsplash.com/photo-1619546813926-a78fa6372cd2$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-eggs',
      name: 'Free Range Eggs (6 pack)',
      category: StoreCategory.freshProduce,
      description: 'Free range eggs from the country farm.',
      price: 4.10,
      stock: 20,
      unit: 'per pack',
      imageUrl:
          'https://images.unsplash.com/photo-1639194335563-d56b83f0060c$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-toothpaste',
      name: 'Toothpaste 100ml',
      category: StoreCategory.household,
      description: 'Fluoride toothpaste, mint. Two tubes per pack.',
      price: 5.60,
      stock: 9,
      unit: 'per pack',
      imageUrl:
          'https://images.unsplash.com/photo-1654373535457-383a0a4d00f9$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-shampoo',
      name: 'Shampoo 400ml',
      category: StoreCategory.household,
      description: 'Gentle daily shampoo for normal hair.',
      price: 7.40,
      stock: 3,
      unit: 'per bottle',
      imageUrl:
          'https://images.unsplash.com/photo-1701992678972-d5a053ad0fb0$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-tissue',
      name: 'Kitchen Towels (2 roll)',
      category: StoreCategory.household,
      description: 'Heavy duty absorbent kitchen towels.',
      price: 3.90,
      stock: 22,
      unit: 'per pack',
      imageUrl:
          'https://images.unsplash.com/photo-1632334994199-cc2ba6538141$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-study-combo',
      name: 'Study Snack Combo',
      category: StoreCategory.combos,
      description:
          'Crisps, a bottled drink and a chocolate bar. Save 12% together.',
      price: 6.90,
      stock: 8,
      unit: 'per combo',
      imageUrl:
          'https://images.unsplash.com/photo-1578849278619-e73505e9610f$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-movie-night-combo',
      name: 'Movie Night Combo',
      category: StoreCategory.combos,
      description: 'Two snack packs and four drinks for a film night in.',
      price: 11.50,
      stock: 2,
      unit: 'per combo',
      imageUrl:
          'https://images.unsplash.com/photo-1623660053975-cf75a8be0908$_photoQuery',
    ),
    const StoreProductModel(
      id: 'store-breakfast-combo',
      name: 'Breakfast In A Box',
      category: StoreCategory.combos,
      description: 'Milk, juice, eggs and a bakery roll.',
      price: 12.40,
      stock: 0,
      unit: 'per box',
      imageUrl:
          'https://images.unsplash.com/photo-1623334044303-241021148842$_photoQuery',
    ),
  ];

  /// The order the briefing describes, so the list has a live example to track.
  static final List<StoreOrderModel> _initialOrders = [
    const StoreOrderModel(
      id: 'ST-20260930-01',
      items: [
        StoreCartLineModel(product: _lays, quantity: 2),
        StoreCartLineModel(product: _water, quantity: 1),
      ],
      deliveryMethod: StoreDeliveryMethod.doorstep,
      deliveryLocation: _unitLabel,
      deliveryTime: 'Today · 6:00 PM – 7:00 PM',
      status: StoreOrderStatus.preparing,
      paymentStatus: StorePaymentStatus.pending,
      subtotal: 9.00,
      deliveryFee: 0,
      total: 9.00,
      residentName: 'Alex Johnson',
      unitLabel: _unitLabel,
      placedOn: 'Sep 30, 2026',
      assignedTo: 'Delivery · Miguel',
    ),
    const StoreOrderModel(
      id: 'ST-20260928-02',
      items: [
        StoreCartLineModel(product: _milk, quantity: 2),
        StoreCartLineModel(product: _eggs, quantity: 1),
      ],
      deliveryMethod: StoreDeliveryMethod.lobbyPickup,
      deliveryLocation: 'Management store · Lobby',
      deliveryTime: 'Sep 28 · 5:00 PM – 6:00 PM',
      status: StoreOrderStatus.completed,
      paymentStatus: StorePaymentStatus.paid,
      subtotal: 11.10,
      deliveryFee: 0,
      total: 11.10,
      residentName: 'Alex Johnson',
      unitLabel: _unitLabel,
      placedOn: 'Sep 28, 2026',
      assignedTo: 'Lobby · Priya',
    ),
  ];

  // Named so the seeded orders can reference the same product instances.
  static const _lays = StoreProduct(
    id: 'store-lays-chips',
    name: "Lay's Potato Chips",
    category: StoreCategory.snacks,
    description: 'Classic salted potato crisps, 60 g bag.',
    price: 2.50,
    stock: 48,
    unit: 'per bag',
    brand: "Lay's",
    imageUrl:
        'https://images.unsplash.com/photo-1613919113640-25732ec5e61f$_photoQuery',
  );
  static const _water = StoreProduct(
    id: 'store-mineral-water',
    name: 'Mineral Water 1.5L Pack',
    category: StoreCategory.beverages,
    description: 'Six 1.5 L bottles of still mineral water.',
    price: 4.00,
    stock: 30,
    unit: 'per pack',
    brand: 'Nestle Pure Life',
    imageUrl:
        'https://images.unsplash.com/photo-1602143407151-7111542de6e8$_photoQuery',
  );
  static const _milk = StoreProduct(
    id: 'store-fresh-milk',
    name: 'Fresh Milk 1L',
    category: StoreCategory.freshProduce,
    description: 'Full cream milk, delivered chilled.',
    price: 3.50,
    stock: 24,
    unit: 'per carton',
    brand: 'Farm Fresh',
    imageUrl:
        'https://images.unsplash.com/photo-1550583724-b2692b85b150$_photoQuery',
  );
  static const _eggs = StoreProduct(
    id: 'store-eggs',
    name: 'Free Range Eggs (6 pack)',
    category: StoreCategory.freshProduce,
    description: 'Free range eggs from the country farm.',
    price: 4.10,
    stock: 20,
    unit: 'per pack',
    imageUrl:
        'https://images.unsplash.com/photo-1639194335563-d56b83f0060c$_photoQuery',
  );

  Future<List<StoreProductModel>> getProducts() async {
    return List<StoreProductModel>.unmodifiable(_products);
  }

  Future<List<StoreOrderModel>> getOrders() async {
    return List<StoreOrderModel>.unmodifiable(_orders);
  }

  Future<StoreProductModel?> getProduct(String id) async {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  /// Checks the shelf before committing, then takes the stock off it.
  Future<StoreOrderModel> placeOrder(StoreOrder order) async {
    if (order.items.isEmpty) {
      throw const AppException('Your basket is empty.');
    }
    for (final line in order.items) {
      final product = _findProduct(line.product.id);
      if (product == null) {
        throw AppException('${line.product.name} is no longer on the shelf.');
      }
      if (product.stock < line.quantity) {
        throw AppException('Only ${product.stock} left of ${product.name}.');
      }
    }
    for (final line in order.items) {
      final index = _products.indexWhere(
        (item) => item.id == line.product.id,
      );
      final product = _products[index];
      _products[index] = StoreProductModel(
        id: product.id,
        name: product.name,
        category: product.category,
        description: product.description,
        price: product.price,
        stock: product.stock - line.quantity,
        unit: product.unit,
        imagePath: product.imagePath,
        brand: product.brand,
        imageUrl: product.imageUrl,
      );
    }

    final created = StoreOrderModel(
      id: _nextOrderId(),
      items: order.items
          .map(
            (line) =>
                StoreCartLineModel(product: line.product, quantity: line.quantity),
          )
          .toList(),
      deliveryMethod: order.deliveryMethod,
      deliveryLocation: order.deliveryLocation,
      deliveryTime: order.deliveryTime,
      status: StoreOrderStatus.submitted,
      paymentStatus: order.paymentStatus,
      subtotal: order.subtotal,
      deliveryFee: order.deliveryFee,
      total: order.total,
      residentName: order.residentName,
      unitLabel: order.unitLabel,
      placedOn: order.placedOn,
    );
    _orders.insert(0, created);
    return created;
  }

  /// Moves an order along the pipeline. Cancelling is a resident action and is
  /// only allowed while the order is still inside the store.
  Future<StoreOrderModel> updateOrderStatus(
    StoreOrder order,
    StoreOrderStatus status,
  ) async {
    if (status == StoreOrderStatus.cancelled && !order.status.canCancel) {
      throw const AppException('This order can no longer be cancelled.');
    }
    return _replaceOrder(order.copyWith(status: status));
  }

  /// Settles or re-opens the store fee on an order.
  Future<StoreOrderModel> updateOrderPayment(
    StoreOrder order,
    StorePaymentStatus status,
  ) async {
    return _replaceOrder(order.copyWith(paymentStatus: status));
  }

  StoreProductModel? _findProduct(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  StoreOrderModel _replaceOrder(StoreOrder updated) {
    final index = _orders.indexWhere((order) => order.id == updated.id);
    if (index == -1) {
      throw const AppException('That store order could not be found.');
    }
    final model = StoreOrderModel(
      id: updated.id,
      items: updated.items
          .map(
            (line) =>
                StoreCartLineModel(product: line.product, quantity: line.quantity),
          )
          .toList(),
      deliveryMethod: updated.deliveryMethod,
      deliveryLocation: updated.deliveryLocation,
      deliveryTime: updated.deliveryTime,
      status: updated.status,
      paymentStatus: updated.paymentStatus,
      subtotal: updated.subtotal,
      deliveryFee: updated.deliveryFee,
      total: updated.total,
      residentName: updated.residentName,
      unitLabel: updated.unitLabel,
      placedOn: updated.placedOn,
      assignedTo: updated.assignedTo,
      storeFeeInvoiceItemKey: updated.storeFeeInvoiceItemKey,
    );
    _orders[index] = model;
    return model;
  }

  /// References are `ST-YYYYMMDD-NN`, numbered per day.
  String _nextOrderId() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final day =
        '${now.year}${two(now.month)}${two(now.day)}';
    final prefix = 'ST-$day-';
    final used = _orders
        .where((order) => order.id.startsWith(prefix))
        .map((order) => int.tryParse(order.id.substring(prefix.length)) ?? 0)
        .fold(0, (max, value) => value > max ? value : max);
    return '$prefix${two(used + 1)}';
  }
}
