import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

import 'network_status_observer.dart';

/// Tracks whether the app can reach the backend.
///
/// Two sources, because neither is sufficient alone:
///
/// * [Connectivity] watches the radio. It is the only thing that can notice the
///   resident walking out of range before anything has been requested.
/// * [NetworkStatusObserver] watches request outcomes. A device on Wi-Fi with no
///   route to the server still reports "connected", so a network-level failure
///   is the only signal that the backend is genuinely unreachable.
///
/// Radio readings are debounced, because connectivity can flap and each flap
/// would otherwise toggle the banner and re-trigger a refresh. Request outcomes
/// are applied at once: they are discrete, unambiguous signals.
class ConnectivityService extends GetxService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  /// How long a radio reading is allowed to settle before it is believed.
  static const Duration debounce = Duration(milliseconds: 700);

  final Connectivity _connectivity;

  /// Whether the backend is believed reachable.
  final isOnline = true.obs;

  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    NetworkStatusObserver.addListener(_onRequestOutcome);
    _subscription = _connectivity.onConnectivityChanged.listen(_onRadioChanged);
    _checkRadio();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _subscription?.cancel();
    NetworkStatusObserver.removeListener(_onRequestOutcome);
    super.onClose();
  }

  Future<void> _checkRadio() async {
    final results = await _connectivity.checkConnectivity();
    _scheduleRadio(!results.contains(ConnectivityResult.none));
  }

  void _onRadioChanged(List<ConnectivityResult> results) {
    _scheduleRadio(!results.contains(ConnectivityResult.none));
  }

  /// A request completed, so the backend is reachable whatever the radio says.
  void _onRequestOutcome(bool online) {
    _debounce?.cancel();
    _apply(online);
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
