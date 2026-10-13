import 'package:get/get.dart';

/// Tracks which screens can refresh their GET data, and whether theirs went
/// stale.
///
/// A screen registers the callback that re-fetches its data and marks that data
/// stale when a fetch fails for a network reason. When connectivity returns, the
/// app asks for the *active* screen by name, and the registry re-fetches it only
/// if it is stale.
///
/// The staleness check is what keeps a reconnect from re-issuing a request that
/// already succeeded: losing connectivity alone never marks anything, so a
/// screen whose data is current is left exactly as it is.
class RefreshRegistry extends GetxService {
  final _refresh = <String, Future<void> Function()>{};
  final _stale = <String, bool>{};

  /// Registers [refresh] as the callback that re-fetches [screen]'s data.
  ///
  /// Called from a controller's `onInit`, so the callback is available before
  /// the connectivity layer has any reason to use it.
  void register(String screen, Future<void> Function() refresh) {
    _refresh[screen] = refresh;
  }

  void unregister(String screen) {
    _refresh.remove(screen);
    _stale.remove(screen);
  }

  /// Marks [screen]'s data stale, so it is re-fetched when connectivity returns.
  void markStale(String screen) => _stale[screen] = true;

  /// Marks [screen]'s data fresh, so a reconnect does not re-fetch it.
  void markFresh(String screen) => _stale[screen] = false;

  /// Re-fetches [screen] only if its data is stale and a callback is registered.
  ///
  /// Returns whether a refresh was started, so a caller logging the outcome can
  /// tell a refresh from a no-op.
  Future<bool> refreshIfStale(String screen) async {
    if (_stale[screen] != true) {
      return false;
    }
    final refresh = _refresh[screen];
    if (refresh == null) {
      return false;
    }
    await refresh();
    return true;
  }
}
