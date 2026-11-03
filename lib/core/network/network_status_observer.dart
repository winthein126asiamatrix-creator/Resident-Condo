/// A signal about the backend, not about the device.
///
/// A failed request does not mean the resident is offline, so this must never
/// drive the offline banner. Device connectivity lives in `ConnectivityService`
/// and comes only from the radio.
abstract final class NetworkStatusObserver {
  static final _listeners = <void Function(bool online)>{};

  static void addListener(void Function(bool online) listener) =>
      _listeners.add(listener);

  static void removeListener(void Function(bool online) listener) =>
      _listeners.remove(listener);

  /// [online] is false when a request failed for a network reason, true when
  /// one completed.
  static void notify(bool online) {
    for (final listener in {..._listeners}) {
      listener(online);
    }
  }
}
