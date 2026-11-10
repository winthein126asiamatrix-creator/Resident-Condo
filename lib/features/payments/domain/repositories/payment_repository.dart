import '../entities/invoice.dart';
import '../entities/payment.dart';
import '../entities/payment_dashboard.dart';

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

  Future<List<Invoice>> getInvoices();

  Future<Invoice?> getInvoice(String id);

  Future<List<Payment>> getPaymentHistory();

  /// Records the payment attempt. A successful payment settles only the
  /// selected items; a failed payment is stored for the history but never
  /// changes an invoice status.
  Future<Payment> submitPayment(Payment payment);

  /// Swaps the mock ledger to the one that matches the signed-in role so the
  /// tenant sees a separate Monthly Rent line next to the condo fee.
  Future<List<Invoice>> applyRole(String roleKey);

  /// Adds a Convenience Store `Store Fee` line to the resident's open statement.
  ///
  /// A store order is always billed on its own line. It is never folded into the
  /// condo fee, rent, utilities, parking or any fine. [reference] is the store
  /// order id, which keeps the statement line traceable back to the order.
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  });
}
