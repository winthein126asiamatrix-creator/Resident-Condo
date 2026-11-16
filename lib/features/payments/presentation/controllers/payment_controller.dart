import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
import '../../../../core/network/dio_api_service.dart';
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
  static const String invoiceSelectionScreen = 'payments:invoice-selection';
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

  // ------------------------------------------------------ invoice selection

  /// Every payable invoice across all pages, used by Pay Now and the selection
  /// screen. It is never limited to the first page.
  final payableInvoices = <InvoiceListItem>[].obs;
  final isLoadingPayableInvoices = false.obs;
  final payableInvoicesError = RxnString();
  final isShowingCachedPayableInvoices = false.obs;
  final payableInvoicesUpdatedAt = Rxn<DateTime>();

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
  final isDownloadingReceipt = false.obs;

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

  final Map<String, _InvoiceListFilterState> _invoiceListStates =
      <String, _InvoiceListFilterState>{};

  int? _payableInvoicesOwnerUserId;
  bool _hasPayableInvoicesData = false;
  int _payableInvoicesSeq = 0;
  Future<void>? _payableInvoicesInFlight;

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

  String get payableInvoicesUpdatedLabel {
    final value = payableInvoicesUpdatedAt.value;
    return value == null ? '' : AppDates.format(value);
  }

  /// How many invoices the dashboard says still carry a balance.
  int get openInvoiceCount {
    final summary = invoiceSummary;
    if (summary != null) {
      return summary.open;
    }
    return recentInvoices
        .where((invoice) => invoice.id > 0 && invoice.remainingAmount > 0)
        .length;
  }

  /// The single open invoice on the dashboard, when exactly one is visible.
  RecentInvoice? get singleOpenInvoice {
    final open = recentInvoices
        .where((invoice) => invoice.id > 0 && invoice.remainingAmount > 0)
        .toList(growable: false);
    return open.length == 1 ? open.first : null;
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
    _registry?.register(
      invoiceSelectionScreen,
      () => loadPayableInvoices(refresh: true),
    );
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
    _registry?.unregister(invoiceSelectionScreen);
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

    _resetInvoiceListFilters(resetStatus: true);
    _resetPayableInvoices();

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
    isDownloadingReceipt.value = false;

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

  Future<void> downloadReceipt(
    Object? receiptOrDetail, {
    String? receiptNumber,
  }) async {
    if (isDownloadingReceipt.value) {
      return;
    }
    String url = '';
    String resolvedReceiptNumber = receiptNumber?.trim() ?? '';
    if (receiptOrDetail is PaymentDetail) {
      url = receiptOrDetail.receipt?.downloadUrl ?? '';
      if (resolvedReceiptNumber.isEmpty) {
        resolvedReceiptNumber = receiptOrDetail.receipt?.receiptNumber ?? '';
      }
    } else if (receiptOrDetail is PaymentReceiptInfo) {
      url = receiptOrDetail.downloadUrl;
      if (resolvedReceiptNumber.isEmpty) {
        resolvedReceiptNumber = receiptOrDetail.receiptNumber;
      }
    } else if (receiptOrDetail is String) {
      url = receiptOrDetail;
    } else if (receiptOrDetail != null) {
      url = receiptOrDetail.toString();
    }

    url = url.trim();
    if (url.isEmpty) {
      throw const FormatException('Receipt download URL is missing.');
    }

    isDownloadingReceipt.value = true;
    try {
      final response = await useCases.downloadReceipt(url);
      await _saveReceiptToGallery(
        response,
        receiptNumber: resolvedReceiptNumber,
      );
    } finally {
      isDownloadingReceipt.value = false;
    }
  }

  Future<void> _saveReceiptToGallery(
    ApiBinaryResponse response, {
    required String receiptNumber,
  }) async {
    final contentType = (response.contentType ?? '').toLowerCase();
    final bytes = response.bytes;
    final baseName = receiptNumber.trim().isEmpty
        ? 'receipt'
        : receiptNumber.trim();

    final isImage = contentType.startsWith('image/') || _looksLikeImage(bytes);
    final isPdf = contentType.contains('pdf') || _looksLikePdf(bytes);

    if (isImage) {
      await Gal.putImageBytes(bytes, name: baseName);
      return;
    }
    if (isPdf) {
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      await Directory(directory.path).create(recursive: true);
      final file = File(p.join(directory.path, '$baseName.pdf'));
      await file.writeAsBytes(bytes, flush: true);
      return;
    }
    throw const FormatException('Unsupported receipt format.');
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 4) {
      return false;
    }
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return true;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true;
    }
    return false;
  }

  bool _looksLikePdf(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
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
  /// Each status filter keeps its own request, so concurrent callers on the same
  /// filter share one request while a different filter is still free to load.
  Future<void> loadInvoices({bool refresh = false}) {
    final state = _invoiceListState(invoiceListStatus.value);
    final existing = state.inFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadInvoices(state, refresh: refresh);
    state.inFlight = future;
    return future.whenComplete(() {
      if (identical(state.inFlight, future)) {
        state.inFlight = null;
      }
    });
  }

  /// Re-publishes the selected filter, loading it only if it has never loaded.
  ///
  /// Reopening the screen, or switching back to a filter that already has data,
  /// must not issue another request.
  Future<void> ensureInvoiceListLoaded() {
    final state = _invoiceListStates[invoiceListStatus.value];
    if (state != null && (state.loaded || state.loading)) {
      _publishInvoiceListState(state);
      return state.inFlight ?? Future<void>.value();
    }
    return loadInvoices();
  }

  Future<void> _loadInvoices(
    _InvoiceListFilterState state, {
    required bool refresh,
  }) async {
    final session = _session;
    final userId = _currentUserId;
    if (session != null && userId == null) {
      return;
    }

    final seq = state.seq + 1;
    state.seq = seq;
    final hadData = state.loaded && state.ownerUserId == userId;
    state.loading = !hadData;
    // A first-page reload supersedes any page request that was still running.
    state.loadingMore = false;
    state.error = null;

    if (_isInvoiceListSelected(state)) {
      isLoadingInvoiceList.value = state.loading;
      isLoadingMoreInvoices.value = false;
      invoiceListError.value = null;
    }

    if (userId != null && !refresh && !hadData) {
      await _hydrateInvoiceListFromCache(state, userId, seq);
      if (!_isInvoiceListCurrent(state, seq, userId)) {
        return;
      }
    }

    // A cached snapshot is enough while offline; the registry refreshes it when
    // connectivity returns.
    if (state.loaded && _connectivity?.isOnline.value == false) {
      state.loading = false;
      state.showingCached = true;
      if (_isInvoiceListSelected(state)) {
        _publishInvoiceListState(state);
        _registry?.markStale(invoiceListScreen);
      }
      return;
    }

    try {
      final response = await useCases.getInvoiceList(
        page: 1,
        limit: state.limit <= 0 ? invoicePageSize : state.limit,
        status: state.status,
      );
      if (!_isInvoiceListCurrent(state, seq, userId)) {
        return;
      }

      state.items
        ..clear()
        ..addAll(response.items);
      state.page = response.page <= 0 ? 1 : response.page;
      state.limit = response.limit <= 0 ? invoicePageSize : response.limit;
      state.total = response.total < response.items.length
          ? response.items.length
          : response.total;
      state.loaded = true;
      state.ownerUserId = userId;
      state.showingCached = false;
      state.updatedAt = DateTime.now();
      state.error = null;
      state.loading = false;

      if (_isInvoiceListSelected(state)) {
        _publishInvoiceListState(state);
        _registry?.markFresh(invoiceListScreen);
      }

      // Only a fully parsed first page reaches this point, so it is safe to
      // keep. Later pages are deliberately never cached.
      if (userId != null) {
        try {
          await useCases.cacheInvoiceList(userId, state.status, response);
        } catch (_) {
          // A cache write is a convenience; the API response is still usable.
        }
      }
    } on AppException catch (error) {
      if (!_isInvoiceListCurrent(state, seq, userId)) {
        return;
      }
      _handleInvoiceListFailure(state, error);
    } catch (_) {
      if (!_isInvoiceListCurrent(state, seq, userId)) {
        return;
      }
      _handleInvoiceListFailure(state, null);
    } finally {
      if (state.seq == seq) {
        state.loading = false;
        if (_isInvoiceListSelected(state)) {
          isLoadingInvoiceList.value = false;
        }
      }
    }
  }

  Future<void> loadMoreInvoices() async {
    final state = _invoiceListStates[invoiceListStatus.value];
    if (state == null || !state.loaded) {
      return;
    }
    if (state.loading || state.loadingMore) {
      return;
    }
    if (!_hasMoreInvoicePages(state)) {
      return;
    }
    if (_connectivity?.isOnline.value == false) {
      state.showingCached = true;
      if (_isInvoiceListSelected(state)) {
        isShowingCachedInvoices.value = true;
        _registry?.markStale(invoiceListScreen);
      }
      return;
    }

    final userId = _currentUserId;
    final seq = state.seq;
    final nextPage = state.page + 1;
    state.loadingMore = true;
    state.error = null;
    if (_isInvoiceListSelected(state)) {
      isLoadingMoreInvoices.value = true;
      invoiceListError.value = null;
    }
    try {
      final response = await useCases.getInvoiceList(
        page: nextPage,
        limit: state.limit,
        status: state.status,
      );
      if (!_isInvoiceListCurrent(state, seq, userId)) {
        return;
      }
      final knownIds = state.items.map((invoice) => invoice.id).toSet();
      state.items.addAll(
        response.items.where((invoice) => !knownIds.contains(invoice.id)),
      );
      state.page = response.page <= 0 ? nextPage : response.page;
      state.limit = response.limit <= 0 ? state.limit : response.limit;
      state.total = response.total < state.items.length
          ? state.items.length
          : response.total;
      state.loaded = true;
      state.ownerUserId = userId;
      state.showingCached = false;
      if (_isInvoiceListSelected(state)) {
        _publishInvoiceListState(state);
        _registry?.markFresh(invoiceListScreen);
      }
    } on AppException catch (error) {
      if (_isInvoiceListCurrent(state, seq, userId)) {
        _handleInvoiceListFailure(state, error);
      }
    } catch (_) {
      if (_isInvoiceListCurrent(state, seq, userId)) {
        _handleInvoiceListFailure(state, null);
      }
    } finally {
      if (state.seq == seq) {
        state.loadingMore = false;
        if (_isInvoiceListSelected(state)) {
          isLoadingMoreInvoices.value = false;
        }
      }
    }
  }

  /// Switches the status filter.
  ///
  /// A filter that already finished loading is shown straight from memory. Only
  /// a filter that has never loaded (or previously failed) touches the cache and
  /// the API, so flipping back and forth never repeats a request.
  Future<void> selectInvoiceListStatus(String status) async {
    final normalized = status.trim().isEmpty
        ? 'all'
        : status.trim().toLowerCase();
    if (normalized == invoiceListStatus.value) {
      final state = _invoiceListStates[normalized];
      if (state != null && state.loaded) {
        _publishInvoiceListState(state);
        return;
      }
      await loadInvoices();
      return;
    }

    invoiceListStatus.value = normalized;
    final state = _invoiceListStates[normalized];
    if (state != null && state.loaded) {
      _publishInvoiceListState(state);
      return;
    }
    _publishInvoiceListState(state ?? _InvoiceListFilterState(normalized));
    await loadInvoices();
  }

  Future<void> _hydrateInvoiceListFromCache(
    _InvoiceListFilterState state,
    int userId,
    int seq,
  ) async {
    try {
      final cached = await useCases.getCachedInvoiceList(userId, state.status);
      if (cached == null || !_isInvoiceListCurrent(state, seq, userId)) {
        return;
      }
      state.items
        ..clear()
        ..addAll(cached.response.items);
      state.page = cached.response.page;
      state.limit = cached.response.limit;
      state.total = cached.response.total;
      state.loaded = true;
      state.ownerUserId = userId;
      state.showingCached = true;
      state.updatedAt = cached.updatedAt;
      state.error = null;
      if (_isInvoiceListSelected(state)) {
        _publishInvoiceListState(state);
      }
    } catch (_) {
      // A broken cache read must not stop the API request.
    }
  }

  void _handleInvoiceListFailure(_InvoiceListFilterState state, Object? error) {
    state.loading = false;
    if (state.loaded) {
      state.showingCached = true;
    } else {
      state.error = error is AppException
          ? error.message
          : 'Unable to load invoices.';
    }
    if (_isInvoiceListSelected(state)) {
      _publishInvoiceListState(state);
      if (error is ApiException && error.isRetryable) {
        _registry?.markStale(invoiceListScreen);
      }
    }
  }

  _InvoiceListFilterState _invoiceListState(String status) {
    return _invoiceListStates.putIfAbsent(
      status,
      () => _InvoiceListFilterState(status),
    );
  }

  bool _isInvoiceListCurrent(
    _InvoiceListFilterState state,
    int seq,
    int? userId,
  ) {
    return state.seq == seq &&
        userId == _currentUserId &&
        identical(_invoiceListStates[state.status], state);
  }

  bool _isInvoiceListSelected(_InvoiceListFilterState state) {
    return state.status == invoiceListStatus.value &&
        identical(_invoiceListStates[state.status], state);
  }

  bool _hasMoreInvoicePages(_InvoiceListFilterState state) {
    return state.loaded && state.page * state.limit < state.total;
  }

  void _publishInvoiceListState(_InvoiceListFilterState state) {
    invoiceList.assignAll(state.items);
    invoiceListPage.value = state.page;
    invoiceListLimit.value = state.limit;
    invoiceListTotal.value = state.total;
    isLoadingInvoiceList.value = state.loading;
    isLoadingMoreInvoices.value = state.loadingMore;
    invoiceListError.value = state.error;
    isShowingCachedInvoices.value = state.showingCached;
    invoiceListUpdatedAt.value = state.updatedAt;
  }

  /// Drops every in-memory invoice filter page. In-flight responses are
  /// invalidated by bumping each filter's sequence number.
  void _resetInvoiceListFilters({bool resetStatus = false}) {
    for (final state in _invoiceListStates.values) {
      state.seq = state.seq + 1;
      state.inFlight = null;
      state.loaded = false;
      state.loading = false;
      state.loadingMore = false;
      state.error = null;
      state.showingCached = false;
      state.updatedAt = null;
      state.ownerUserId = null;
      state.items.clear();
    }
    _invoiceListStates.clear();
    if (resetStatus) {
      invoiceListStatus.value = 'all';
    }
    invoiceList.assignAll(const <InvoiceListItem>[]);
    invoiceListPage.value = 1;
    invoiceListLimit.value = invoicePageSize;
    invoiceListTotal.value = 0;
    isLoadingInvoiceList.value = false;
    isLoadingMoreInvoices.value = false;
    invoiceListError.value = null;
    isShowingCachedInvoices.value = false;
    invoiceListUpdatedAt.value = null;
  }

  // ------------------------------------------------------ invoice selection

  /// Loads every invoice that can still receive a payment.
  ///
  /// The selection screen must show invoices from every page, so this walks the
  /// paginated list instead of trusting the first page. A completed "All"
  /// filter is reused as-is; otherwise the in-memory rows and the cached
  /// snapshot only seed the pages that still need fetching.
  Future<void> loadPayableInvoices({bool refresh = false}) {
    final existing = _payableInvoicesInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadPayableInvoices(refresh: refresh);
    _payableInvoicesInFlight = future;
    return future.whenComplete(() {
      if (identical(_payableInvoicesInFlight, future)) {
        _payableInvoicesInFlight = null;
      }
    });
  }

  Future<void> _loadPayableInvoices({required bool refresh}) async {
    final session = _session;
    final userId = _currentUserId;
    if (session != null && userId == null) {
      return;
    }

    final seq = ++_payableInvoicesSeq;
    final hadData =
        _hasPayableInvoicesData && _payableInvoicesOwnerUserId == userId;
    isLoadingPayableInvoices.value = !hadData;
    payableInvoicesError.value = null;

    final allState = _invoiceListStates['all'];
    final canReuseAllState =
        allState != null &&
        allState.loaded &&
        allState.ownerUserId == userId &&
        !_hasMoreInvoicePages(allState);
    if (!refresh && canReuseAllState) {
      _publishPayableInvoices(
        allState.items.where((invoice) => invoice.isPayable).toList(),
        userId,
        showingCached: allState.showingCached,
        updatedAt: allState.updatedAt,
      );
      if (allState.showingCached) {
        _registry?.markStale(invoiceSelectionScreen);
      }
      return;
    }

    var collected = <InvoiceListItem>[];
    var nextPage = 1;
    var showingCached = false;
    DateTime? updatedAt;

    if (!refresh &&
        allState != null &&
        allState.loaded &&
        allState.ownerUserId == userId) {
      collected = allState.items.where((invoice) => invoice.isPayable).toList();
      nextPage = allState.page + 1;
      showingCached = allState.showingCached;
      updatedAt = allState.updatedAt;
    }

    if (_connectivity?.isOnline.value == false) {
      if (collected.isEmpty && userId != null && !refresh) {
        try {
          final cached = await useCases.getCachedInvoiceList(userId, 'all');
          if (!_isPayableInvoicesCurrent(seq, userId)) {
            return;
          }
          if (cached != null) {
            collected = cached.response.items
                .where((invoice) => invoice.isPayable)
                .toList();
            showingCached = true;
            updatedAt = cached.updatedAt;
          }
        } catch (_) {
          // A broken cache read must not hide the offline state.
        }
        if (!_isPayableInvoicesCurrent(seq, userId)) {
          return;
        }
      }

      if (collected.isEmpty) {
        _handlePayableInvoicesFailure(
          const <InvoiceListItem>[],
          userId,
          'You are offline and no saved invoices are available.',
          null,
        );
        return;
      }
      _publishPayableInvoices(
        collected,
        userId,
        showingCached: true,
        updatedAt: updatedAt,
      );
      _registry?.markStale(invoiceSelectionScreen);
      return;
    }

    // A cached page keeps only ten rows, so restart at page one when the API
    // is reachable instead of skipping the rows the cache dropped.
    if (showingCached) {
      collected = <InvoiceListItem>[];
      nextPage = 1;
    }

    try {
      var page = nextPage;
      while (true) {
        final response = await useCases.getInvoiceList(
          page: page,
          limit: invoicePageSize,
          status: 'all',
        );
        if (!_isPayableInvoicesCurrent(seq, userId)) {
          return;
        }

        final knownIds = collected.map((invoice) => invoice.id).toSet();
        collected.addAll(
          response.items.where(
            (invoice) => invoice.isPayable && !knownIds.contains(invoice.id),
          ),
        );

        if (page == 1 && userId != null) {
          try {
            await useCases.cacheInvoiceList(userId, 'all', response);
          } catch (_) {
            // A cache write is a convenience; the API response is still usable.
          }
        }

        final responsePage = response.page <= 0 ? page : response.page;
        if (!response.hasMore || response.items.isEmpty) {
          break;
        }
        final next = responsePage + 1;
        // A backend that ignores `page` would otherwise loop forever.
        if (next <= page) {
          break;
        }
        page = next;
      }

      if (!_isPayableInvoicesCurrent(seq, userId)) {
        return;
      }
      _publishPayableInvoices(
        collected,
        userId,
        showingCached: false,
        updatedAt: DateTime.now(),
      );
      _registry?.markFresh(invoiceSelectionScreen);
    } on AppException catch (error) {
      if (!_isPayableInvoicesCurrent(seq, userId)) {
        return;
      }
      _handlePayableInvoicesFailure(collected, userId, error.message, error);
    } catch (_) {
      if (!_isPayableInvoicesCurrent(seq, userId)) {
        return;
      }
      _handlePayableInvoicesFailure(collected, userId, null, null);
    } finally {
      if (_payableInvoicesSeq == seq) {
        isLoadingPayableInvoices.value = false;
      }
    }
  }

  void _handlePayableInvoicesFailure(
    List<InvoiceListItem> collected,
    int? userId,
    String? message,
    AppException? error,
  ) {
    if (collected.isNotEmpty) {
      _publishPayableInvoices(
        collected,
        userId,
        showingCached: true,
        updatedAt: payableInvoicesUpdatedAt.value,
      );
    } else if (_hasPayableInvoicesData &&
        _payableInvoicesOwnerUserId == userId) {
      isShowingCachedPayableInvoices.value = true;
      isLoadingPayableInvoices.value = false;
    } else {
      payableInvoicesError.value = message ?? 'Unable to load invoices.';
      isShowingCachedPayableInvoices.value = false;
      isLoadingPayableInvoices.value = false;
      _hasPayableInvoicesData = false;
      _payableInvoicesOwnerUserId = userId;
    }
    if (error is ApiException && error.isRetryable) {
      _registry?.markStale(invoiceSelectionScreen);
    }
  }

  bool _isPayableInvoicesCurrent(int seq, int? userId) {
    return seq == _payableInvoicesSeq && userId == _currentUserId;
  }

  void _publishPayableInvoices(
    List<InvoiceListItem> items,
    int? userId, {
    required bool showingCached,
    required DateTime? updatedAt,
  }) {
    payableInvoices.assignAll(items);
    isLoadingPayableInvoices.value = false;
    payableInvoicesError.value = null;
    isShowingCachedPayableInvoices.value = showingCached;
    payableInvoicesUpdatedAt.value = updatedAt;
    _hasPayableInvoicesData = true;
    _payableInvoicesOwnerUserId = userId;
  }

  void _resetPayableInvoices() {
    _payableInvoicesSeq++;
    _payableInvoicesInFlight = null;
    _hasPayableInvoicesData = false;
    _payableInvoicesOwnerUserId = null;
    payableInvoices.clear();
    isLoadingPayableInvoices.value = false;
    payableInvoicesError.value = null;
    isShowingCachedPayableInvoices.value = false;
    payableInvoicesUpdatedAt.value = null;
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
    if (isPaymentProcessing.value) {
      return null;
    }
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
    final transactionReference = transactionId.trim();
    if (transactionReference.isEmpty) {
      errorMessage.value =
          'Enter the transaction reference from your bank or payment app.';
      return null;
    }

    final invoiceId = int.tryParse(invoice.id);
    if (invoiceId == null || invoiceId <= 0) {
      errorMessage.value = 'This invoice cannot be paid right now.';
      return null;
    }
    final selectedItemIds = selectedItems
        .map((item) => item.id)
        .whereType<int>()
        .where((id) => id > 0)
        .toList(growable: false);
    if (selectedItemIds.length != selectedItems.length ||
        selectedItemIds.toSet().length != selectedItemIds.length) {
      errorMessage.value =
          'Some selected fees cannot be paid right now. Please choose again.';
      return null;
    }

    isPaymentProcessing.value = true;
    errorMessage.value = null;
    paymentSuccess.value = null;
    paymentFailure.value = null;

    try {
      final quote = await useCases.getPaymentQuote(
        invoiceId: invoiceId,
        selectedItemIds: selectedItemIds,
      );
      final quoteError = quote.validationError(
        invoiceId: invoiceId,
        selectedItemIds: selectedItemIds.toSet(),
      );
      if (quoteError != null) {
        errorMessage.value = quoteError;
        return null;
      }

      final payment = Payment(
        id: '',
        invoiceNumber: invoice.number,
        residentName: _session?.name ?? '',
        unitLabel: invoice.unitLabel,
        items: List<InvoiceItem>.unmodifiable(selectedItems),
        amount: quote.totalAmount,
        date: AppDates.format(DateTime.now()),
        method: paymentMethodFromCode(method.code),
        status: PaymentStatus.unknown,
        transactionId: transactionReference,
        paymentMethodCode: method.code,
        paymentMethodName: method.displayName,
        proofPath: proofPath,
        proofFileName: proofFileName,
        paymentMethodId: method.id,
        quoteId: quote.quoteId,
        currency: quote.currency,
      );

      final stored = await useCases.submitPayment(payment);
      if (stored.isSuccessful ||
          stored.status == PaymentStatus.pendingVerification) {
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
    final hadInvoiceListData = _invoiceListStates.values.any(
      (state) => state.loaded,
    );
    final hadPayableInvoicesData = _hasPayableInvoicesData;
    try {
      await useCases.clearDashboardCache();
    } catch (_) {}
    try {
      await useCases.clearInvoiceListCache();
    } catch (_) {}
    try {
      await useCases.clearPaymentListCache();
    } catch (_) {}

    // A payment changes both the dashboard and the status of every filter, so
    // the in-memory pages are dropped and the visible filter is re-read once.
    _resetInvoiceListFilters();
    _resetPayableInvoices();
    final invoiceRefresh = hadInvoiceListData
        ? loadInvoices(refresh: true)
        : Future<void>.value();
    final payableRefresh = hadPayableInvoicesData
        ? loadPayableInvoices(refresh: true)
        : Future<void>.value();
    await loadPayments();
    await invoiceRefresh;
    await payableRefresh;

    final invoiceId = int.tryParse(invoice.id);
    if (invoiceId != null &&
        invoiceId > 0 &&
        invoiceDetailId.value == invoiceId) {
      await loadInvoiceDetail(invoiceId, force: true);
    }
  }
}

class _InvoiceListFilterState {
  _InvoiceListFilterState(this.status);

  final String status;
  final List<InvoiceListItem> items = <InvoiceListItem>[];
  int page = 1;
  int limit = PaymentController.invoicePageSize;
  int total = 0;
  bool loaded = false;
  bool loading = false;
  bool loadingMore = false;
  String? error;
  bool showingCached = false;
  DateTime? updatedAt;
  int? ownerUserId;
  int seq = 0;
  Future<void>? inFlight;
}
