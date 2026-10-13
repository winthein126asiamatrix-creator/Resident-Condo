
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
