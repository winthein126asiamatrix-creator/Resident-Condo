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
}
