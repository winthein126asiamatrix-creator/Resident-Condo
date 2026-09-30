import '../../domain/entities/store_product.dart';

/// Resident-facing store contract.
///
/// Read-only on the catalogue: residents browse the shelf but never write to
/// it. Pricing, restocking and order dispatch are management concerns and
/// deliberately have no path through this repository.
abstract interface class StoreRepository {
  Future<List<StoreProduct>> getProducts();

  Future<List<StoreOrder>> getOrders();

  Future<StoreOrder> placeOrder(StoreOrder order);

  /// Moves an order along the pipeline, including a resident cancelling their
  /// own order while it is still inside the store.
  Future<StoreOrder> updateOrderStatus(StoreOrder order, StoreOrderStatus status);

  /// Settles or re-opens the store fee on one of the resident's own orders.
  Future<StoreOrder> updateOrderPayment(
    StoreOrder order,
    StorePaymentStatus status,
  );
}
