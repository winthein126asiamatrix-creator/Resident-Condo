import '../../domain/entities/store_product.dart';

class StoreProductModel extends StoreProduct {
  const StoreProductModel({
    required super.id,
    required super.name,
    required super.category,
    required super.description,
    required super.price,
    required super.stock,
    required super.unit,
    super.imagePath,
    super.brand,
    super.imageUrl,
  });
}

class StoreCartLineModel extends StoreCartLine {
  const StoreCartLineModel({required super.product, required super.quantity});
}

class StoreOrderModel extends StoreOrder {
  const StoreOrderModel({
    required super.id,
    required super.items,
    required super.deliveryMethod,
    required super.deliveryLocation,
    required super.deliveryTime,
    required super.status,
    required super.paymentStatus,
    required super.subtotal,
    required super.deliveryFee,
    required super.total,
    required super.residentName,
    required super.unitLabel,
    required super.placedOn,
    super.assignedTo,
    super.storeFeeInvoiceItemKey,
  });
}
