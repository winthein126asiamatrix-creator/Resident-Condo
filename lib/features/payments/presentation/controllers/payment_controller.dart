import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/network/refresh_registry.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_detail.dart';
import '../../domain/entities/invoice_list.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_dashboard.dart';
import '../../domain/entities/payment_detail.dart';
import '../../domain/entities/payment_list.dart';
import '../../domain/entities/payment_method_option.dart';
import '../../domain/usecases/payment_usecases.dart';

class PaymentController extends GetxController {
  PaymentController(
    this.useCases, {
    this._sessionController,
    RefreshRegistry? registry,
    ConnectivityService? connectivity,
  }) : _registryOverride = registry,
       _connectivityOverride = connectivity;

  /// The registry key this controller re-fetches under.
  static const String screen = 'payments';

  /// Reconnect keys for the invoice screens. They are separate from the
  /// payments tab so a reconnect refreshes whichever screen is actually open.
  static const String invoiceListScreen = 'payments:invoices';
  static const String invoiceDetailScreen = 'payments:invoice-detail';
  static const String paymentListScreen = 'payments:list';
  static const String paymentDetailScreen = 'payments:payment-detail';
  static const String paymentMethodsScreen = 'payments:methods';

  /// The first page size used by the list and by the cache snapshot.
  static const int invoicePageSize = 20;
  static const int paymentPageSize = 20;

  /// Status values the Invoice List filter offers.
  static const List<String> invoiceStatusFilters = <String>[
    'all',
    'unpaid',
    'partial',
    'paid',
    'overdue',
  ];

  final PaymentUseCases useCases;
  final dashboard = Rxn<PaymentDashboard>();
  final selectedInvoice = Rxn<Invoice>();
  final selectedItems = <InvoiceItem>[].obs;
  final paymentMethods = <PaymentMethodOption>[].obs;
  final selectedPaymentMethodKey = RxnString();
  final paymentSuccess = Rxn<Payment>();
  final paymentFailure = Rxn<Payment>();
  final isLoading = false.obs;
  final isPaymentProcessing = false.obs;
  final errorMessage = RxnString();

  /// True while what is on screen came from the device rather than the API.
  final isShowingCachedData = false.obs;

  /// When the dashboard currently on screen was last refreshed from the API.
  final lastUpdatedAt = Rxn<DateTime>();

  // ----------------------------------------------------------- invoice list

  final invoiceList = <InvoiceListItem>[].obs;
  final invoiceListPage = 1.obs;
  final invoiceListLimit = invoicePageSize.obs;
  final invoiceListTotal = 0.obs;
  final invoiceListStatus = 'all'.obs;
  final isLoadingInvoiceList = false.obs;
  final isLoadingMoreInvoices = false.obs;
  final invoiceListError = RxnString();
  final isShowingCachedInvoices = false.obs;
  final invoiceListUpdatedAt = Rxn<DateTime>();

  // --------------------------------------------------------- invoice detail

  /// The API detail currently on screen. This is never populated from cache.
  final invoiceDetail = Rxn<InvoiceDetail>();
  final invoiceDetailId = Rxn<int>();
  final isLoadingInvoiceDetail = false.obs;
  final invoiceDetailError = RxnString();

  // ------------------------------------------------------------ payment list

  final paymentList = <PaymentListItem>[].obs;
  final paymentListPage = 1.obs;
  final paymentListLimit = paymentPageSize.obs;
  final paymentListTotal = 0.obs;
  final isLoadingPaymentList = false.obs;
  final isLoadingMorePayments = false.obs;
  final paymentListError = RxnString();
  final isShowingCachedPayments = false.obs;
  final paymentListUpdatedAt = Rxn<DateTime>();

  // ---------------------------------------------------------- payment detail

  final paymentDetail = Rxn<PaymentDetail>();
  final paymentDetailId = Rxn<int>();
  final isLoadingPaymentDetail = false.obs;
  final paymentDetailError = RxnString();

  // --------------------------------------------------------- payment methods

  final isLoadingPaymentMethods = false.obs;
  final paymentMethodsError = RxnString();
  final isShowingCachedPaymentMethods = false.obs;
  final paymentMethodsUpdatedAt = Rxn<DateTime>();

  final SessionController? _sessionController;
  final RefreshRegistry? _registryOverride;
  final ConnectivityService? _connectivityOverride;

  Worker? _sessionWorker;
  int? _loadedForUserId;
  int? _ownerUserId;
  int _requestSeq = 0;
  Future<void>? _loadInFlight;

  int? _invoiceListOwnerUserId;
  bool _hasInvoiceListData = false;
  int _invoiceListSeq = 0;
  Future<void>? _invoiceListInFlight;

  int _invoiceDetailSeq = 0;
  Future<void>? _invoiceDetailInFlight;
  int? _invoiceDetailInFlightId;

  int? _paymentListOwnerUserId;
  bool _hasPaymentListData = false;
  int _paymentListSeq = 0;
  Future<void>? _paymentListInFlight;

  int _paymentDetailSeq = 0;
  Future<void>? _paymentDetailInFlight;
  int? _paymentDetailInFlightId;

  int? _paymentMethodsOwnerUserId;
  bool _hasPaymentMethodsData = false;
  int _paymentMethodsSeq = 0;
  Future<void>? _paymentMethodsInFlight;

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

  bool get hasMoreInvoices =>
      invoiceListPage.value * invoiceListLimit.value < invoiceListTotal.value;

  String get invoiceListUpdatedLabel {
    final value = invoiceListUpdatedAt.value;
    return value == null ? '' : AppDates.format(value);
  }

  bool get hasMorePayments =>
      paymentListPage.value * paymentListLimit.value < paymentListTotal.value;

  String get paymentListUpdatedLabel {
    final value = paymentListUpdatedAt.value;
    return value == null ? '' : AppDates.format(value);
  }

  String get paymentMethodsUpdatedLabel {
    final value = paymentMethodsUpdatedAt.value;
    return value == null ? '' : AppDates.format(value);
  }

  PaymentMethodOption? get selectedPaymentMethod {
    final key = selectedPaymentMethodKey.value;
    if (key == null || key.isEmpty) {
      return null;
    }
    for (final method in paymentMethods) {
      if (method.methodKey == key) {
        return method;
      }
    }
    return null;
  }

  List<PaymentMethodOption> get activePaymentMethods =>
      paymentMethods.where((method) => method.isActive).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    _registry?.register(screen, loadPayments);
    _registry?.register(invoiceListScreen, loadInvoices);
    _registry?.register(invoiceDetailScreen, _refreshActiveInvoiceDetail);
    _registry?.register(paymentListScreen, loadPaymentList);
    _registry?.register(paymentDetailScreen, _refreshActivePaymentDetail);
    _registry?.register(paymentMethodsScreen, loadPaymentMethods);

    final session = _session;
    if (session == null) {
      loadPayments();
      return;
    }

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
    _registry?.unregister(invoiceListScreen);
    _registry?.unregister(invoiceDetailScreen);
    _registry?.unregister(paymentListScreen);
    _registry?.unregister(paymentDetailScreen);
    _registry?.unregister(paymentMethodsScreen);
    super.onClose();
  }

  // ---------------------------------------------------------------- balances

  // -------------------------------------------------------- dashboard values

  String get dashboardCurrency =>
      dashboard.value?.outstandingBalance.currency ?? '';

  double get outstandingBalanceAmount =>
      dashboard.value?.outstandingBalance.amount ?? 0;

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
    try {
      await useCases.clearInvoiceListCache();
    } catch (_) {
      // The invoice cache is equally optional at sign-out time.
    }
    try {
      await useCases.clearPaymentListCache();
    } catch (_) {
      // The payment cache is equally optional at sign-out time.
    }
    try {
      await useCases.clearPaymentMethodsCache();
    } catch (_) {
      // The payment methods cache is equally optional at sign-out time.
    }
  }

  void _resetForAccount() {
    _requestSeq++;
    _loadInFlight = null;
    dashboard.value = null;
    selectedInvoice.value = null;
    selectedItems.clear();
    paymentSuccess.value = null;
    paymentFailure.value = null;
    selectedPaymentMethodKey.value = null;
    isPaymentProcessing.value = false;
    isLoading.value = false;
    errorMessage.value = null;
    isShowingCachedData.value = false;
    lastUpdatedAt.value = null;
    _ownerUserId = null;

    _invoiceListSeq++;
    _invoiceListInFlight = null;
    _hasInvoiceListData = false;
    _invoiceListOwnerUserId = null;
    invoiceList.clear();
    invoiceListPage.value = 1;
    invoiceListTotal.value = 0;
    invoiceListStatus.value = 'all';
    isLoadingInvoiceList.value = false;
    isLoadingMoreInvoices.value = false;
    invoiceListError.value = null;
    isShowingCachedInvoices.value = false;
    invoiceListUpdatedAt.value = null;

    _invoiceDetailSeq++;
    _invoiceDetailInFlight = null;
    _invoiceDetailInFlightId = null;
    invoiceDetail.value = null;
    invoiceDetailId.value = null;
    isLoadingInvoiceDetail.value = false;
    invoiceDetailError.value = null;

    _paymentListSeq++;
    _paymentListInFlight = null;
    _hasPaymentListData = false;
    _paymentListOwnerUserId = null;
    paymentList.clear();
    paymentListPage.value = 1;
    paymentListLimit.value = paymentPageSize;
    paymentListTotal.value = 0;
    isLoadingPaymentList.value = false;
    isLoadingMorePayments.value = false;
    paymentListError.value = null;
    isShowingCachedPayments.value = false;
    paymentListUpdatedAt.value = null;

    _paymentDetailSeq++;
    _paymentDetailInFlight = null;
    _paymentDetailInFlightId = null;
    paymentDetail.value = null;
    paymentDetailId.value = null;
    isLoadingPaymentDetail.value = false;
    paymentDetailError.value = null;

    _paymentMethodsSeq++;
    _paymentMethodsInFlight = null;
    _hasPaymentMethodsData = false;
    _paymentMethodsOwnerUserId = null;
    paymentMethods.clear();
    selectedPaymentMethodKey.value = null;
    isLoadingPaymentMethods.value = false;
    paymentMethodsError.value = null;
    isShowingCachedPaymentMethods.value = false;
    paymentMethodsUpdatedAt.value = null;
  }


  // ----------------------------------------------------------- payment list

  Future<void> loadPaymentList({bool refresh = false}) {
    final existing = _paymentListInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadPaymentList(refresh: refresh);
    _paymentListInFlight = future;
    return future.whenComplete(() {
      if (identical(_paymentListInFlight, future)) {
        _paymentListInFlight = null;
      }
    });
  }

  Future<void> _loadPaymentList({required bool refresh}) async {
    final session = _session;
    final userId = _currentUserId;
    if (session != null && userId == null) {
      return;
    }

    final seq = ++_paymentListSeq;
    final hadData = _hasPaymentListData && _paymentListOwnerUserId == userId;
    isLoadingPaymentList.value = !hadData;
    isLoadingMorePayments.value = false;
    paymentListError.value = null;

    if (userId != null && !refresh && !hadData) {
      await _hydratePaymentListFromCache(userId, seq);
      if (seq != _paymentListSeq || userId != _currentUserId) {
        return;
      }
    }

    if (_hasPaymentListData && _connectivity?.isOnline.value == false) {
      isShowingCachedPayments.value = true;
      _registry?.markStale(paymentListScreen);
      isLoadingPaymentList.value = false;
      return;
    }

    try {
      final response = await useCases.getPaymentList(
        page: 1,
        limit: paymentPageSize,
      );
      if (seq != _paymentListSeq || userId != _currentUserId) {
        return;
      }

      paymentList.assignAll(response.items);
      paymentListPage.value = response.page <= 0 ? 1 : response.page;
      paymentListLimit.value = response.limit <= 0
          ? paymentPageSize
          : response.limit;
      paymentListTotal.value = response.total < response.items.length
          ? response.items.length
          : response.total;
      _hasPaymentListData = true;
      _paymentListOwnerUserId = userId;
      isShowingCachedPayments.value = false;
      paymentListUpdatedAt.value = DateTime.now();
      paymentListError.value = null;
      _registry?.markFresh(paymentListScreen);

      if (userId != null) {
        try {
          await useCases.cachePaymentList(userId, response);
        } catch (_) {
          // A cache write is a convenience; the API response is still usable.
        }
      }
    } on AppException catch (error) {
      if (seq != _paymentListSeq || userId != _currentUserId) {
        return;
      }
      _handlePaymentListFailure(error);
    } catch (_) {
      if (seq != _paymentListSeq || userId != _currentUserId) {
        return;
      }
      _handlePaymentListFailure(null);
    } finally {
      if (seq == _paymentListSeq) {
        isLoadingPaymentList.value = false;
      }
    }
  }

  Future<void> loadMorePayments() async {
    if (isLoadingPaymentList.value ||
        isLoadingMorePayments.value ||
        !hasMorePayments) {
      return;
    }
    if (_connectivity?.isOnline.value == false && _hasPaymentListData) {
      isShowingCachedPayments.value = true;
      _registry?.markStale(paymentListScreen);
      return;
    }

    final userId = _currentUserId;
    final seq = _paymentListSeq;
    final nextPage = paymentListPage.value + 1;
    isLoadingMorePayments.value = true;
    paymentListError.value = null;
    try {
      final response = await useCases.getPaymentList(
        page: nextPage,
        limit: paymentListLimit.value,
      );
      if (seq != _paymentListSeq || userId != _currentUserId) {
        return;
      }
      final knownIds = paymentList.map((payment) => payment.id).toSet();
      paymentList.addAll(
        response.items.where((payment) => !knownIds.contains(payment.id)),
      );
      paymentListPage.value = response.page <= 0 ? nextPage : response.page;
      paymentListLimit.value = response.limit <= 0
          ? paymentListLimit.value
          : response.limit;
      // An empty page means the API has nothing older to return, whatever the
      // reported total says. Stop asking instead of looping on the same page.
      paymentListTotal.value = response.items.isEmpty
          ? paymentList.length
          : (response.total < paymentList.length
                ? paymentList.length
                : response.total);
      _hasPaymentListData = true;
      _paymentListOwnerUserId = userId;
      isShowingCachedPayments.value = false;
      _registry?.markFresh(paymentListScreen);
    } on AppException catch (error) {
      if (seq == _paymentListSeq && userId == _currentUserId) {
        paymentListError.value = error.message;
        if (error is ApiException && error.isRetryable) {
          _registry?.markStale(paymentListScreen);
        }
      }
    } catch (_) {
      if (seq == _paymentListSeq && userId == _currentUserId) {
        paymentListError.value = 'Unable to load more payments.';
      }
    } finally {
      if (seq == _paymentListSeq) {
        isLoadingMorePayments.value = false;
      }
    }
  }

  Future<void> _hydratePaymentListFromCache(int userId, int seq) async {
    try {
      final cached = await useCases.getCachedPaymentList(userId);
      if (cached == null ||
          seq != _paymentListSeq ||
          userId != _currentUserId) {
        return;
      }
      paymentList.assignAll(cached.response.items);
      paymentListPage.value = cached.response.page;
      paymentListLimit.value = cached.response.limit;
      paymentListTotal.value = cached.response.total;
      _hasPaymentListData = true;
      _paymentListOwnerUserId = userId;
      isShowingCachedPayments.value = true;
      paymentListUpdatedAt.value = cached.updatedAt;
      paymentListError.value = null;
    } catch (_) {
      // A broken cache read must not stop the API request.
    }
  }

  void _handlePaymentListFailure(Object? error) {
    if (_hasPaymentListData) {
      isShowingCachedPayments.value = true;
    } else {
      paymentListError.value = error is AppException
          ? error.message
          : 'Unable to load payments.';
    }
    if (error is ApiException && error.isRetryable) {
      _registry?.markStale(paymentListScreen);
    }
  }

  // --------------------------------------------------------- payment detail

  Future<void> loadPaymentDetail(int id, {bool force = false}) {
    if (id <= 0) {
      return Future<void>.value();
    }
    final existing = _paymentDetailInFlight;
    if (existing != null && _paymentDetailInFlightId == id) {
      return existing;
    }
    final future = _fetchPaymentDetail(id);
    _paymentDetailInFlight = future;
    _paymentDetailInFlightId = id;
    return future.whenComplete(() {
      if (identical(_paymentDetailInFlight, future)) {
        _paymentDetailInFlight = null;
        _paymentDetailInFlightId = null;
      }
    });
  }

  Future<void> _fetchPaymentDetail(int id) async {
    final session = _session;
    final userId = _currentUserId;
    if (session != null && userId == null) {
      return;
    }

    final seq = ++_paymentDetailSeq;
    if (paymentDetailId.value != id) {
      paymentDetail.value = null;
    }
    paymentDetailId.value = id;
    paymentDetailError.value = null;
    isLoadingPaymentDetail.value = paymentDetail.value == null;

    try {
      final detail = await useCases.getPaymentDetail(id);
      if (seq != _paymentDetailSeq ||
          userId != _currentUserId ||
          paymentDetailId.value != id) {
        return;
      }
      paymentDetail.value = detail;
      paymentDetailError.value = null;
      _registry?.markFresh(paymentDetailScreen);
    } on AppException catch (error) {
      if (seq != _paymentDetailSeq ||
          userId != _currentUserId ||
          paymentDetailId.value != id) {
        return;
      }
      paymentDetailError.value = error.message;
      if (error is ApiException && error.isRetryable) {
        _registry?.markStale(paymentDetailScreen);
      }
    } catch (_) {
      if (seq != _paymentDetailSeq ||
          userId != _currentUserId ||
          paymentDetailId.value != id) {
        return;
      }
      paymentDetailError.value = 'Unable to load payment details.';
    } finally {
      if (seq == _paymentDetailSeq) {
        isLoadingPaymentDetail.value = false;
      }
    }
  }

  Future<void> _refreshActivePaymentDetail() async {
    final id = paymentDetailId.value;
    if (id == null || id <= 0) {
      return;
    }
    await loadPaymentDetail(id, force: true);
  }

  // --------------------------------------------------------- payment methods

  Future<void> loadPaymentMethods({bool refresh = false}) {
    final existing = _paymentMethodsInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadPaymentMethods(refresh: refresh);
    _paymentMethodsInFlight = future;
    return future.whenComplete(() {
      if (identical(_paymentMethodsInFlight, future)) {
        _paymentMethodsInFlight = null;
      }
    });
  }

  Future<void> _loadPaymentMethods({required bool refresh}) async {
    final session = _session;
    final userId = _currentUserId;
    if (session != null && userId == null) {
      return;
    }

    final seq = ++_paymentMethodsSeq;
    final hadData =
        _hasPaymentMethodsData && _paymentMethodsOwnerUserId == userId;
    isLoadingPaymentMethods.value = !hadData;
    paymentMethodsError.value = null;

    if (userId != null && !refresh && !hadData) {
      await _hydratePaymentMethodsFromCache(userId, seq);
      if (seq != _paymentMethodsSeq || userId != _currentUserId) {
        return;
      }
    }

    if (_hasPaymentMethodsData && _connectivity?.isOnline.value == false) {
      isShowingCachedPaymentMethods.value = true;
      _registry?.markStale(paymentMethodsScreen);
      isLoadingPaymentMethods.value = false;
      return;
    }

    try {
      final methods = await useCases.getPaymentMethods();
      if (seq != _paymentMethodsSeq || userId != _currentUserId) {
        return;
      }

      paymentMethods.assignAll(methods);
      _hasPaymentMethodsData = true;
      _paymentMethodsOwnerUserId = userId;
      isShowingCachedPaymentMethods.value = false;
      paymentMethodsUpdatedAt.value = DateTime.now();
      paymentMethodsError.value = null;
      _ensurePaymentMethodSelection();
      _registry?.markFresh(paymentMethodsScreen);

      if (userId != null) {
        try {
          await useCases.cachePaymentMethods(userId, methods);
        } catch (_) {
          // A cache write is a convenience; the API response is still usable.
        }
      }
    } on AppException catch (error) {
      if (seq != _paymentMethodsSeq || userId != _currentUserId) {
        return;
      }
      _handlePaymentMethodsFailure(error);
    } catch (_) {
      if (seq != _paymentMethodsSeq || userId != _currentUserId) {
        return;
      }
      _handlePaymentMethodsFailure(null);
    } finally {
      if (seq == _paymentMethodsSeq) {
        isLoadingPaymentMethods.value = false;
      }
    }
  }

  Future<void> _hydratePaymentMethodsFromCache(int userId, int seq) async {
    try {
      final cached = await useCases.getCachedPaymentMethods(userId);
      if (cached == null ||
          seq != _paymentMethodsSeq ||
          userId != _currentUserId) {
        return;
      }
      paymentMethods.assignAll(cached.methods);
      _hasPaymentMethodsData = true;
      _paymentMethodsOwnerUserId = userId;
      isShowingCachedPaymentMethods.value = true;
      paymentMethodsUpdatedAt.value = cached.updatedAt;
      paymentMethodsError.value = null;
      _ensurePaymentMethodSelection();
    } catch (_) {
      // A broken cache read must not stop the API request.
    }
  }

  void _ensurePaymentMethodSelection() {
    final active = activePaymentMethods;
    if (active.isEmpty) {
      selectedPaymentMethodKey.value = null;
      return;
    }
    final key = selectedPaymentMethodKey.value;
    for (final method in active) {
      if (method.methodKey == key) {
        return;
      }
    }
    selectedPaymentMethodKey.value = active.first.methodKey;
  }

  void _handlePaymentMethodsFailure(Object? error) {
    if (_hasPaymentMethodsData) {
      isShowingCachedPaymentMethods.value = true;
    } else {
      paymentMethodsError.value = error is AppException
          ? error.message
          : 'Unable to load payment methods.';
    }
    if (error is ApiException && error.isRetryable) {
      _registry?.markStale(paymentMethodsScreen);
    }
  }

  void selectPaymentMethod(PaymentMethodOption method) {
    if (!method.isActive) {
      return;
    }
    selectedPaymentMethodKey.value = method.methodKey;
  }

  // ----------------------------------------------------------- invoice list

  /// Loads the first invoice page, cache first, then refreshes it from the API.
  ///
  /// Concurrent callers share one request, so opening the screen while a
  /// reconnect refresh is already running cannot issue the same GET twice.
  Future<void> loadInvoices({bool refresh = false}) {
    final existing = _invoiceListInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadInvoices(refresh: refresh);
    _invoiceListInFlight = future;
    return future.whenComplete(() {
      if (identical(_invoiceListInFlight, future)) {
        _invoiceListInFlight = null;
      }
    });
  }

  Future<void> _loadInvoices({required bool refresh}) async {
    final session = _session;
    final userId = _currentUserId;
    if (session != null && userId == null) {
      return;
    }

    final status = invoiceListStatus.value;
    final seq = ++_invoiceListSeq;
    final hadData = _hasInvoiceListData && _invoiceListOwnerUserId == userId;
    isLoadingInvoiceList.value = !hadData;
    // A first-page reload supersedes any page request that was still running.
    isLoadingMoreInvoices.value = false;
    invoiceListError.value = null;

    if (userId != null && !refresh && !hadData) {
      await _hydrateInvoiceListFromCache(userId, status, seq);
      if (seq != _invoiceListSeq ||
          userId != _currentUserId ||
          status != invoiceListStatus.value) {
        return;
      }
    }

    // A cached snapshot is enough while offline; the registry refreshes it when
    // connectivity returns.
    if (_hasInvoiceListData && _connectivity?.isOnline.value == false) {
      isShowingCachedInvoices.value = true;
      _registry?.markStale(invoiceListScreen);
      isLoadingInvoiceList.value = false;
      return;
    }

    try {
      final response = await useCases.getInvoiceList(
        page: 1,
        limit: invoiceListLimit.value <= 0
            ? invoicePageSize
            : invoiceListLimit.value,
        status: status,
      );
      if (seq != _invoiceListSeq ||
          userId != _currentUserId ||
          status != invoiceListStatus.value) {
        return;
      }

      invoiceList.assignAll(response.items);
      invoiceListPage.value = response.page <= 0 ? 1 : response.page;
      invoiceListLimit.value = response.limit <= 0
          ? invoicePageSize
          : response.limit;
      invoiceListTotal.value = response.total < response.items.length
          ? response.items.length
          : response.total;
      _hasInvoiceListData = true;
      _invoiceListOwnerUserId = userId;
      isShowingCachedInvoices.value = false;
      invoiceListUpdatedAt.value = DateTime.now();
      invoiceListError.value = null;
      _registry?.markFresh(invoiceListScreen);

      // Only a fully parsed first page reaches this point, so it is safe to
      // keep. Later pages are deliberately never cached.
      if (userId != null) {
        try {
          await useCases.cacheInvoiceList(userId, status, response);
        } catch (_) {
          // A cache write is a convenience; the API response is still usable.
        }
      }
    } on AppException catch (error) {
      if (seq != _invoiceListSeq ||
          userId != _currentUserId ||
          status != invoiceListStatus.value) {
        return;
      }
      _handleInvoiceListFailure(error);
    } catch (_) {
      if (seq != _invoiceListSeq ||
          userId != _currentUserId ||
          status != invoiceListStatus.value) {
        return;
      }
      _handleInvoiceListFailure(null);
    } finally {
      if (seq == _invoiceListSeq) {
        isLoadingInvoiceList.value = false;
      }
    }
  }

  Future<void> loadMoreInvoices() async {
    if (isLoadingInvoiceList.value ||
        isLoadingMoreInvoices.value ||
        !hasMoreInvoices) {
      return;
    }
    if (_connectivity?.isOnline.value == false && _hasInvoiceListData) {
      isShowingCachedInvoices.value = true;
      _registry?.markStale(invoiceListScreen);
      return;
    }

    final status = invoiceListStatus.value;
    final userId = _currentUserId;
    final seq = _invoiceListSeq;
    final nextPage = invoiceListPage.value + 1;
    isLoadingMoreInvoices.value = true;
    invoiceListError.value = null;
    try {
      final response = await useCases.getInvoiceList(
        page: nextPage,
        limit: invoiceListLimit.value,
        status: status,
      );
      if (seq != _invoiceListSeq ||
          userId != _currentUserId ||
          status != invoiceListStatus.value) {
        return;
      }
      final knownIds = invoiceList.map((invoice) => invoice.id).toSet();
      invoiceList.addAll(
        response.items.where((invoice) => !knownIds.contains(invoice.id)),
      );
      invoiceListPage.value = response.page <= 0 ? nextPage : response.page;
      invoiceListLimit.value = response.limit <= 0
          ? invoiceListLimit.value
          : response.limit;
      invoiceListTotal.value = response.total < invoiceList.length
          ? invoiceList.length
          : response.total;
      _hasInvoiceListData = true;
      _invoiceListOwnerUserId = userId;
      isShowingCachedInvoices.value = false;
      _registry?.markFresh(invoiceListScreen);
    } on AppException catch (error) {
      if (seq == _invoiceListSeq && userId == _currentUserId) {
        _handleInvoiceListFailure(error);
      }
    } catch (_) {
      if (seq == _invoiceListSeq && userId == _currentUserId) {
        _handleInvoiceListFailure(null);
      }
    } finally {
      if (seq == _invoiceListSeq) {
        isLoadingMoreInvoices.value = false;
      }
    }
  }

  /// Switches the status filter and reloads its own cache snapshot.
  Future<void> selectInvoiceListStatus(String status) async {
    final normalized = status.trim().isEmpty
        ? 'all'
        : status.trim().toLowerCase();
    if (normalized == invoiceListStatus.value && _hasInvoiceListData) {
      return;
    }
    invoiceListStatus.value = normalized;
    _invoiceListSeq++;
    _invoiceListInFlight = null;
    _hasInvoiceListData = false;
    _invoiceListOwnerUserId = null;
    invoiceList.clear();
    invoiceListPage.value = 1;
    invoiceListTotal.value = 0;
    invoiceListError.value = null;
    isShowingCachedInvoices.value = false;
    invoiceListUpdatedAt.value = null;
    isLoadingMoreInvoices.value = false;
    await loadInvoices();
  }

  Future<void> _hydrateInvoiceListFromCache(
    int userId,
    String status,
    int seq,
  ) async {
    try {
      final cached = await useCases.getCachedInvoiceList(userId, status);
      if (cached == null ||
          seq != _invoiceListSeq ||
          userId != _currentUserId ||
          status != invoiceListStatus.value) {
        return;
      }
      invoiceList.assignAll(cached.response.items);
      invoiceListPage.value = cached.response.page;
      invoiceListLimit.value = cached.response.limit;
      invoiceListTotal.value = cached.response.total;
      _hasInvoiceListData = true;
      _invoiceListOwnerUserId = userId;
      isShowingCachedInvoices.value = true;
      invoiceListUpdatedAt.value = cached.updatedAt;
      invoiceListError.value = null;
    } catch (_) {
      // A broken cache read must not stop the API request.
    }
  }

  void _handleInvoiceListFailure(Object? error) {
    if (_hasInvoiceListData) {
      isShowingCachedInvoices.value = true;
    } else {
      invoiceListError.value = error is AppException
          ? error.message
          : 'Unable to load invoices.';
    }
    if (error is ApiException && error.isRetryable) {
      _registry?.markStale(invoiceListScreen);
    }
  }

  // --------------------------------------------------------- invoice detail

  /// Loads one invoice detail from the API.
  ///
  /// There is intentionally no cache read here: an invoice is server
  /// authoritative, and a stale list row must never stand in for a detail.
  Future<void> loadInvoiceDetail(int id, {bool force = false}) {
    final existing = _invoiceDetailInFlight;
    if (existing != null && _invoiceDetailInFlightId == id) {
      return existing;
    }
    final future = _fetchInvoiceDetail(id);
    _invoiceDetailInFlight = future;
    _invoiceDetailInFlightId = id;
    return future.whenComplete(() {
      if (identical(_invoiceDetailInFlight, future)) {
        _invoiceDetailInFlight = null;
        _invoiceDetailInFlightId = null;
      }
    });
  }

  Future<void> _fetchInvoiceDetail(int id) async {
    final session = _session;
    final userId = _currentUserId;
    if (session != null && userId == null) {
      return;
    }

    final seq = ++_invoiceDetailSeq;
    if (invoiceDetailId.value != id) {
      invoiceDetail.value = null;
    }
    invoiceDetailId.value = id;
    invoiceDetailError.value = null;
    isLoadingInvoiceDetail.value = invoiceDetail.value == null;

    try {
      final detail = await useCases.getInvoiceDetail(id);
      if (seq != _invoiceDetailSeq ||
          userId != _currentUserId ||
          invoiceDetailId.value != id) {
        return;
      }
      invoiceDetail.value = detail;
      invoiceDetailError.value = null;
      _registry?.markFresh(invoiceDetailScreen);
    } on AppException catch (error) {
      if (seq != _invoiceDetailSeq ||
          userId != _currentUserId ||
          invoiceDetailId.value != id) {
        return;
      }
      invoiceDetailError.value = error.message;
      if (error is ApiException && error.isRetryable) {
        _registry?.markStale(invoiceDetailScreen);
      }
    } catch (_) {
      if (seq != _invoiceDetailSeq ||
          userId != _currentUserId ||
          invoiceDetailId.value != id) {
        return;
      }
      invoiceDetailError.value = 'Unable to load invoice details.';
    } finally {
      if (seq == _invoiceDetailSeq) {
        isLoadingInvoiceDetail.value = false;
      }
    }
  }

  Future<void> _refreshActiveInvoiceDetail() async {
    final id = invoiceDetailId.value;
    if (id == null || id <= 0) {
      return;
    }
    await loadInvoiceDetail(id, force: true);
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
    selectedPaymentMethodKey.value = null;
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

  double get selectedTotal =>
      selectedItems.fold(0, (total, item) => total + item.dueAmount);

  int get selectedCount => selectedItems.length;

  // ---------------------------------------------------------------- payment

  /// Submits the selected invoice and payment method to the API.
  ///
  /// The backend response is authoritative: it supplies the payment id,
  /// number, amount, status, timestamp and proof image. No local result is
  /// created when the request fails.
  Future<Payment?> confirmPayment({
    String? proofPath,
    String? proofFileName,
    required String transactionId,
  }) async {
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

    final method = selectedPaymentMethod;
    if (method == null || !method.isActive || method.id <= 0) {
      errorMessage.value = 'Select an available payment method first.';
      return null;
    }
    if (method.requiresProof && (proofPath?.trim() ?? '').isEmpty) {
      errorMessage.value = 'Attach proof of payment to continue.';
      return null;
    }

    isPaymentProcessing.value = true;
    errorMessage.value = null;
    paymentSuccess.value = null;
    paymentFailure.value = null;

    final payment = Payment(
      id: '',
      invoiceNumber: invoice.number,
      residentName: _session?.name ?? '',
      unitLabel: invoice.unitLabel,
      items: List<InvoiceItem>.unmodifiable(selectedItems),
      amount: selectedTotal,
      date: AppDates.format(DateTime.now()),
      method: paymentMethodFromCode(method.code),
      status: PaymentStatus.unknown,
      transactionId: transactionId.trim(),
      paymentMethodCode: method.code,
      paymentMethodName: method.displayName,
      proofPath: proofPath,
      proofFileName: proofFileName,
      paymentMethodId: method.id,
      quoteId: invoice.number,
      currency: invoice.currency,
    );

    try {
      final stored = await useCases.submitPayment(payment);
      if (stored.isSuccessful) {
        paymentSuccess.value = stored;
      } else {
        paymentFailure.value = stored;
      }
      await _refreshAfterSubmission(invoice);
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

  Future<void> _refreshAfterSubmission(Invoice invoice) async {
    try {
      await useCases.clearDashboardCache();
    } catch (_) {
    }
    try {
      await useCases.clearInvoiceListCache();
    } catch (_) {
    }
    try {
      await useCases.clearPaymentListCache();
    } catch (_) {
    }

    await loadPayments();

    final invoiceId = int.tryParse(invoice.id);
    if (invoiceId != null &&
        invoiceId > 0 &&
        invoiceDetailId.value == invoiceId) {
      await loadInvoiceDetail(invoiceId, force: true);
    }
    // Invoice list refresh is handled by the caller when needed.
  }
}

