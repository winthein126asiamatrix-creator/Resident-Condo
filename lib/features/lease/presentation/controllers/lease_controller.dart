import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/resident_role.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/network/refresh_registry.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../domain/entities/lease.dart';
import '../../domain/usecases/lease_usecases.dart';

class LeaseController extends GetxController {
  LeaseController(this.useCases);

  /// The registry key this controller re-fetches under.
  static const String screen = 'lease';

  final LeaseUseCases useCases;
  final leases = <Lease>[].obs;
  final renewals = <LeaseRenewal>[].obs;
  final selectedLease = Rxn<Lease>();
  final role = ResidentRole.owner.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  /// True while what is on screen came from the device rather than the API.
  final isShowingCachedData = false.obs;

  Worker? _sessionWorker;
  int? _loadedForUserId;
  bool _cacheChecked = false;
  bool _hasLeaseSnapshot = false;
  bool _hasRenewalSnapshot = false;
  Future<void>? _loadInFlight;
  int _accountEpoch = 0;

  bool get _hasUsableData => _hasLeaseSnapshot || _hasRenewalSnapshot;

  SessionController? get _session => Get.isRegistered<SessionController>()
      ? Get.find<SessionController>()
      : null;

  RefreshRegistry? get _registry =>
      Get.isRegistered<RefreshRegistry>() ? Get.find<RefreshRegistry>() : null;

  ConnectivityService? get _connectivity =>
      Get.isRegistered<ConnectivityService>()
      ? Get.find<ConnectivityService>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _registry?.register(screen, loadLeases);

    final session = _session;
    if (session == null) {
      // A test can pump this controller without the app's session graph.
      loadLeases();
      return;
    }

    // Wait for `/auth/me` before calling the lease API. Running the request from
    // onInit would fire before the session is restored and be rejected with 401.
    _sessionWorker = ever(session.session, _handleSession);
    final user = session.currentUser;
    if (user != null) {
      _loadedForUserId = user.id;
      role.value = _roleFor(user.role);
      loadLeases();
    }
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    _registry?.unregister(screen);
    super.onClose();
  }

  Lease? get activeLease {
    for (final lease in leases) {
      if (!lease.hasExpired) {
        return lease;
      }
    }
    return leases.isEmpty ? null : leases.first;
  }

  LeaseRenewal? get pendingRenewal {
    for (final renewal in renewals) {
      if (renewal.status == RenewalStatus.pending) {
        return renewal;
      }
    }
    return null;
  }

  List<LeaseRenewal> renewalsFor(Lease lease) =>
      renewals.where((renewal) => renewal.leaseId == lease.id).toList();

  /// Tenants see the rent they owe, owners see the rent they collect.
  String get rentPerspectiveLabel =>
      role.value.paysRent ? 'Rent you pay' : 'Rent you collect';

  /// Loads the cached snapshot, then refreshes both lists from the API.
  ///
  /// Concurrent callers share the request already in flight so a reconnect and
  /// a pull-to-refresh cannot issue the same GETs twice.
  Future<void> loadLeases() {
    final existing = _loadInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadLeases();
    _loadInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    });
  }

  Future<void> _loadLeases() async {
    final epoch = _accountEpoch;
    isLoading.value = true;
    errorMessage.value = null;

    if (!_cacheChecked) {
      await _hydrateFromCache();
      if (epoch != _accountEpoch) return;
    }

    // With a cached snapshot there is nothing useful to ask the API while the
    // radio says the device is offline. The reconnect worker refreshes it later.
    if (_connectivity?.isOnline.value == false && _hasUsableData) {
      isShowingCachedData.value = true;
      _registry?.markStale(screen);
      isLoading.value = false;
      return;
    }

    try {
      final results = await Future.wait<Object>([
        useCases.getLeases(),
        useCases.getRenewals(),
      ]);
      if (epoch != _accountEpoch) return;
      leases.assignAll(results[0] as List<Lease>);
      renewals.assignAll(results[1] as List<LeaseRenewal>);
      _hasLeaseSnapshot = true;
      _hasRenewalSnapshot = true;
      isShowingCachedData.value = false;
      _registry?.markFresh(screen);
      _refreshSelection();
    } on AppException catch (error) {
      if (epoch == _accountEpoch) {
        _handleLoadFailure(error);
      }
    } catch (_) {
      if (epoch == _accountEpoch) {
        _handleLoadFailure(null, fallback: 'Unable to load lease information.');
      }
    } finally {
      if (epoch == _accountEpoch) {
        isLoading.value = false;
      }
    }
  }

  void selectLease(Lease lease) {
    selectedLease.value = lease;
    errorMessage.value = null;
  }

  void applyRole(ResidentRole next) {
    role.value = next;
  }

  Future<LeaseRenewal?> requestRenewal({
    required Lease lease,
    required DateTime proposedStart,
    required DateTime proposedEnd,
    required double proposedRent,
    String note = '',
  }) async {
    if (isSubmitting.value) {
      return null;
    }
    if (proposedRent <= 0) {
      errorMessage.value = 'Enter the proposed monthly rent.';
      return null;
    }
    if (!proposedEnd.isAfter(proposedStart)) {
      errorMessage.value = 'The end date must be after the start date.';
      return null;
    }

    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final renewal = await useCases.createRenewal(
        LeaseRenewal(
          id: '',
          leaseId: lease.id,
          requestedOn: AppDates.format(DateTime.now()),
          proposedStart: AppDates.format(proposedStart),
          proposedEnd: AppDates.format(proposedEnd),
          proposedRent: proposedRent,
          status: RenewalStatus.pending,
          requestedBy: _session?.currentUser?.displayName ?? role.value.label,
          note: note,
        ),
      );
      // The server accepted the write before anything is shown as pending.
      renewals.removeWhere(
        (item) =>
            item.leaseId == lease.id && item.status == RenewalStatus.pending,
      );
      renewals.insert(0, renewal);
      _hasRenewalSnapshot = true;
      await loadLeases();
      return renewal;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to send the renewal request.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<LeaseRenewal?> withdrawRenewal(LeaseRenewal renewal) async {
    if (isSubmitting.value) {
      return null;
    }

    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.withdrawRenewal(renewal);
      final index = renewals.indexWhere((item) => item.id == renewal.id);
      if (index != -1) {
        renewals[index] = updated;
      }
      await loadLeases();
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to withdraw the renewal request.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _hydrateFromCache() async {
    try {
      final cachedLeases = await useCases.getCachedLeases();
      final cachedRenewals = await useCases.getCachedRenewals();

      if (cachedLeases != null) {
        leases.assignAll(cachedLeases);
        _hasLeaseSnapshot = true;
      }
      if (cachedRenewals != null) {
        renewals.assignAll(cachedRenewals);
        _hasRenewalSnapshot = true;
      }
      if (_hasUsableData) {
        isShowingCachedData.value = true;
        _refreshSelection();
      }
    } catch (_) {
      // The cache is only a head start; a broken row must not stop the request.
    } finally {
      _cacheChecked = true;
    }
  }

  void _handleLoadFailure(Object? error, {String? fallback}) {
    if (_hasLeaseSnapshot) {
      // Older data is better than an error screen.
      isShowingCachedData.value = true;
    } else {
      errorMessage.value = error is AppException
          ? error.message
          : (fallback ?? 'Unable to load lease information.');
    }
    if ((error is ApiException && error.isRetryable) ||
        _connectivity?.isOnline.value == false) {
      _registry?.markStale(screen);
    }
  }

  void _handleSession(Object? value) {
    final user = _session?.currentUser;
    if (user == null || user.id <= 0) {
      _loadedForUserId = null;
      _resetForAccount();
      return;
    }

    if (_loadedForUserId == user.id) {
      return;
    }

    final switchingAccount =
        _loadedForUserId != null && _loadedForUserId != user.id;
    _loadedForUserId = user.id;
    role.value = _roleFor(user.role);
    if (switchingAccount) {
      _resetForAccount();
    }
    loadLeases();
  }

  /// Clears everything that belonged to the previous resident.
  void _resetForAccount() {
    _accountEpoch++;
    _loadInFlight = null;
    leases.clear();
    renewals.clear();
    selectedLease.value = null;
    _cacheChecked = false;
    _hasLeaseSnapshot = false;
    _hasRenewalSnapshot = false;
    isShowingCachedData.value = false;
    errorMessage.value = null;
    isLoading.value = false;
  }

  void _refreshSelection() {
    final selected = selectedLease.value;
    if (selected == null) return;
    selectedLease.value = _findLease(selected.id) ?? selected;
  }

  Lease? _findLease(String id) {
    for (final lease in leases) {
      if (lease.id == id) {
        return lease;
      }
    }
    return null;
  }

  ResidentRole _roleFor(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'owner' => ResidentRole.owner,
      'tenant' => ResidentRole.tenant,
      _ => ResidentRole.resident,
    };
  }
}
