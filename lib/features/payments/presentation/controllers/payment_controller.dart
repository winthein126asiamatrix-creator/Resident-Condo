import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/network/refresh_registry.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_dashboard.dart';
import '../../domain/usecases/payment_usecases.dart';

class PaymentController extends GetxController {
  PaymentController(
    this.useCases, {
    this._sessionController,
    RefreshRegistry? registry,
    ConnectivityService? connectivity,
  }) : _registryOverride = registry,
       _connectivityOverride = connectivity;

  static const currentBillingPeriod = 'September 2026';
  static const today = 'Sep 25, 2026';

  /// The registry key this controller re-fetches under.
  static const String screen = 'payments';

  final PaymentUseCases useCases;
  final dashboard = Rxn<PaymentDashboard>();
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

  /// True while what is on screen came from the device rather than the API.
  final isShowingCachedData = false.obs;

  /// When the dashboard currently on screen was last refreshed from the API.
  final lastUpdatedAt = Rxn<DateTime>();

  final SessionController? _sessionController;
  final RefreshRegistry? _registryOverride;
  final ConnectivityService? _connectivityOverride;

  Worker? _sessionWorker;
  int? _loadedForUserId;
  int? _ownerUserId;
  int _requestSeq = 0;
  Future<void>? _loadInFlight;

  var _transactionSequence = 1;

  SessionController? get _session =>
      _sessionController ??
      (Get.isRegistered<SessionController>()
          ? Get.find<SessionController>()
          : null);

  RefreshRegistry? get _registry =>
      _registryOverride ??
      (Get.isRegistered<RefreshRegistry>()
          ? Get.find<RefreshRegistry>()
          : null);

  ConnectivityService? get _connectivity =>
      _connectivityOverride ??
      (Get.isRegistered<ConnectivityService>()
          ? Get.find<ConnectivityService>()
          : null);

  int? get _currentUserId {
    final userId = _session?.currentUser?.id;
    return userId != null && userId > 0 ? userId : null;
  }

  String get lastUpdatedLabel {
    final value = lastUpdatedAt.value;
    return value == null ? '' : AppDates.format(value);
  }

  @override
  void onInit() {
    super.onInit();
    _registry?.register(screen, loadPayments);

    final session = _session;
    if (session == null) {
      // No session graph (e.g. a unit test): keep the previous eager behaviour.
      loadPayments();
      return;
    }

    // The dashboard is personal, so wait for `/me` to publish the authenticated
    // resident before asking the API or touching the scoped cache.
    _sessionWorker = ever(session.session, (resident) {
      final userId = resident?.user.id;
      if (userId == null || userId <= 0) {
        _loadedForUserId = null;
        _resetForAccount();
        return;
      }
      if (_loadedForUserId == userId) {
        return;
      }
      final switchingAccount =
          _loadedForUserId != null && _loadedForUserId != userId;
      _loadedForUserId = userId;
      if (switchingAccount) {
        _resetForAccount();
      }
      loadPayments();
    });

    final userId = session.currentUser?.id;
    if (userId != null && userId > 0) {
      _loadedForUserId = userId;
      loadPayments();
    }
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    _registry?.unregister(screen);
    super.onClose();
  }

  // ---------------------------------------------------------------- balances

  double get outstandingBalance =>
      invoices.fold(0, (total, invoice) => total + invoice.amountDue);

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

  double get currentCondoFeeDue =>
      _dueFor(InvoiceItemType.condoFee, period: currentBillingPeriod);

  double get currentRentDue =>
      _dueFor(InvoiceItemType.rent, period: currentBillingPeriod);

  int get openInvoiceCount =>
      invoices.where((invoice) => invoice.isPayable).length;

  double get totalPaidThisYear => paymentHistory
      .where((payment) => payment.isSuccessful && payment.date.endsWith('2026'))
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

  // -------------------------------------------------------- dashboard values

  String get dashboardCurrency =>
      dashboard.value?.outstandingBalance.currency ?? '';

  double get outstandingBalanceAmount =>
      dashboard.value?.outstandingBalance.amount ?? outstandingBalance;

  PaymentStatistics? get paymentStatistics =>
      dashboard.value?.paymentStatistics;

  InvoiceSummary? get invoiceSummary => dashboard.value?.invoiceSummary;

  List<RecentInvoice> get recentInvoices =>
      dashboard.value?.recentInvoices ?? const <RecentInvoice>[];

  List<RecentPayment> get recentPayments =>
      dashboard.value?.recentPayments ?? const <RecentPayment>[];

  FeeSummary? feeSummaryFor(String feeType) => dashboard.value?.feeFor(feeType);

  String get lastDashboardPaymentDate =>
      recentPayments.isEmpty ? '' : recentPayments.first.paidAtLabel;

  /// Finds the full invoice the API summary refers to, so tapping a recent
  /// invoice can open the existing detail screen.
  Invoice? invoiceByNumber(String number) {
    for (final invoice in invoices) {
      if (invoice.number == number) {
        return invoice;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ loads

  /// Loads the dashboard cache first, then refreshes it from the API.
  ///
  /// Concurrent callers share the request already in flight, so a rebuild, a
  /// pull-to-refresh and a reconnect cannot issue the same GET twice.
  Future<void> loadPayments() {
    final existing = _loadInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadPayments();
    _loadInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    });
  }

  Future<void> _loadPayments() async {
    final session = _session;
    final userId = _currentUserId;
    // With a session graph, a personal dashboard must not be fetched before the
    // authenticated resident is known.
    if (session != null && userId == null) {
      return;
    }

    final seq = ++_requestSeq;
    final hadDashboard = dashboard.value != null;
    isLoading.value = !hadDashboard;
    errorMessage.value = null;

    if (userId != null && (!hadDashboard || _ownerUserId != userId)) {
      await _hydrateFromCache(userId, seq);
      if (seq != _requestSeq || userId != _currentUserId) return;
    }

    await _loadLocalLedger(seq, userId);
    if (seq != _requestSeq || userId != _currentUserId) return;

    // A cached snapshot is enough to keep the screen useful while offline; the
    // reconnect worker refreshes it once the radio is back.
    if (dashboard.value != null && _connectivity?.isOnline.value == false) {
      isShowingCachedData.value = true;
      _registry?.markStale(screen);
      isLoading.value = false;
      return;
    }

    try {
      final fresh = await useCases.getDashboard();
      // A slower, older response must never replace a newer one or another
      // resident's dashboard.
      if (seq != _requestSeq || userId != _currentUserId) return;

      // Only a fully parsed response reaches this point, so it is safe to keep.
      if (userId != null) {
        try {
          await useCases.cacheDashboard(userId, fresh);
        } catch (_) {
          // A cache write is a convenience; the API response is still usable.
        }
        if (seq != _requestSeq || userId != _currentUserId) return;
      }

      dashboard.value = fresh;
      _ownerUserId = userId;
      isShowingCachedData.value = false;
      lastUpdatedAt.value = DateTime.now();
      errorMessage.value = null;
      _registry?.markFresh(screen);
    } on AppException catch (error) {
      if (seq != _requestSeq || userId != _currentUserId) return;
      _handleDashboardFailure(error);
    } catch (_) {
      if (seq != _requestSeq || userId != _currentUserId) return;
      _handleDashboardFailure(
        null,
        fallback: 'Unable to load payment information.',
      );
    } finally {
      if (seq == _requestSeq) {
        isLoading.value = false;
      }
    }
  }

  Future<void> _loadLocalLedger(int seq, int? userId) async {
    try {
      final loadedInvoices = await useCases.getInvoices();
      final loadedHistory = await useCases.getPaymentHistory();
      if (seq != _requestSeq || userId != _currentUserId) return;
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
      if (seq != _requestSeq || userId != _currentUserId) return;
      if (dashboard.value == null) {
        errorMessage.value = error.message;
      }
    } catch (_) {
      if (seq != _requestSeq || userId != _currentUserId) return;
      if (dashboard.value == null) {
        errorMessage.value = 'Unable to load payment information.';
      }
    }
  }

  /// Puts the device's copy on screen before the API answers.
  Future<void> _hydrateFromCache(int userId, int seq) async {
    try {
      final cached = await useCases.getCachedDashboard(userId);
      if (cached == null || seq != _requestSeq || userId != _currentUserId) {
        return;
      }
      dashboard.value = cached.dashboard;
      _ownerUserId = userId;
      isShowingCachedData.value = true;
      lastUpdatedAt.value = cached.updatedAt;
      errorMessage.value = null;
    } catch (_) {
      // The cache is only a head start; a broken read must not stop the request.
    }
  }

  void _handleDashboardFailure(Object? error, {String? fallback}) {
    if (dashboard.value != null) {
      // Older data is better than an error screen. The notice on the page says
      // where it came from.
      isShowingCachedData.value = true;
    } else {
      errorMessage.value = error is AppException
          ? error.message
          : (fallback ?? 'Unable to load payment information.');
    }
    if (error is ApiException && error.isRetryable) {
      _registry?.markStale(screen);
    }
  }

  /// Drops everything that belonged to the previous resident and clears the
  /// device copy. Called on sign-out.
  Future<void> clear() async {
    _resetForAccount();
    _loadedForUserId = null;
    try {
      await useCases.clearDashboardCache();
    } catch (_) {
      // Sign-out must still complete if the cache cannot be cleared.
    }
  }

  void _resetForAccount() {
    _requestSeq++;
    _loadInFlight = null;
    dashboard.value = null;
    invoices.clear();
    paymentHistory.clear();
    selectedInvoice.value = null;
    selectedItems.clear();
    paymentSuccess.value = null;
    paymentFailure.value = null;
    selectedPaymentMethod.value = PaymentMethod.card;
    isPaymentProcessing.value = false;
    isLoading.value = false;
    errorMessage.value = null;
    isShowingCachedData.value = false;
    lastUpdatedAt.value = null;
    _ownerUserId = null;
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
