import '../entities/invoice_detail.dart';
import '../entities/invoice_list.dart';
import '../entities/payment.dart';
import '../entities/payment_dashboard.dart';
import '../entities/payment_detail.dart';
import '../entities/payment_list.dart';
import '../entities/payment_method_option.dart';
import '../entities/payment_quote.dart';

abstract interface class PaymentRepository {
  /// Balance, fee breakdown, invoice counts and recent activity for the
  /// payments dashboard.
  Future<PaymentDashboard> getDashboard();

  /// The dashboard snapshot stored for [userId], or null when none exists.
  Future<CachedPaymentDashboard?> getCachedDashboard(int userId);

  /// Stores a fully parsed dashboard response for [userId].
  Future<void> cacheDashboard(int userId, PaymentDashboard dashboard);

  /// Drops every cached payment dashboard on this device.
  Future<void> clearDashboardCache();

  /// One page of the resident's invoices from the API.
  Future<InvoiceListResponse> getInvoiceList({
    int page = 1,
    int limit = 20,
    String status = 'all',
  });

  /// One invoice, with its unit and line items, from the API.
  Future<InvoiceDetail> getInvoiceDetail(int id);

  /// The cached first page for [userId] and [status], when one exists.
  Future<CachedInvoiceList?> getCachedInvoiceList(int userId, String status);

  /// Stores the first page, truncated to the newest ten invoices.
  Future<void> cacheInvoiceList(
    int userId,
    String status,
    InvoiceListResponse response,
  );

  /// Drops every cached invoice list on this device.
  Future<void> clearInvoiceListCache();

  /// One page of the resident's payments from the API.
  Future<PaymentListResponse> getPaymentList({int page = 1, int limit = 20});

  /// One payment, with its receipt, from the API.
  Future<PaymentDetail> getPaymentDetail(int id);

  /// The cached latest payments for [userId], when one exists.
  Future<CachedPaymentList?> getCachedPaymentList(int userId);

  /// Stores the first page, truncated to the latest twenty payments.
  Future<void> cachePaymentList(int userId, PaymentListResponse response);

  /// Drops every cached payment list on this device.
  Future<void> clearPaymentListCache();

  /// The payment methods residents can choose from.
  Future<List<PaymentMethodOption>> getPaymentMethods();

  /// The cached payment methods for [userId], when one exists.
  Future<CachedPaymentMethods?> getCachedPaymentMethods(int userId);

  /// Stores a fully parsed payment methods response for [userId].
  Future<void> cachePaymentMethods(
    int userId,
    List<PaymentMethodOption> methods,
  );

  /// Drops every cached payment methods list on this device.
  Future<void> clearPaymentMethodsCache();

  /// Prices the selected invoice lines before the payment is submitted.
  Future<PaymentQuote> getPaymentQuote({
    required int invoiceId,
    required List<int> selectedItemIds,
  });

  /// Submits the payment to the API and returns the backend payment record.
  ///
  /// The server response is authoritative for payment status, identifiers,
  /// amounts, timestamps and proof images.
  Future<Payment> submitPayment(Payment payment);
}
