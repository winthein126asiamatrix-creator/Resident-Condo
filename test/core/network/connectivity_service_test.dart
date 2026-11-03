import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/connectivity_service.dart';
import 'package:test/core/network/network_status_observer.dart';

class _FakeConnectivity implements Connectivity {
  List<ConnectivityResult> current = const <ConnectivityResult>[
    ConnectivityResult.wifi,
  ];
  final _changes = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    await Future<void>.delayed(Duration.zero);
    return current;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;

  void emit(List<ConnectivityResult> value) {
    current = value;
    _changes.add(value);
  }

  Future<void> close() => _changes.close();
}

Future<void> _settle() => Future<void>.delayed(
  ConnectivityService.debounce + const Duration(milliseconds: 50),
);

void main() {
  late _FakeConnectivity connectivity;
  late ConnectivityService service;

  setUp(() {
    connectivity = _FakeConnectivity();
    service = ConnectivityService(connectivity: connectivity);
    service.onInit();
  });

  tearDown(() async {
    service.onClose();
    await connectivity.close();
  });

  test('starts online until the first radio reading arrives', () {
    expect(service.isOnline.value, isTrue);
  });

  test('reports offline when the radio has no connection', () async {
    connectivity.current = const <ConnectivityResult>[ConnectivityResult.none];

    await _settle();

    expect(service.isOnline.value, isFalse);
  });

  test('stays online for a Wi-Fi reading', () async {
    await _settle();

    expect(service.isOnline.value, isTrue);
  });

  test('follows the radio back online after a disconnection', () async {
    connectivity.current = const <ConnectivityResult>[ConnectivityResult.none];
    await _settle();
    expect(service.isOnline.value, isFalse);

    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.wifi]);
    await _settle();

    expect(service.isOnline.value, isTrue);
  });

  test('debounces rapid radio flapping to the final reading', () async {
    await _settle();
    expect(service.isOnline.value, isTrue);

    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.none]);
    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.wifi]);
    await _settle();

    expect(service.isOnline.value, isTrue);
  });

  test('a failed request does not mark the device offline', () async {
    await _settle();

    NetworkStatusObserver.notify(false);

    expect(service.isOnline.value, isTrue);
  });

  test('a successful request does not change device connectivity', () async {
    connectivity.current = const <ConnectivityResult>[ConnectivityResult.none];
    await _settle();
    expect(service.isOnline.value, isFalse);

    NetworkStatusObserver.notify(true);

    expect(service.isOnline.value, isFalse);
  });

  test('repeated radio readings do not emit duplicate updates', () async {
    await _settle();
    final updates = <bool>[];
    final subscription = service.isOnline.listen(updates.add);

    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.none]);
    await _settle();
    connectivity.emit(const <ConnectivityResult>[ConnectivityResult.none]);
    await _settle();

    expect(updates.where((online) => online == false), hasLength(1));
    await subscription.cancel();
  });
}
