import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../session/presentation/controllers/session_controller.dart';
import '../../domain/entities/condo_config.dart';
import '../../domain/usecases/config_usecases.dart';

class CondoConfigController extends GetxController {
  CondoConfigController(this.useCases, {SessionController? sessionController})
    : _sessionOverride = sessionController;

  final ConfigUseCases useCases;
  final SessionController? _sessionOverride;

  final config = Rxn<CondoConfig>();
  final isLoading = false.obs;
  final isResolved = false.obs;
  final errorMessage = RxnString();

  Future<void>? _inFlight;
  String? _accountKey;
  bool _attempted = false;

  SessionController? get _session =>
      _sessionOverride ??
      (Get.isRegistered<SessionController>()
          ? Get.find<SessionController>()
          : null);

  String? get _currentAccountKey {
    final user = _session?.currentUser;
    if (user == null) return null;
    if (user.id > 0) return 'user:${user.id}';
    final email = user.email?.trim() ?? '';
    return email.isEmpty ? user.displayName : email;
  }

  bool get hasConfig => config.value != null;

  bool isFeatureEnabled(CondoFeature feature) =>
      config.value?.isFeatureEnabled(feature) ?? false;

  bool get partialPaymentEnabled =>
      isFeatureEnabled(CondoFeature.partialPayment);

  CondoInfo? get condo => config.value?.condo;

  MaintenanceBookingConfig? get maintenanceBooking =>
      config.value?.booking?.maintenance;

  LeaseConfig? get leaseConfig => config.value?.lease;

  Future<void> loadForSession({bool refresh = true}) {
    final accountKey = _currentAccountKey;
    if (accountKey == null) {
      clear();
      return Future<void>.value();
    }
    final existing = _inFlight;
    if (existing != null && _accountKey == accountKey) {
      return existing;
    }
    final future = _run(accountKey, refresh);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _run(String accountKey, bool refresh) async {
    if (_accountKey != accountKey) {
      _accountKey = accountKey;
      config.value = null;
      _attempted = false;
      isResolved.value = false;
      errorMessage.value = null;
    }

    final cached = await useCases.readCachedCondoConfig(accountKey);
    if (_accountKey != accountKey) return;
    if (cached != null) {
      config.value = cached;
    }

    if (!refresh || _attempted) {
      isResolved.value = true;
      return;
    }

    _attempted = true;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final fresh = await useCases.fetchCondoConfig();
      if (_accountKey != accountKey) return;
      config.value = fresh;
      try {
        await useCases.cacheCondoConfig(accountKey, fresh);
      } on Object {
        // A local write failure must not discard a valid response.
      }
    } on AppException catch (error) {
      if (_accountKey == accountKey) {
        errorMessage.value = error.message;
      }
    } catch (_) {
      if (_accountKey == accountKey) {
        errorMessage.value = 'Unable to load condo configuration.';
      }
    } finally {
      if (_accountKey == accountKey) {
        isLoading.value = false;
        isResolved.value = true;
      }
    }
  }

  Future<void> clearCachedConfig() async {
    final accountKey = _accountKey;
    if (accountKey == null) return;
    try {
      await useCases.clearCondoConfig(accountKey);
    } on Object {
      // Clearing the device copy is best effort.
    }
  }

  void clear() {
    _accountKey = null;
    _inFlight = null;
    _attempted = false;
    config.value = null;
    isLoading.value = false;
    isResolved.value = false;
    errorMessage.value = null;
  }
}
