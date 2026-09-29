import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../models/invoice_model.dart';
import '../models/payment_model.dart';

/// In-memory ledger that mimics the Odoo invoice / payment pairs.
///
/// Owner and tenant have separate statements on purpose: an owner never has a
/// Monthly Rent line, a tenant always has Monthly Rent and Monthly Condo Fee as
/// two independent line items.
class PaymentLocalDataSource {
  PaymentLocalDataSource() : _seed = _ownerSeed() {
    _invoices = List<InvoiceModel>.of(_seed.invoices);
    _payments = List<PaymentModel>.of(_seed.payments);
  }

  late List<InvoiceModel> _invoices;
  late List<PaymentModel> _payments;
  late _LedgerSeed _seed;

  String _roleKey = 'owner';

  Future<List<InvoiceModel>> getInvoices() async {
    return List<InvoiceModel>.unmodifiable(_invoices);
  }

  Future<InvoiceModel?> getInvoice(String id) async {
    for (final invoice in _invoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    return null;
  }

  Future<List<PaymentModel>> getPaymentHistory() async {
    return List<PaymentModel>.unmodifiable(_payments);
  }

  Future<List<InvoiceModel>> applyRole(String roleKey) async {
    if (_roleKey == roleKey) {
      return getInvoices();
    }
    _roleKey = roleKey;
    _seed = roleKey == 'tenant' ? _tenantSeed() : _ownerSeed();
    _invoices = List<InvoiceModel>.of(_seed.invoices);
    _payments = List<PaymentModel>.of(_seed.payments);
    return getInvoices();
  }

  /// Only the selected items are settled. An invoice becomes `paid` once every
  /// payable item is settled, otherwise it stays `partiallyPaid`.
  /// A failed payment is only written to the history and never settles items.
  Future<PaymentModel> submitPayment(Payment payment) async {
    if (payment.isFailed) {
      final failed = _toModel(payment);
      _payments.insert(0, failed);
      return failed;
    }

    final index = _invoices.indexWhere(
      (invoice) => invoice.number == payment.invoiceNumber,
    );
    if (index == -1) {
      throw const AppException('Invoice could not be found.');
    }

    final invoice = _invoices[index];
    if (invoice.isFullyPaid) {
      throw const AppException('This invoice has already been paid.');
    }

    final keys = payment.items.map((item) => item.key).toSet();
    for (final key in keys) {
      final existing = invoice.itemByKey(key);
      if (existing == null) {
        throw const AppException('One of the selected items is no longer valid.');
      }
      if (!existing.isPayable) {
        throw const AppException('One of the selected items is already paid.');
      }
    }

    final updatedItems = invoice.items
        .map(
          (item) => keys.contains(item.key)
              ? item.copyWith(isPaid: true, paidDate: payment.date)
              : item,
        )
        .toList();
    final dueAfter = updatedItems.fold(0.0, (sum, item) => sum + item.dueAmount);
    final fullyPaid = dueAfter <= 0;

    _invoices[index] = InvoiceModel(
      id: invoice.id,
      number: invoice.number,
      title: invoice.title,
      billingPeriod: invoice.billingPeriod,
      unitLabel: invoice.unitLabel,
      dueDate: invoice.dueDate,
      status: fullyPaid ? InvoiceStatus.paid : InvoiceStatus.partiallyPaid,
      items: updatedItems,
      paidDate: fullyPaid ? payment.date : null,
    );

    final created = _toModel(payment);
    _payments.insert(0, created);
    return created;
  }

  PaymentModel _toModel(Payment payment) {
    return PaymentModel(
      id: payment.id,
      invoiceNumber: payment.invoiceNumber,
      residentName: payment.residentName,
      unitLabel: payment.unitLabel,
      items: List<InvoiceItem>.unmodifiable(payment.items),
      amount: payment.amount,
      date: payment.date,
      method: payment.method,
      transactionId: payment.transactionId,
      status: payment.status,
      failureReason: payment.failureReason,
    );
  }

  static _LedgerSeed _ownerSeed() {
    return _LedgerSeed(
      invoices: const [
        InvoiceModel(
          id: 'invoice-2026-011',
          number: 'INV-2026-011',
          title: 'September 2026 statement',
          billingPeriod: 'September 2026',
          unitLabel: 'Tower A · 1205',
          dueDate: 'Sep 30, 2026',
          status: InvoiceStatus.unpaid,
          items: [
            InvoiceItem(
              type: InvoiceItemType.condoFee,
              amount: 135,
              note: 'Sep 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.parking,
              amount: 45,
              note: 'Sep 2026 · Slot B2-125',
            ),
            InvoiceItem(
              type: InvoiceItemType.utility,
              amount: 62.40,
              note: 'Water & power · Aug–Sep',
            ),
            InvoiceItem(
              type: InvoiceItemType.facility,
              amount: 30,
              note: 'Function Room · Sep 27',
            ),
            InvoiceItem(
              type: InvoiceItemType.service,
              amount: 55,
              note: 'Deep cleaning · Sep 26',
            ),
            InvoiceItem(
              type: InvoiceItemType.violation,
              amount: 80,
              note: 'Noise violation · Sep 12',
            ),
            InvoiceItem(
              type: InvoiceItemType.lateFee,
              amount: 15,
              note: 'August statement',
            ),
          ],
        ),
        InvoiceModel(
          id: 'invoice-2026-010',
          number: 'INV-2026-010',
          title: 'August 2026 statement',
          billingPeriod: 'August 2026',
          unitLabel: 'Tower A · 1205',
          dueDate: 'Aug 31, 2026',
          status: InvoiceStatus.partiallyPaid,
          items: [
            InvoiceItem(
              type: InvoiceItemType.condoFee,
              amount: 135,
              note: 'Aug 2026',
              isPaid: true,
              paidDate: 'Sep 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.parking,
              amount: 45,
              note: 'Aug 2026 · Slot B2-125',
              isPaid: true,
              paidDate: 'Sep 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.utility,
              amount: 58.10,
              note: 'Water & power · Jul–Aug',
              isPaid: true,
              paidDate: 'Sep 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.facility,
              amount: 0,
              note: 'No facility booking',
            ),
            InvoiceItem(
              type: InvoiceItemType.service,
              amount: 40,
              note: 'Aircon servicing · Aug 28',
            ),
            InvoiceItem(type: InvoiceItemType.violation, amount: 0),
          ],
        ),
        InvoiceModel(
          id: 'invoice-2026-009',
          number: 'INV-2026-009',
          title: 'July 2026 statement',
          billingPeriod: 'July 2026',
          unitLabel: 'Tower A · 1205',
          dueDate: 'Jul 31, 2026',
          status: InvoiceStatus.paid,
          paidDate: 'Aug 01, 2026',
          items: [
            InvoiceItem(
              type: InvoiceItemType.condoFee,
              amount: 135,
              note: 'Jul 2026',
              isPaid: true,
              paidDate: 'Aug 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.parking,
              amount: 45,
              note: 'Jul 2026 · Slot B2-125',
              isPaid: true,
              paidDate: 'Aug 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.utility,
              amount: 54.20,
              note: 'Water & power · Jun–Jul',
              isPaid: true,
              paidDate: 'Aug 01, 2026',
            ),
          ],
        ),
      ],
      payments: const [
        PaymentModel(
          id: 'payment-2026-008',
          invoiceNumber: 'INV-2026-010',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'Aug 2026'),
            InvoiceItem(type: InvoiceItemType.parking, amount: 45, note: 'Aug 2026 · Slot B2-125'),
            InvoiceItem(type: InvoiceItemType.utility, amount: 58.10, note: 'Water & power · Jul–Aug'),
          ],
          amount: 238.10,
          date: 'Sep 01, 2026',
          method: PaymentMethod.bankTransfer,
          transactionId: 'TXN-20260901-001',
        ),
        PaymentModel(
          id: 'payment-2026-007',
          invoiceNumber: 'INV-2026-009',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'Jul 2026'),
            InvoiceItem(type: InvoiceItemType.parking, amount: 45, note: 'Jul 2026 · Slot B2-125'),
            InvoiceItem(type: InvoiceItemType.utility, amount: 54.20, note: 'Water & power · Jun–Jul'),
          ],
          amount: 234.20,
          date: 'Aug 01, 2026',
          method: PaymentMethod.card,
          transactionId: 'TXN-20260801-001',
        ),
        PaymentModel(
          id: 'payment-2026-006',
          invoiceNumber: 'INV-2026-008',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'Jun 2026'),
            InvoiceItem(type: InvoiceItemType.parking, amount: 45, note: 'Jun 2026 · Slot B2-125'),
          ],
          amount: 180,
          date: 'Jul 02, 2026',
          method: PaymentMethod.card,
          transactionId: 'TXN-20260702-001',
        ),
        PaymentModel(
          id: 'payment-2026-005',
          invoiceNumber: 'INV-2026-007',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'May 2026'),
            InvoiceItem(type: InvoiceItemType.parking, amount: 45, note: 'May 2026 · Slot B2-125'),
          ],
          amount: 180,
          date: 'Jun 03, 2026',
          method: PaymentMethod.card,
          transactionId: 'TXN-20260603-001',
        ),
        PaymentModel(
          id: 'payment-2026-004',
          invoiceNumber: 'INV-2026-006',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'Apr 2026'),
            InvoiceItem(type: InvoiceItemType.parking, amount: 45, note: 'Apr 2026 · Slot B2-125'),
          ],
          amount: 180,
          date: 'May 04, 2026',
          method: PaymentMethod.digitalWallet,
          transactionId: 'TXN-20260504-001',
        ),
        PaymentModel(
          id: 'payment-2026-003',
          invoiceNumber: 'INV-2026-005',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'Mar 2026'),
            InvoiceItem(type: InvoiceItemType.parking, amount: 45, note: 'Mar 2026 · Slot B2-125'),
          ],
          amount: 180,
          date: 'Apr 06, 2026',
          method: PaymentMethod.card,
          transactionId: 'TXN-20260406-001',
        ),
        PaymentModel(
          id: 'payment-2026-failed',
          invoiceNumber: 'INV-2026-009',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.utility, amount: 54.20, note: 'Water & power · Jun–Jul'),
          ],
          amount: 54.20,
          date: 'Jul 29, 2026',
          method: PaymentMethod.card,
          transactionId: 'TXN-20260729-002',
          status: PaymentStatus.failed,
          failureReason: 'Card declined by the issuing bank.',
        ),
      ],
    );
  }

  static _LedgerSeed _tenantSeed() {
    return _LedgerSeed(
      invoices: const [
        InvoiceModel(
          id: 'invoice-2026-011',
          number: 'INV-2026-011',
          title: 'September 2026 statement',
          billingPeriod: 'September 2026',
          unitLabel: 'Tower A · 1205',
          dueDate: 'Sep 30, 2026',
          status: InvoiceStatus.unpaid,
          items: [
            InvoiceItem(
              type: InvoiceItemType.rent,
              amount: 2400,
              note: 'Sep 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.condoFee,
              amount: 135,
              note: 'Sep 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.utility,
              amount: 62.40,
              note: 'Water & power · Aug–Sep',
            ),
            InvoiceItem(
              type: InvoiceItemType.parking,
              amount: 45,
              note: 'Sep 2026 · Slot B2-125',
            ),
            InvoiceItem(
              type: InvoiceItemType.lateFee,
              amount: 25,
              note: 'August rent',
            ),
          ],
        ),
        InvoiceModel(
          id: 'invoice-2026-010',
          number: 'INV-2026-010',
          title: 'August 2026 statement',
          billingPeriod: 'August 2026',
          unitLabel: 'Tower A · 1205',
          dueDate: 'Aug 31, 2026',
          status: InvoiceStatus.partiallyPaid,
          items: [
            InvoiceItem(
              type: InvoiceItemType.rent,
              amount: 2400,
              note: 'Aug 2026',
              isPaid: true,
              paidDate: 'Sep 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.condoFee,
              amount: 135,
              note: 'Aug 2026',
              isPaid: true,
              paidDate: 'Sep 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.utility,
              amount: 58.10,
              note: 'Water & power · Jul–Aug',
            ),
          ],
        ),
        InvoiceModel(
          id: 'invoice-2026-009',
          number: 'INV-2026-009',
          title: 'July 2026 statement',
          billingPeriod: 'July 2026',
          unitLabel: 'Tower A · 1205',
          dueDate: 'Jul 31, 2026',
          status: InvoiceStatus.paid,
          paidDate: 'Aug 01, 2026',
          items: [
            InvoiceItem(
              type: InvoiceItemType.rent,
              amount: 2400,
              note: 'Jul 2026',
              isPaid: true,
              paidDate: 'Aug 01, 2026',
            ),
            InvoiceItem(
              type: InvoiceItemType.condoFee,
              amount: 135,
              note: 'Jul 2026',
              isPaid: true,
              paidDate: 'Aug 01, 2026',
            ),
          ],
        ),
      ],
      payments: const [
        PaymentModel(
          id: 'payment-2026-t-002',
          invoiceNumber: 'INV-2026-010',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.rent, amount: 2400, note: 'Aug 2026'),
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'Aug 2026'),
          ],
          amount: 2535,
          date: 'Sep 01, 2026',
          method: PaymentMethod.bankTransfer,
          transactionId: 'TXN-20260901-101',
        ),
        PaymentModel(
          id: 'payment-2026-t-001',
          invoiceNumber: 'INV-2026-009',
          residentName: 'Alex Johnson',
          unitLabel: 'Tower A · 1205',
          items: [
            InvoiceItem(type: InvoiceItemType.rent, amount: 2400, note: 'Jul 2026'),
            InvoiceItem(type: InvoiceItemType.condoFee, amount: 135, note: 'Jul 2026'),
          ],
          amount: 2535,
          date: 'Aug 01, 2026',
          method: PaymentMethod.card,
          transactionId: 'TXN-20260801-101',
        ),
      ],
    );
  }
}

class _LedgerSeed {
  const _LedgerSeed({required this.invoices, required this.payments});

  final List<InvoiceModel> invoices;
  final List<PaymentModel> payments;
}
