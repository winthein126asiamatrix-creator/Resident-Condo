import '../../domain/entities/store_product.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_local_data_source.dart';

class StoreRepositoryImpl implements StoreRepository {
  const StoreRepositoryImpl(this.localDataSource);

  final StoreLocalDataSource localDataSource;

  @override
  Future<List<StoreProduct>> getProducts() async {
    final products = await localDataSource.getProducts();
    return List<StoreProduct>.of(products);
  }

  @override
  Future<List<StoreOrder>> getOrders() async {
    final orders = await localDataSource.getOrders();
    return List<StoreOrder>.of(orders);
  }

  @override
  Future<StoreOrder> placeOrder(StoreOrder order) =>
      localDataSource.placeOrder(order);

  @override
  Future<StoreOrder> updateOrderStatus(
    StoreOrder order,
    StoreOrderStatus status,
  ) => localDataSource.updateOrderStatus(order, status);

  @override
  Future<StoreOrder> updateOrderPayment(
    StoreOrder order,
    StorePaymentStatus status,
  ) => localDataSource.updateOrderPayment(order, status);
}
