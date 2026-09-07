import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  group('KlineStore', () {
    test('starts with a stable empty version-zero snapshot', () {
      final store = KlineStore();

      expect(store.snapshot.isEmpty, isTrue);
      expect(store.snapshot.version, KlineDataVersion.zero);
      expect(store.snapshot.firstOrNull, isNull);
      expect(store.snapshot.lastOrNull, isNull);
    });

    test('replace publishes one ordered immutable snapshot', () {
      final store = KlineStore();
      final source = [_kline(0), _kline(1), _kline(2)];

      final snapshot = store.replace(source);
      source.clear();

      expect(snapshot.length, 3);
      expect(snapshot.version, KlineDataVersion(1));
      expect(snapshot.firstOrNull?.openTime, _time(0));
      expect(snapshot.lastOrNull?.openTime, _time(2));
      expect(() => snapshot.data.add(_kline(3)), throwsUnsupportedError);
    });

    test('equal replace and empty operations preserve snapshot identity', () {
      final store = KlineStore();
      final first = store.replace([_kline(0), _kline(1)]);

      final equal = store.replace([_kline(0), _kline(1)]);
      final emptyPrepend = store.prepend(const []);
      final emptyAppend = store.append(const []);

      expect(identical(equal, first), isTrue);
      expect(identical(emptyPrepend, first), isTrue);
      expect(identical(emptyAppend, first), isTrue);
      expect(store.snapshot.version, KlineDataVersion(1));
    });

    test('prepend and append each create one new version', () {
      final store = KlineStore()..replace([_kline(2), _kline(3)]);

      final prepended = store.prepend([_kline(0), _kline(1)]);
      final appended = store.append([_kline(4), _kline(5)]);

      expect(prepended.version, KlineDataVersion(2));
      expect(appended.version, KlineDataVersion(3));
      expect(
        appended.data.map((value) => value.openTime),
        List.generate(6, _time),
      );
    });

    test('snapshots remain stable after later mutations', () {
      final store = KlineStore();
      final before = store.replace([_kline(0), _kline(1)]);

      store.append([_kline(2)]);

      expect(before.length, 2);
      expect(before.lastOrNull?.openTime, _time(1));
      expect(store.snapshot.length, 3);
    });

    test('update uses binary-search identity and skips equal values', () {
      final store = KlineStore()..replace(List.generate(5, _kline));
      final before = store.snapshot;

      final equal = store.update(_kline(2));
      final updatedValue = _kline(2).copyWith(close: 102.5, high: 103);
      final updated = store.update(updatedValue);

      expect(identical(equal, before), isTrue);
      expect(updated.version, KlineDataVersion(2));
      expect(updated[2], updatedValue);
      expect(before[2].close, 103);
    });

    test('replace with empty data clears once and then becomes a no-op', () {
      final store = KlineStore()..replace([_kline(0)]);

      final cleared = store.replace(const []);
      final repeated = store.replace(const []);

      expect(cleared.isEmpty, isTrue);
      expect(cleared.version, KlineDataVersion(2));
      expect(identical(cleared, repeated), isTrue);
    });

    test('rejects unordered, duplicate, and mixed-series replacement', () {
      final store = KlineStore();

      expect(
        () => store.replace([_kline(1), _kline(0)]),
        throwsArgumentError,
      );
      expect(
        () => store.replace([_kline(0), _kline(0)]),
        throwsArgumentError,
      );
      expect(
        () => store.replace([_kline(0), _kline(1, symbol: 'ETHUSDT')]),
        throwsArgumentError,
      );
      expect(store.snapshot.version, KlineDataVersion.zero);
    });

    test('rejects overlapping prepend and append ranges', () {
      final store = KlineStore()..replace([_kline(2), _kline(3)]);

      expect(() => store.prepend([_kline(1), _kline(2)]), throwsArgumentError);
      expect(() => store.append([_kline(3), _kline(4)]), throwsArgumentError);
      expect(store.snapshot.version, KlineDataVersion(1));
    });

    test('rejects update for missing identity or a different series', () {
      final store = KlineStore()..replace([_kline(0), _kline(1)]);

      expect(() => store.update(_kline(3)), throwsStateError);
      expect(
        () => store.update(_kline(1, symbol: 'ETHUSDT')),
        throwsArgumentError,
      );
      expect(store.snapshot.version, KlineDataVersion(1));
    });

    test('can append into and prepend into an empty store', () {
      final appendStore = KlineStore();
      final prependStore = KlineStore();

      appendStore.append([_kline(0), _kline(1)]);
      prependStore.prepend([_kline(0), _kline(1)]);

      expect(appendStore.snapshot.length, 2);
      expect(prependStore.snapshot.length, 2);
    });
  });
}

const _baseTime = 1724457600000;

int _time(int index) => _baseTime + index * 60 * Duration.millisecondsPerSecond;

Kline _kline(int index, {String symbol = 'BTCUSDT'}) {
  final open = 100.0 + index;
  return Kline(
    symbol: symbol,
    interval: KlineInterval.oneMinute,
    openTime: _time(index),
    closeTime: _time(index + 1) - 1,
    open: open,
    high: open + 2,
    low: open - 1,
    close: open + 1,
    baseVolume: 10 + index.toDouble(),
    quoteVolume: (10 + index) * (open + 1),
    tradeCount: 20 + index,
    isClosed: true,
  );
}
