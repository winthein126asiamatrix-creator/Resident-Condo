import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/payment_usecases.dart';

class PaymentController extends GetxController {
  PaymentController(this.useCases);

  static const currentBillingPeriod = 'September 2026';
  static const today = 'Sep 25, 2026';

  final PaymentUseCases useCases;
  final invoices = <Invoice>[].obs;
  final paymentHistory = <Payment>[].obs;
  final selectedInvoice = Rxn<Invoice>();
  final selectedItems = <InvoiceItem>[].obs;
  final selectedPaymentMethod = PaymentMethod.card.obs;
  final paymentSuccess = Rxn<Payment>();
  final paymentFailure = Rxn<Payment>();
  final isLoading = false.obs;
  final isPaymentProcessing = false.obs;
  final errorMessage = RxnString();

  var _transactionSequence = 1;

  @override
  void onInit() {
    super.onInit();
    loadPayments();
  }

  // ---------------------------------------------------------------- balances

  double get outstandingBalance => invoices.fold(
    0,
    (total, invoice) => total + invoice.amountDue,
  );

  /// Monthly rent is always reported on its own line, never merged with the
  /// monthly condo fee.
  double get rentDueTotal => _dueFor(InvoiceItemType.rent);

  double get condoFeeDueTotal => _dueFor(InvoiceItemType.condoFee);

  double get otherChargesDueTotal {
    var total = 0.0;
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        if (!item.type.isManagementCharge) {
          continue;
        }
        if (item.type == InvoiceItemType.condoFee) {
          continue;
        }
        total += item.dueAmount;
      }
    }
    return total;
  }

  double get currentMonthTotal => invoices
      .where((invoice) => invoice.billingPeriod == currentBillingPeriod)
      .fold(0, (total, invoice) => total + invoice.amountDue);

  double get currentCondoFeeDue => _dueFor(
    InvoiceItemType.condoFee,
    period: currentBillingPeriod,
  );

  double get currentRentDue => _dueFor(
    InvoiceItemType.rent,
    period: currentBillingPeriod,
  );

  int get openInvoiceCount =>
      invoices.where((invoice) => invoice.isPayable).length;

  double get totalPaidThisYear => paymentHistory
      .where(
        (payment) =>
            payment.isSuccessful && payment.date.endsWith('2026'),
      )
      .fold(0, (total, payment) => total + payment.amount);

  double get lastPaymentAmount {
    for (final payment in paymentHistory) {
      if (payment.isSuccessful) {
        return payment.amount;
      }
    }
    return 0;
  }

  String get lastPaymentDate {
    for (final payment in paymentHistory) {
      if (payment.isSuccessful) {
        return payment.date;
      }
    }
    return '';
  }

  Invoice? get oldestOpenInvoice {
    for (final invoice in invoices) {
      if (invoice.isPayable) {
        return invoice;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ loads

  Future<void> loadPayments() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loadedInvoices = await useCases.getInvoices();
      final loadedHistory = await useCases.getPaymentHistory();
      invoices.assignAll(loadedInvoices);
      paymentHistory.assignAll(loadedHistory);
      final selected = selectedInvoice.value;
      if (selected != null) {
        final refreshed = _findInvoice(selected.id);
        selectedInvoice.value = refreshed;
        if (refreshed != null) {
          // Keep only items that are still payable after a refresh so paid
          // items can never be submitted twice.
          selectedItems.removeWhere(
            (item) => !(refreshed.itemByKey(item.key)?.isPayable ?? false),
          );
          // Mandatory charges are always part of the payment.
          selectedItems.addAll(
            refreshed.mandatoryItems.where(
              (item) => !selectedItems.contains(item),
            ),
          );
        } else {
          selectedItems.clear();
        }
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load payment information.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> applyRole(String roleKey) async {
    try {
      await useCases.applyRole(roleKey);
      selectedItems.clear();
      await loadPayments();
    } on AppException catch (error) {
      errorMessage.value = error.message;
    }
  }

  // -------------------------------------------------------------- selection

  /// Selecting an invoice clears the selection: nothing optional is auto
  /// selected so "Pay now" can never settle the whole balance by accident.
  /// Mandatory charges are the exception, they are always pre-selected.
  void selectInvoice(Invoice invoice) {
    selectedInvoice.value = invoice;
    paymentSuccess.value = null;
    paymentFailure.value = null;
    errorMessage.value = null;
    selectedPaymentMethod.value = PaymentMethod.card;
    selectedItems
      ..clear()
      ..addAll(invoice.mandatoryItems);
  }

  /// Clears the optional items. Mandatory charges stay selected.
  void clearSelection() {
    final invoice = selectedInvoice.value;
    if (invoice == null) {
      selectedItems.clear();
      return;
    }
    selectedItems
      ..clear()
      ..addAll(invoice.mandatoryItems);
  }

  /// Explicit user action, used by the "Select all unpaid" shortcut.
  void selectAllUnpaidItems() {
    final invoice = selectedInvoice.value;
    if (invoice == null) {
      return;
    }
    selectedItems
      ..clear()
      ..addAll(invoice.unpaidItems);
  }

  bool isItemSelected(InvoiceItem item) => selectedItems.contains(item);

  /// Paid and zero-amount items can never be selected again, and mandatory
  /// charges can never be deselected.
  void toggleInvoiceItem(InvoiceItem item) {
    if (!item.isPayable || item.mustPaid) {
      return;
    }
    if (selectedItems.contains(item)) {
      selectedItems.remove(item);
    } else {
      selectedItems.add(item);
    }
  }

  /// Mandatory charges that are not part of the current selection. A non empty
  /// result blocks the payment.
  List<InvoiceItem> get missingMandatoryItems {
    final invoice = selectedInvoice.value;
    if (invoice == null) {
      return const [];
    }
    return invoice.mandatoryItems
        .where((item) => !selectedItems.contains(item))
        .toList();
  }

  /// Payment can only continue once every mandatory charge is selected.
  bool get canProceedToPayment =>
      selectedItems.isNotEmpty && missingMandatoryItems.isEmpty;

  String get mandatoryValidationMessage {
    final missing = missingMandatoryItems;
    if (missing.isEmpty) {
      return '';
    }
    final labels = missing.map((item) => item.label).join(', ');
    return 'Mandatory fees must be paid: $labels';
  }

  void selectPaymentMethod(PaymentMethod method) {
    selectedPaymentMethod.value = method;
  }

  double get selectedTotal =>
      selectedItems.fold(0, (total, item) => total + item.amount);

  int get selectedCount => selectedItems.length;

  Future<Invoice?> getInvoice(String id) {
    return useCases.getInvoice(id);
  }

  /// Adds a Convenience Store `Store Fee` to the open statement and refreshes the
  /// ledger, so the charge shows up as an outstanding payment straight away.
  Future<Invoice> addStoreFee({
    required double amount,
    required String reference,
  }) async {
    final updated = await useCases.addStoreFee(
      amount: amount,
      reference: reference,
    );
    await loadPayments();
    return updated;
  }

  // ---------------------------------------------------------------- payment

  /// Submits the selected items only. A declined attempt is stored as failed
  /// and never changes the invoice status.
  Future<Payment?> confirmPayment({String cardNumber = ''}) async {
    final invoice = selectedInvoice.value;
    if (invoice == null || !invoice.isPayable) {
      errorMessage.value = 'Select an unpaid invoice first.';
      return null;
    }
    if (selectedItems.isEmpty) {
      errorMessage.value = 'Select at least one fee to pay.';
      return null;
    }
    if (missingMandatoryItems.isNotEmpty) {
      errorMessage.value = mandatoryValidationMessage;
      return null;
    }

    isPaymentProcessing.value = true;
    errorMessage.value = null;
    paymentSuccess.value = null;
    paymentFailure.value = null;

    final transactionId =
        'TXN-20260925-${_transactionSequence.toString().padLeft(3, '0')}';
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final declined = _shouldDecline(cardNumber);
      final payment = Payment(
        id: 'payment-${DateTime.now().microsecondsSinceEpoch}',
        invoiceNumber: invoice.number,
        residentName: 'Alex Johnson',
        unitLabel: invoice.unitLabel,
        items: List<InvoiceItem>.unmodifiable(selectedItems),
        amount: selectedTotal,
        date: today,
        method: selectedPaymentMethod.value,
        transactionId: transactionId,
        status: declined ? PaymentStatus.failed : PaymentStatus.successful,
        failureReason: declined
            ? 'Your bank declined the transaction. No amount was charged.'
            : null,
      );
      final stored = await useCases.submitPayment(payment);
      _transactionSequence++;
      if (stored.isSuccessful) {
        paymentSuccess.value = stored;
      } else {
        paymentFailure.value = stored;
      }
      await loadPayments();
      return stored;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to complete the payment.';
      return null;
    } finally {
      isPaymentProcessing.value = false;
    }
  }

  /// Mock gateway rule so the failure state can be demonstrated: any card
  /// number ending in 0000 is declined.
  bool _shouldDecline(String cardNumber) {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 && digits.endsWith('0000');
  }

  // ---------------------------------------------------------------- helpers

  Invoice? _findInvoice(String id) {
    for (final invoice in invoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    return null;
  }

  double _dueFor(InvoiceItemType type, {String? period}) {
    var total = 0.0;
    for (final invoice in invoices) {
      if (period != null && invoice.billingPeriod != period) {
        continue;
      }
      for (final item in invoice.items) {
        if (item.type == type) {
          total += item.dueAmount;
        }
      }
    }
    return total;
  }
}
