import '../../domain/entities/store_product.dart';
import '../repositories/store_repository.dart';

class StoreUseCases {
  const StoreUseCases(this.repository);

  final StoreRepository repository;

  Future<List<StoreProduct>> getProducts() => repository.getProducts();

  Future<List<StoreOrder>> getOrders() => repository.getOrders();

  Future<StoreOrder> placeOrder(StoreOrder order) => repository.placeOrder(order);

  Future<StoreOrder> updateOrderStatus(StoreOrder order, StoreOrderStatus status) =>
      repository.updateOrderStatus(order, status);

  Future<StoreOrder> updateOrderPayment(StoreOrder order, StorePaymentStatus status) =>
      repository.updateOrderPayment(order, status);
}
