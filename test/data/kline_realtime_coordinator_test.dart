import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  group('KlineRealtimeCoordinator', () {
    test('appends first and newer realtime Klines', () {
      final coordinator = KlineRealtimeCoordinator();

      final first = coordinator.apply(
        _kline(0),
        generation: coordinator.generation,
      );
      final second = coordinator.apply(
        _kline(1),
        generation: coordinator.generation,
      );

      expect(first.outcome, KlineMergeOutcome.appended);
      expect(second.outcome, KlineMergeOutcome.appended);
      expect(second.changed, isTrue);
      expect(second.snapshot.length, 2);
      expect(second.snapshot.version, KlineDataVersion(2));
    });

    test('updates an unclosed Kline with the same identity', () {
      final coordinator = KlineRealtimeCoordinator();
      coordinator.apply(
        _kline(0, isClosed: false),
        generation: coordinator.generation,
      );

      final result = coordinator.apply(
        _kline(0, close: 102.5, high: 103, isClosed: true),
        generation: coordinator.generation,
      );

      expect(result.outcome, KlineMergeOutcome.updated);
      expect(result.snapshot.lastOrNull?.close, 102.5);
      expect(result.snapshot.lastOrNull?.isClosed, isTrue);
    });

    test('ignores a structurally identical duplicate without version change',
        () {
      final coordinator = KlineRealtimeCoordinator();
      coordinator.apply(_kline(0), generation: coordinator.generation);
      final before = coordinator.store.snapshot;

      final result = coordinator.apply(
        _kline(0),
        generation: coordinator.generation,
      );

      expect(result.outcome, KlineMergeOutcome.ignoredDuplicate);
      expect(result.changed, isFalse);
      expect(identical(result.snapshot, before), isTrue);
    });

    test('requires explicit permission to correct a closed Kline', () {
      final coordinator = KlineRealtimeCoordinator();
      coordinator.apply(_kline(0), generation: coordinator.generation);
      final correction = _kline(0, close: 102.5, high: 103);

      final rejected = coordinator.apply(
        correction,
        generation: coordinator.generation,
      );
      final accepted = coordinator.apply(
        correction,
        generation: coordinator.generation,
        allowClosedCorrection: true,
      );

      expect(rejected.outcome, KlineMergeOutcome.rejectedClosedCorrection);
      expect(rejected.snapshot.version, KlineDataVersion(1));
      expect(accepted.outcome, KlineMergeOutcome.updated);
      expect(accepted.snapshot.version, KlineDataVersion(2));
    });

    test('inserts an out-of-order Kline inside the configured window', () {
      final store = KlineStore()..replace([_kline(0), _kline(1), _kline(3)]);
      final coordinator = KlineRealtimeCoordinator(
        store: store,
        maxOutOfOrderCandles: 2,
      );

      final result = coordinator.apply(
        _kline(2),
        generation: coordinator.generation,
      );

      expect(result.outcome, KlineMergeOutcome.insertedOutOfOrder);
      expect(result.snapshot.data.map((value) => value.openTime), [
        _time(0),
        _time(1),
        _time(2),
        _time(3),
      ]);
    });

    test('rejects older events outside the window and requests reload', () {
      final store = KlineStore()
        ..replace([_kline(0), _kline(2), _kline(3), _kline(4)]);
      final coordinator = KlineRealtimeCoordinator(
        store: store,
        maxOutOfOrderCandles: 2,
      );
      final before = store.snapshot;

      final result = coordinator.apply(
        _kline(1),
        generation: coordinator.generation,
      );

      expect(result.outcome, KlineMergeOutcome.rejectedOutsideWindow);
      expect(result.requiresReload, isTrue);
      expect(identical(result.snapshot, before), isTrue);
    });

    test('drops events from a stale generation before inspecting payload', () {
      final coordinator = KlineRealtimeCoordinator();
      final stale = coordinator.generation;
      final current = coordinator.beginNextGeneration(
        replacement: [_kline(10, symbol: 'ETHUSDT')],
      );

      final result = coordinator.apply(
        _kline(0),
        generation: stale,
      );

      expect(current, KlineGeneration(1));
      expect(result.outcome, KlineMergeOutcome.ignoredStaleGeneration);
      expect(result.snapshot.firstOrNull?.symbol, 'ETHUSDT');
    });

    test('rejects a different series in the current generation', () {
      final coordinator = KlineRealtimeCoordinator();
      coordinator.apply(_kline(0), generation: coordinator.generation);

      final result = coordinator.apply(
        _kline(1, symbol: 'ETHUSDT'),
        generation: coordinator.generation,
      );

      expect(result.outcome, KlineMergeOutcome.rejectedDifferentSeries);
      expect(result.snapshot.length, 1);
      expect(result.changed, isFalse);
    });

    test('generation replacement invalidates old work and changes data once',
        () {
      final coordinator = KlineRealtimeCoordinator();
      coordinator.apply(_kline(0), generation: coordinator.generation);

      final generation = coordinator.beginNextGeneration(
        replacement: [_kline(5), _kline(6)],
      );

      expect(generation, KlineGeneration(1));
      expect(coordinator.store.snapshot.length, 2);
      expect(coordinator.store.snapshot.version, KlineDataVersion(2));
    });

    test('validates generation and out-of-order window values', () {
      expect(() => KlineGeneration(-1), throwsArgumentError);
      expect(
        () => KlineRealtimeCoordinator(maxOutOfOrderCandles: -1),
        throwsArgumentError,
      );
    });

    test('failed generation replacement keeps the current token and data', () {
      final coordinator = KlineRealtimeCoordinator();
      coordinator.apply(_kline(0), generation: coordinator.generation);
      final before = coordinator.store.snapshot;

      expect(
        () => coordinator.beginNextGeneration(
          replacement: [_kline(2), _kline(1)],
        ),
        throwsArgumentError,
      );

      expect(coordinator.generation, KlineGeneration.zero);
      expect(identical(coordinator.store.snapshot, before), isTrue);
    });
  });
}

const _baseTime = 1724457600000;

int _time(int index) => _baseTime + index * 60 * Duration.millisecondsPerSecond;

Kline _kline(
  int index, {
  String symbol = 'BTCUSDT',
  double? close,
  double? high,
  bool isClosed = true,
}) {
  final open = 100.0 + index;
  return Kline(
    symbol: symbol,
    interval: KlineInterval.oneMinute,
    openTime: _time(index),
    closeTime: _time(index + 1) - 1,
    open: open,
    high: high ?? open + 2,
    low: open - 1,
    close: close ?? open + 1,
    baseVolume: 10 + index.toDouble(),
    quoteVolume: (10 + index) * (open + 1),
    tradeCount: 20 + index,
    isClosed: isClosed,
  );
}
