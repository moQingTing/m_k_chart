import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  group('IndicatorDataChange', () {
    test('classifies append, prepend, update, and replace ranges', () {
      final store = KlineStore()..replace(buildV2KlineFixture(3));
      final initial = store.snapshot;
      final appended = store.append(buildV2KlineFixture(2, startIndex: 3));
      final appendChange = IndicatorDataChange.between(initial, appended);

      expect(appendChange.kind, IndicatorChangeKind.append);
      expect(appendChange.currentStart, 3);
      expect(appendChange.currentEnd, 5);
      expect(appendChange.preservedPrefixLength, 3);

      final updateBase = store.snapshot;
      final updated = store.update(
        updateBase.data.last.copyWith(
          close: updateBase.data.last.close + 0.1,
          high: updateBase.data.last.high + 0.1,
        ),
      );
      final updateChange = IndicatorDataChange.between(updateBase, updated);

      expect(updateChange.kind, IndicatorChangeKind.update);
      expect(updateChange.currentStart, 4);
      expect(updateChange.currentEnd, 5);

      final historyStore = KlineStore()
        ..replace(buildV2KlineFixture(3, startIndex: 2));
      final historyBase = historyStore.snapshot;
      final prepended = historyStore.prepend(buildV2KlineFixture(2));
      final prependChange = IndicatorDataChange.between(historyBase, prepended);

      expect(prependChange.kind, IndicatorChangeKind.prepend);
      expect(prependChange.preservedSuffixLength, 3);
      expect(prependChange.currentEnd, 2);

      final replacementStore = KlineStore()
        ..replace(buildV2KlineFixture(4, startIndex: 20));
      final replaceChange = IndicatorDataChange.between(
        initial,
        replacementStore.snapshot,
      );
      expect(replaceChange.kind, IndicatorChangeKind.replace);
    });
  });

  group('IndicatorCache', () {
    test('returns exact cached result without recalculation', () {
      final definition = _CumulativeCloseIndicator();
      final registry = IndicatorRegistry()..register(definition);
      final cache = IndicatorCache(registry);
      final store = KlineStore()..replace(buildV2KlineFixture(3));
      final config = _config();

      final first = cache.resolve(store.snapshot, config);
      final second = cache.resolve(store.snapshot, config);

      expect(identical(first, second), isTrue);
      expect(definition.fullCalls, 1);
      expect(definition.incrementalCalls, 0);
      expect(cache.cacheHits, 1);
    });

    test('uses incremental append and last-update calculations', () {
      final definition = _CumulativeCloseIndicator();
      final cache = IndicatorCache(
        IndicatorRegistry()..register(definition),
      );
      final store = KlineStore()..replace(buildV2KlineFixture(3));
      final config = _config();
      cache.resolve(store.snapshot, config);

      store.append(buildV2KlineFixture(2, startIndex: 3));
      final appended = cache.resolve(store.snapshot, config);
      final beforeUpdate = store.snapshot.data.last;
      store.update(
        beforeUpdate.copyWith(
          close: beforeUpdate.close + 0.2,
          high: beforeUpdate.high + 0.2,
        ),
      );
      final updated = cache.resolve(store.snapshot, config);

      expect(definition.fullCalls, 1);
      expect(definition.incrementalCalls, 2);
      expect(cache.incrementalCalculations, 2);
      expect(
        appended.series.single.values.last,
        closeTo(_sum(store.snapshot.data.take(4)) + beforeUpdate.close, 1e-9),
      );
      expect(
        updated.series.single.values.last,
        closeTo(_sum(store.snapshot.data), 1e-9),
      );
    });

    test('falls back to full calculation for unsupported changes', () {
      final definition = _CumulativeCloseIndicator();
      final cache = IndicatorCache(
        IndicatorRegistry()..register(definition),
      );
      final store = KlineStore()
        ..replace(buildV2KlineFixture(3, startIndex: 2));
      final config = _config();
      cache.resolve(store.snapshot, config);

      store.prepend(buildV2KlineFixture(2));
      cache.resolve(store.snapshot, config);

      expect(definition.fullCalls, 2);
      expect(definition.incrementalCalls, 0);
      expect(cache.fullCalculations, 2);
    });

    test('separates configurations, price sources, and store snapshots', () {
      final definition = _CumulativeCloseIndicator();
      final cache = IndicatorCache(
        IndicatorRegistry()..register(definition),
      );
      final tradeStore = KlineStore()..replace(buildV2KlineFixture(2));
      final markStore = KlineStore()
        ..replace(buildV2KlineFixture(2).map(_asMarkPrice));
      final firstConfig = _config();
      final secondConfig = _config(instanceId: 'sum-secondary');

      final tradeKey = IndicatorCacheKey.from(tradeStore.snapshot, firstConfig);
      final markKey = IndicatorCacheKey.from(markStore.snapshot, firstConfig);
      cache.resolve(tradeStore.snapshot, firstConfig);
      cache.resolve(tradeStore.snapshot, secondConfig);
      cache.resolve(markStore.snapshot, firstConfig);

      expect(tradeKey.priceSource, KlinePriceSource.trade);
      expect(markKey.priceSource, KlinePriceSource.mark);
      expect(tradeKey, isNot(markKey));
      expect(definition.fullCalls, 3);
    });

    test('bounds entries with LRU eviction and supports clear', () {
      final cache = IndicatorCache(
        IndicatorRegistry()..register(_CumulativeCloseIndicator()),
        maximumEntries: 1,
      );
      final store = KlineStore()..replace(buildV2KlineFixture(2));

      cache.resolve(store.snapshot, _config());
      cache.resolve(store.snapshot, _config(instanceId: 'other'));

      expect(cache.length, 1);
      expect(cache.evictions, 1);
      cache.clear();
      expect(cache.length, 0);
    });
  });
}

IndicatorConfig _config({String instanceId = 'sum-primary'}) => IndicatorConfig(
      instanceId: instanceId,
      definitionId: 'test.cumulative-close',
    );

double _sum(Iterable<Kline> values) =>
    values.fold(0, (total, item) => total + item.close);

Kline _asMarkPrice(Kline value) => Kline(
      symbol: value.symbol,
      interval: value.interval,
      openTime: value.openTime,
      closeTime: value.closeTime,
      open: value.open,
      high: value.high,
      low: value.low,
      close: value.close,
      baseVolume: value.baseVolume,
      quoteVolume: value.quoteVolume,
      tradeCount: value.tradeCount,
      isClosed: value.isClosed,
      priceSource: KlinePriceSource.mark,
    );

final class _CumulativeCloseIndicator
    implements IncrementalIndicatorDefinition {
  int fullCalls = 0;
  int incrementalCalls = 0;

  @override
  String get id => 'test.cumulative-close';

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.mainChart,
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: 'Cumulative close',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    fullCalls++;
    var total = 0.0;
    return _result(
      input,
      config,
      input.data.map((item) => total += item.close).toList(),
    );
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      change.kind == IndicatorChangeKind.append ||
      change.kind == IndicatorChangeKind.update;

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    incrementalCalls++;
    final values = List<double?>.of(previous.series.single.values);
    if (values.length < input.data.length) {
      values.length = input.data.length;
    } else if (values.length > input.data.length) {
      values.removeRange(input.data.length, values.length);
    }
    final start = change.currentStart;
    var total = start == 0 ? 0.0 : values[start - 1]!;
    for (var index = start; index < input.data.length; index++) {
      total += input.data[index].close;
      values[index] = total;
    }
    return _result(input, config, values);
  }

  IndicatorResult _result(
    VersionedKlineData input,
    IndicatorConfig config,
    List<double?> values,
  ) =>
      IndicatorResult(
        instanceId: config.instanceId,
        definitionId: id,
        dataVersion: input.version,
        length: input.data.length,
        series: [IndicatorSeries(id: 'value', values: values)],
      );
}
