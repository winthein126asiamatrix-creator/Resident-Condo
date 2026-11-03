import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/api_log_store.dart';

ApiLogEntry _entry(
  String id, {
  ApiLogOutcome outcome = ApiLogOutcome.pending,
  int? statusCode,
  int? durationMs,
}) {
  return ApiLogEntry(
    id: id,
    method: 'GET',
    url: 'https://api.example.com/$id',
    endpoint: '/$id',
    requestTimestamp: DateTime(2026, 1, 1),
    statusCode: statusCode,
    durationMs: durationMs,
    outcome: outcome,
  );
}

void main() {
  test('keeps only the latest records when the limit is exceeded', () {
    final store = ApiLogStore(maxEntries: 200);
    for (var i = 0; i < 205; i++) {
      store.add(_entry('$i'));
    }

    expect(store.total, 200);
    expect(store.logs.first.id, '5');
    expect(store.logs.last.id, '204');
  });

  test('finishing a request replaces it instead of adding a duplicate', () {
    final store = ApiLogStore();
    final pending = _entry('a');
    store.add(pending);
    store.finish(
      pending.copyWith(
        statusCode: 200,
        outcome: ApiLogOutcome.success,
        durationMs: 12,
      ),
    );

    expect(store.total, 1);
    expect(store.logs.single.isSuccess, isTrue);
    expect(store.logs.single.durationMs, 12);
  });

  test('ignores a completion for an entry that was evicted', () {
    final store = ApiLogStore(maxEntries: 1);
    final old = _entry('old');
    store.add(old);
    store.add(_entry('new'));

    store.finish(old.copyWith(outcome: ApiLogOutcome.success));

    expect(store.logs.single.id, 'new');
    expect(store.logs.single.isPending, isTrue);
  });

  test('clear removes every log', () {
    final store = ApiLogStore();
    store.add(_entry('a'));
    store.add(_entry('b'));

    store.clear();

    expect(store.total, 0);
    expect(store.logs, isEmpty);
  });

  test('summary counts and average ignore pending durations', () {
    final store = ApiLogStore();
    store.add(
      _entry(
        'ok',
        outcome: ApiLogOutcome.success,
        statusCode: 200,
        durationMs: 10,
      ),
    );
    store.add(
      _entry(
        'bad',
        outcome: ApiLogOutcome.failed,
        statusCode: 500,
        durationMs: 30,
      ),
    );
    store.add(_entry('pending'));

    expect(store.total, 3);
    expect(store.successCount, 1);
    expect(store.failedCount, 1);
    expect(store.pendingCount, 1);
    expect(store.averageDurationMs, 20);
  });

  test('finds a log by id', () {
    final store = ApiLogStore();
    store.add(_entry('a'));

    expect(store.findById('a')?.id, 'a');
    expect(store.findById('missing'), isNull);
  });
}
