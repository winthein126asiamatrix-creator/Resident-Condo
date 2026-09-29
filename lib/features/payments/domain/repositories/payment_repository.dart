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
}
