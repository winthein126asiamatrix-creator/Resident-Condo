import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_detail.dart';
import '../../domain/entities/invoice_list.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_dashboard.dart';
import '../../domain/entities/payment_detail.dart';
import '../../domain/entities/payment_list.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_dashboard_local_data_source.dart';
import '../datasources/payment_dashboard_remote_data_source.dart';
import '../datasources/payment_invoice_local_data_source.dart';
import '../datasources/payment_invoice_remote_data_source.dart';
import '../datasources/payment_list_local_data_source.dart';
import '../datasources/payment_local_data_source.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl(
    this.localDataSource,
    this.dashboardDataSource,
    this.dashboardLocalDataSource, {
    this.invoiceDataSource,
    this.invoiceLocalDataSource,
    this.paymentListLocalDataSource,
  });

  final PaymentLocalDataSource localDataSource;
  final PaymentDashboardRemoteDataSource dashboardDataSource;
  final PaymentDashboardLocalDataSource dashboardLocalDataSource;
  final PaymentInvoiceRemoteDataSource? invoiceDataSource;
  final PaymentInvoiceLocalDataSource? invoiceLocalDataSource;
  final PaymentListLocalDataSource? paymentListLocalDataSource;

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
  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) {
    final remote = invoiceDataSource;
    if (remote == null) {
      throw StateError('Invoice remote data source is not configured.');
    }
    return remote.getInvoices(page: page, limit: limit, status: status);
  }

  @override
  Future<InvoiceDetail> getInvoiceDetail(int id) {
    final remote = invoiceDataSource;
    if (remote == null) {
      throw StateError('Invoice remote data source is not configured.');
    }
    return remote.getInvoice(id);
  }

  @override
  Future<CachedInvoiceList?> getCachedInvoiceList(
    int userId,
    String status,
  ) async {
    final local = invoiceLocalDataSource;
    if (local == null) {
      return null;
    }
    return local.read(userId, status);
  }

  @override
  Future<void> cacheInvoiceList(
    int userId,
    String status,
    InvoiceListResponse response,
  ) {
    return invoiceLocalDataSource?.save(userId, status, response) ??
        Future<void>.value();
  }

  @override
  Future<void> clearInvoiceListCache() {
    return invoiceLocalDataSource?.clear() ?? Future<void>.value();
  }

  @override
  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20}) {
    final remote = invoiceDataSource;
    if (remote == null) {
      throw StateError('Payment remote data source is not configured.');
    }
    return remote.getPayments(page: page, limit: limit);
  }

  @override
  Future<PaymentDetail> getPaymentDetail(int id) {
    final remote = invoiceDataSource;
    if (remote == null) {
      throw StateError('Payment remote data source is not configured.');
    }
    return remote.getPayment(id);
  }

  @override
  Future<CachedPaymentList?> getCachedPaymentList(int userId) async {
    final local = paymentListLocalDataSource;
    if (local == null) {
      return null;
    }
    return local.read(userId);
  }

  @override
  Future<void> cachePaymentList(int userId, PaymentListResponse response) {
    return paymentListLocalDataSource?.save(userId, response) ??
        Future<void>.value();
  }

  @override
  Future<void> clearPaymentListCache() {
    return paymentListLocalDataSource?.clear() ?? Future<void>.value();
  }

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
