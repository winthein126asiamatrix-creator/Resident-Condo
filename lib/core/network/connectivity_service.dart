import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Tracks whether the device has a usable network interface.
///
/// Only [Connectivity] radio readings feed [isOnline]. Request outcomes are
/// deliberately not used: a 500, a DNS failure, a timeout or an unreachable API
/// host says something about the backend, not about the device's connection.
/// Treating any of those as "offline" is what made the banner appear when the
/// device was connected but the server was not reachable.
///
/// A Wi-Fi network with no internet route still reports Wi-Fi here. That is the
/// honest limit of the radio API; the failed request itself surfaces the problem
/// to the screen that made it, without claiming the device is disconnected.
///
/// Radio readings are debounced, because connectivity can flap and each flap
/// would otherwise toggle the banner and re-trigger a refresh.
class ConnectivityService extends GetxService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  /// How long a radio reading is allowed to settle before it is believed.
  static const Duration debounce = Duration(milliseconds: 700);

  final Connectivity _connectivity;

  /// Whether the device currently has a network interface.
  ///
  /// This is device connectivity only. It does not mean the backend is
  /// reachable.
  final isOnline = true.obs;

  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    _subscription = _connectivity.onConnectivityChanged.listen(_onRadioChanged);
    _checkRadio();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.onClose();
  }

  Future<void> _checkRadio() async {
    final results = await _connectivity.checkConnectivity();
    _scheduleRadio(!results.contains(ConnectivityResult.none));
  }

  void _onRadioChanged(List<ConnectivityResult> results) {
    _scheduleRadio(!results.contains(ConnectivityResult.none));
  }

  void _scheduleRadio(bool online) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => _apply(online));
  }

  void _apply(bool online) {
    if (online == _online) {
      return;
    }
    _online = online;
    isOnline.value = online;
  }
}
