import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/refresh_registry.dart';

void main() {
  test('concurrent refreshes for a stale screen share one request', () async {
    final registry = RefreshRegistry();
    final request = Completer<void>();
    var calls = 0;
    registry.register('dashboard', () {
      calls++;
      return request.future;
    });
    registry.markStale('dashboard');

    final first = registry.refreshIfStale('dashboard');
    final second = registry.refreshIfStale('dashboard');

    expect(calls, 1);

    request.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(calls, 1);
  });

  test('a fresh screen is not refreshed', () async {
    final registry = RefreshRegistry();
    var calls = 0;
    registry.register('dashboard', () async {
      calls++;
    });
    registry.markFresh('dashboard');

    expect(await registry.refreshIfStale('dashboard'), isFalse);
    expect(calls, 0);
  });

  test('an unregistered screen is not refreshed', () async {
    final registry = RefreshRegistry();
    registry.markStale('dashboard');

    expect(await registry.refreshIfStale('dashboard'), isFalse);
  });
}
