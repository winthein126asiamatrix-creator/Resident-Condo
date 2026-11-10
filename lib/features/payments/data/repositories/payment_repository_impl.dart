import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_dashboard.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_dashboard_local_data_source.dart';
import '../datasources/payment_dashboard_remote_data_source.dart';
import '../datasources/payment_local_data_source.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl(
    this.localDataSource,
    this.dashboardDataSource,
    this.dashboardLocalDataSource,
  );

  final PaymentLocalDataSource localDataSource;
  final PaymentDashboardRemoteDataSource dashboardDataSource;
  final PaymentDashboardLocalDataSource dashboardLocalDataSource;

  @override
  Future<PaymentDashboard> getDashboard() => dashboardDataSource.getDashboard();

  @override
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) {
    return dashboardLocalDataSource.read(userId);
  }

  @override
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) {
    return dashboardLocalDataSource.save(userId, dashboard);
  }

  @override
  Future<void> clearDashboardCache() => dashboardLocalDataSource.clear();

  @override
  Future<List<Invoice>> getInvoices() async {
    final invoices = await localDataSource.getInvoices();
    return List<Invoice>.of(invoices);
  }

  @override
  Future<Invoice?> getInvoice(String id) {
    return localDataSource.getInvoice(id);
  }

  @override
  Future<List<Payment>> getPaymentHistory() async {
    final history = await localDataSource.getPaymentHistory();
    return List<Payment>.of(history);
  }

  @override
  Future<Payment> submitPayment(Payment payment) {
    return localDataSource.submitPayment(payment);
  }

  @override
  Future<List<Invoice>> applyRole(String roleKey) {
    return localDataSource.applyRole(roleKey);
  }

  @override
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  }) {
    return localDataSource.addStoreFee(amount: amount, reference: reference);
  }
}
