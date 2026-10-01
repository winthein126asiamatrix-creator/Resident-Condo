import '../entities/invoice.dart';
import '../entities/payment.dart';

abstract interface class PaymentRepository {
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
