import '../entities/invoice.dart';
import '../entities/invoice_detail.dart';
import '../entities/invoice_list.dart';
import '../entities/payment.dart';
import '../entities/payment_dashboard.dart';
import '../entities/payment_detail.dart';
import '../entities/payment_list.dart';
import '../repositories/payment_repository.dart';

class PaymentUseCases {
  const PaymentUseCases(this.repository);

  final PaymentRepository repository;

  Future<PaymentDashboard> getDashboard() {
    return repository.getDashboard();
  }

  Future<CachedPaymentDashboard?> getCachedDashboard(int userId) {
    return repository.getCachedDashboard(userId);
  }

  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard) {
    return repository.cacheDashboard(userId, dashboard);
  }

  Future<void> clearDashboardCache() {
    return repository.clearDashboardCache();
  }

  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) {
    return repository.getInvoiceList(page: page, limit: limit, status: status);
  }

  Future<InvoiceDetail> getInvoiceDetail(int id) {
    return repository.getInvoiceDetail(id);
  }

  Future<CachedInvoiceList?> getCachedInvoiceList(int userId, String status) {
    return repository.getCachedInvoiceList(userId, status);
  }

  Future<void> cacheInvoiceList(
    int userId,
    String status,
    InvoiceListResponse response,
  ) {
    return repository.cacheInvoiceList(userId, status, response);
  }

  Future<void> clearInvoiceListCache() {
    return repository.clearInvoiceListCache();
  }

  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20}) {
    return repository.getPaymentList(page: page, limit: limit);
  }

  Future<PaymentDetail> getPaymentDetail(int id) {
    return repository.getPaymentDetail(id);
  }

  Future<CachedPaymentList?> getCachedPaymentList(int userId) {
    return repository.getCachedPaymentList(userId);
  }

  Future<void> cachePaymentList(int userId, PaymentListResponse response) {
    return repository.cachePaymentList(userId, response);
  }

  Future<void> clearPaymentListCache() {
    return repository.clearPaymentListCache();
  }

  Future<List<Invoice>> getInvoices() {
    return repository.getInvoices();
  }

  Future<Invoice?> getInvoice(String id) {
    return repository.getInvoice(id);
  }

  Future<List<Payment>> getPaymentHistory() {
    return repository.getPaymentHistory();
  }

  Future<Payment> submitPayment(Payment payment) {
    return repository.submitPayment(payment);
  }

  Future<List<Invoice>> applyRole(String roleKey) {
    return repository.applyRole(roleKey);
  }

  /// Bills a Convenience Store order as its own `Store Fee` line on the resident's
  /// statement, rather than merging it into any other charge.
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  }) {
    return repository.addStoreFee(amount: amount, reference: reference);
  }
}
