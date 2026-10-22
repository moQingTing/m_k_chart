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

    test('多个指标实例复用同一对快照的变化范围识别', () {
      final definition = _CumulativeCloseIndicator();
      final cache = IndicatorCache(
        IndicatorRegistry()..register(definition),
      );
      final store = KlineStore()..replace(buildV2KlineFixture(5));
      final configs = [
        for (var index = 0; index < 6; index++)
          _config(instanceId: 'sum-$index'),
      ];
      for (final config in configs) {
        cache.resolve(store.snapshot, config);
      }
      expect(cache.changeClassifications, 0);

      final last = store.snapshot.lastOrNull!;
      store.update(last.copyWith(close: last.close + 0.1));
      final expected = _sum(store.snapshot.data);
      for (final config in configs) {
        final result = cache.resolve(store.snapshot, config);
        expect(result.series.single.values.last, closeTo(expected, 1e-9));
      }

      expect(cache.changeClassifications, 1);
      expect(definition.incrementalCalls, 6);
      store.append(buildV2KlineFixture(1, startIndex: 5));
      for (final config in configs) {
        cache.resolve(store.snapshot, config);
      }
      expect(cache.changeClassifications, 2);
      expect(definition.incrementalCalls, 12);
    });

    test('变化分类只按快照身份复用，不按相同版本号混用', () {
      final cache = IndicatorCache(
        IndicatorRegistry()..register(_CumulativeCloseIndicator()),
      );
      final firstStore = KlineStore()..replace(buildV2KlineFixture(3));
      final secondStore = KlineStore()..replace(buildV2KlineFixture(3));
      final firstConfig = _config(instanceId: 'first');
      final secondConfig = _config(instanceId: 'second');
      cache.resolve(firstStore.snapshot, firstConfig);
      cache.resolve(secondStore.snapshot, secondConfig);

      final firstLast = firstStore.snapshot.lastOrNull!;
      final secondLast = secondStore.snapshot.lastOrNull!;
      firstStore.update(firstLast.copyWith(close: firstLast.close + 0.1));
      secondStore.update(secondLast.copyWith(close: secondLast.close + 0.2));
      final first = cache.resolve(firstStore.snapshot, firstConfig);
      final second = cache.resolve(secondStore.snapshot, secondConfig);

      expect(
        first.series.single.values.last,
        closeTo(_sum(firstStore.snapshot.data), 1e-9),
      );
      expect(
        second.series.single.values.last,
        closeTo(_sum(secondStore.snapshot.data), 1e-9),
      );
      expect(cache.changeClassifications, 2);
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

    test('相同版本号但不同仓库或参数时不复用旧指标结果', () {
      final definition = _CumulativeCloseIndicator();
      final cache = IndicatorCache(
        IndicatorRegistry()..register(definition),
      );
      final firstStore = KlineStore()..replace(buildV2KlineFixture(2));
      final secondStore = KlineStore()
        ..replace([
          ...buildV2KlineFixture(1),
          buildV2KlineFixture(2).last.copyWith(close: 999, high: 1001),
        ]);
      expect(firstStore.snapshot.version, secondStore.snapshot.version);
      final config = _config();
      final first = cache.resolve(firstStore.snapshot, config);
      final second = cache.resolve(secondStore.snapshot, config);
      final changedParameters = cache.resolve(
        secondStore.snapshot,
        IndicatorConfig(
          instanceId: config.instanceId,
          definitionId: config.definitionId,
          parameters: const {'period': 2},
        ),
      );
      expect(
        first.series.single.values.last,
        isNot(second.series.single.values.last),
      );
      expect(
        second.series.single.values.last,
        999 + secondStore.snapshot.data.first.close,
      );
      expect(changedParameters, isNot(same(second)));
      expect(definition.fullCalls, 3);
      expect(cache.cacheHits, 0);
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
