/// Aisle the product sits in.
enum StoreCategory {
  snacks,
  beverages,
  instantFood,
  freshProduce,
  household,
  combos,
}

extension StoreCategoryLabel on StoreCategory {
  String get label {
    switch (this) {
      case StoreCategory.snacks:
        return 'Snacks & Sweets';
      case StoreCategory.beverages:
        return 'Beverages & Drinks';
      case StoreCategory.instantFood:
        return 'Instant Food & Bakery';
      case StoreCategory.freshProduce:
        return 'Fresh Produce & Dairy';
      case StoreCategory.household:
        return 'Household Essentials & Toiletries';
      case StoreCategory.combos:
        return 'Condo Specials & Combos';
    }
  }

  /// Compact wording for chips, where the full label would not fit.
  String get shortLabel {
    switch (this) {
      case StoreCategory.snacks:
        return 'Snacks';
      case StoreCategory.beverages:
        return 'Drinks';
      case StoreCategory.instantFood:
        return 'Instant food';
      case StoreCategory.freshProduce:
        return 'Fresh';
      case StoreCategory.household:
        return 'Household';
      case StoreCategory.combos:
        return 'Combos';
    }
  }
}

/// How much of a product is left. Derived from the stock count so the two can
/// never disagree.
enum StoreStockStatus { inStock, lowStock, outOfStock }

/// Where a delivered order goes.
enum StoreDeliveryMethod { doorstep, lobbyPickup }

extension StoreDeliveryMethodLabel on StoreDeliveryMethod {
  String get label {
    switch (this) {
      case StoreDeliveryMethod.doorstep:
        return 'Deliver to Doorstep';
      case StoreDeliveryMethod.lobbyPickup:
        return 'Pick-up at Lobby';
    }
  }

  String get description {
    switch (this) {
      case StoreDeliveryMethod.doorstep:
        return 'Our runner brings it to your unit door.';
      case StoreDeliveryMethod.lobbyPickup:
        return 'Collect from the management store in the lobby.';
    }
  }
}

/// How far an order has got. Every status has an icon and a word as well as a
/// colour, so it never depends on seeing colour.
enum StoreOrderStatus {
  submitted,
  confirmed,
  preparing,
  outForDelivery,
  readyForPickup,
  completed,
  cancelled,
}

extension StoreOrderStatusLabel on StoreOrderStatus {
  String get label {
    switch (this) {
      case StoreOrderStatus.submitted:
        return 'Submitted';
      case StoreOrderStatus.confirmed:
        return 'Order Confirmed';
      case StoreOrderStatus.preparing:
        return 'Preparing';
      case StoreOrderStatus.outForDelivery:
        return 'Out for Delivery';
      case StoreOrderStatus.readyForPickup:
        return 'Ready for Pick-up';
      case StoreOrderStatus.completed:
        return 'Completed';
      case StoreOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// The steps a live order walks through, in order. The handover step depends
  /// on how the order is being delivered, so it is built per status.
  List<StoreOrderStatus> get timeline {
    final handover = switch (this) {
      StoreOrderStatus.outForDelivery => StoreOrderStatus.outForDelivery,
      StoreOrderStatus.readyForPickup => StoreOrderStatus.readyForPickup,
      _ => null,
    };
    if (handover != null) {
      return [
        StoreOrderStatus.submitted,
        StoreOrderStatus.confirmed,
        StoreOrderStatus.preparing,
        handover,
        StoreOrderStatus.completed,
      ];
    }
    return const [
      StoreOrderStatus.submitted,
      StoreOrderStatus.confirmed,
      StoreOrderStatus.preparing,
      StoreOrderStatus.completed,
    ];
  }

  StoreOrderStatus? get next {
    switch (this) {
      case StoreOrderStatus.submitted:
        return StoreOrderStatus.confirmed;
      case StoreOrderStatus.confirmed:
        return StoreOrderStatus.preparing;
      case StoreOrderStatus.preparing:
        return null;
      case StoreOrderStatus.outForDelivery:
      case StoreOrderStatus.readyForPickup:
        return StoreOrderStatus.completed;
      case StoreOrderStatus.completed:
      case StoreOrderStatus.cancelled:
        return null;
    }
  }

  /// An order can be called off until it leaves the store.
  bool get canCancel =>
      this == StoreOrderStatus.submitted || this == StoreOrderStatus.confirmed;

  bool get isFinished =>
      this == StoreOrderStatus.completed || this == StoreOrderStatus.cancelled;
}

/// Whether the store fee for an order has been settled.
enum StorePaymentStatus { paid, pending }

extension StorePaymentStatusLabel on StorePaymentStatus {
  String get label {
    switch (this) {
      case StorePaymentStatus.paid:
        return 'Paid';
      case StorePaymentStatus.pending:
        return 'Pending';
    }
  }
}

/// How a resident settles a Store Fee at checkout.
///
/// The store lists the methods residents actually use here, which is a wider and
/// more local set than the app-wide invoice payment methods: the two mobile
/// wallets are the common way to pay a small store fee.
enum StorePaymentMethod { card, kbzPay, wavePay, bankTransfer }

extension StorePaymentMethodLabel on StorePaymentMethod {
  String get label {
    switch (this) {
      case StorePaymentMethod.card:
        return 'Credit / Debit Card';
      case StorePaymentMethod.kbzPay:
        return 'KBZPay';
      case StorePaymentMethod.wavePay:
        return 'WavePay';
      case StorePaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  /// Short name for a button that already says "Pay $9.00 via ...".
  String get buttonLabel {
    switch (this) {
      case StorePaymentMethod.card:
        return 'Card';
      case StorePaymentMethod.kbzPay:
        return 'KBZPay';
      case StorePaymentMethod.wavePay:
        return 'WavePay';
      case StorePaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  String get description {
    switch (this) {
      case StorePaymentMethod.card:
        return 'Visa or Mastercard, saved or a new card.';
      case StorePaymentMethod.kbzPay:
        return 'Pay from your KBZPay wallet with your phone number.';
      case StorePaymentMethod.wavePay:
        return 'Pay from your WavePay wallet with your phone number.';
      case StorePaymentMethod.bankTransfer:
        return 'Transfer from your linked bank account.';
    }
  }
}

/// A payment method the resident has used before, so they can pay in one tap.
///
/// Only a masked reference is kept, never a full card number.
class StoreSavedMethod {
  const StoreSavedMethod({
    required this.id,
    required this.method,
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });

  final String id;
  final StorePaymentMethod method;

  /// What the resident recognises, e.g. `Visa ···· 4242`.
  final String title;
  final String subtitle;
  final bool isDefault;
}

/// Something a resident can buy in the Condo Mart.
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.stock,
    required this.unit,
    this.imagePath = '',
    this.brand = '',
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final StoreCategory category;
  final String description;
  final double price;

  /// Units left on the shelf.
  final int stock;

  /// Display unit such as `per pack`.
  final String unit;

  /// Bundled asset for the product, used when there is no remote photo.
  final String imagePath;

  /// Photography of the actual item, shown on the card and the detail sheet.
  ///
  /// Real product photography rather than an icon, so a resident can recognise
  /// what they are about to buy. Every seeded product carries one.
  final String imageUrl;
  final String brand;

  /// Derived from [stock] so the badge can never disagree with the count.
  StoreStockStatus get stockStatus {
    if (stock <= 0) {
      return StoreStockStatus.outOfStock;
    }
    if (stock <= 3) {
      return StoreStockStatus.lowStock;
    }
    return StoreStockStatus.inStock;
  }

  bool get isInStock => stock > 0;

  /// How many more the resident may add without going past what is on the
  /// shelf.
  int get maxPerOrder => stock;

  StoreProduct copyWith({
    String? name,
    StoreCategory? category,
    String? description,
    double? price,
    int? stock,
    String? unit,
    String? imagePath,
    String? brand,
    String? imageUrl,
  }) {
    return StoreProduct(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      imagePath: imagePath ?? this.imagePath,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// One product in a cart or in a placed order.
class StoreCartLine {
  const StoreCartLine({required this.product, required this.quantity});

  final StoreProduct product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  String get key => product.id;

  StoreCartLine copyWith({int? quantity}) =>
      StoreCartLine(product: product, quantity: quantity ?? this.quantity);
}

/// A placed store order.
///
/// Business rule: a store order is billed as its own `Store Fee` line. It is
/// never folded into the monthly condo fee, rent, utilities or any fine.
class StoreOrder {
  const StoreOrder({
    required this.id,
    required this.items,
    required this.deliveryMethod,
    required this.deliveryLocation,
    required this.deliveryTime,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.residentName,
    required this.unitLabel,
    required this.placedOn,
    this.assignedTo = '',
    this.storeFeeInvoiceItemKey = '',
  });

  /// Reference such as `ST-20260930-01`.
  final String id;
  final List<StoreCartLine> items;
  final StoreDeliveryMethod deliveryMethod;

  /// Where the order goes, e.g. `Tower A · Unit 1205`.
  final String deliveryLocation;

  /// Chosen slot, e.g. `Today · 6:00 PM – 7:00 PM`.
  final String deliveryTime;
  final StoreOrderStatus status;
  final StorePaymentStatus paymentStatus;
  final double subtotal;
  final double deliveryFee;

  /// What the resident pays in total.
  final double total;
  final String residentName;
  final String unitLabel;
  final String placedOn;

  /// Store staff member the order was given to, empty until it is assigned.
  final String assignedTo;

  /// The `Store Fee` invoice line this order is billed on, when the resident
  /// chose to pay with their statement rather than at checkout.
  final String storeFeeInvoiceItemKey;

  int get itemCount => items.fold(0, (total, line) => total + line.quantity);

  /// The store fee is the order total: the goods plus delivery.
  double get storeFee => total;

  bool get isPaid => paymentStatus == StorePaymentStatus.paid;

  StoreOrder copyWith({
    StoreOrderStatus? status,
    StorePaymentStatus? paymentStatus,
    String? assignedTo,
    String? storeFeeInvoiceItemKey,
  }) {
    return StoreOrder(
      id: id,
      items: items,
      deliveryMethod: deliveryMethod,
      deliveryLocation: deliveryLocation,
      deliveryTime: deliveryTime,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      residentName: residentName,
      unitLabel: unitLabel,
      placedOn: placedOn,
      assignedTo: assignedTo ?? this.assignedTo,
      storeFeeInvoiceItemKey: storeFeeInvoiceItemKey ?? this.storeFeeInvoiceItemKey,
    );
  }
}
