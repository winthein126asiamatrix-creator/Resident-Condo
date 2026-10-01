import '../entities/invoice.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

class PaymentUseCases {
  const PaymentUseCases(this.repository);

  final PaymentRepository repository;

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
