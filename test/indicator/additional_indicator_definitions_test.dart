import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

const _tolerance = 1e-9;

void main() {
  group('additional indicator definitions', () {
    test('registers all six definitions and renderer contracts', () {
      final registry = IndicatorRegistry();
      registerAdditionalIndicatorDefinitions(registry);

      expect(registry.definitions, hasLength(6));
      expect(
        registry.definitions.keys,
        containsAll([
          VwapIndicatorDefinition.definitionId,
          AtrIndicatorDefinition.definitionId,
          CciIndicatorDefinition.definitionId,
          DmiIndicatorDefinition.definitionId,
          RocIndicatorDefinition.definitionId,
          StochRsiIndicatorDefinition.definitionId,
        ]),
      );
      expect(
        registry
            .find(VwapIndicatorDefinition.definitionId)!
            .rendererDescriptor
            .placement,
        IndicatorPlacement.mainChart,
      );
      expect(
        registry
            .find(DmiIndicatorDefinition.definitionId)!
            .rendererDescriptor
            .series
            .map((item) => item.id),
        ['plusDi', 'minusDi', 'adx'],
      );

      final allBuiltIns = IndicatorRegistry();
      registerBuiltInIndicatorDefinitions(allBuiltIns);
      expect(allBuiltIns.definitions, hasLength(16));
    });

    test('matches analytically known flat and rising series', () {
      final flatResults = _calculate(_snapshot(_linearKlines(50, step: 0)));

      expect(_last(flatResults, 'vwap', 'vwap'), 10);
      expect(_last(flatResults, 'atr', 'atr'), 2);
      expect(_last(flatResults, 'cci', 'cci'), 0);
      expect(_last(flatResults, 'dmi', 'plusDi'), 0);
      expect(_last(flatResults, 'dmi', 'minusDi'), 0);
      expect(_last(flatResults, 'dmi', 'adx'), 0);
      expect(_last(flatResults, 'roc', 'roc'), 0);
      expect(_last(flatResults, 'stochRsi', 'k'), 0);
      expect(_last(flatResults, 'stochRsi', 'd'), 0);

      final rising = _calculate(_snapshot(_linearKlines(50)));
      expect(_value(rising, 'atr', 'atr', 13), 2);
      expect(
        _value(rising, 'cci', 'cci', 19),
        closeTo(126.66666666666667, _tolerance),
      );
      expect(_value(rising, 'dmi', 'plusDi', 14), 50);
      expect(_value(rising, 'dmi', 'minusDi', 14), 0);
      expect(_value(rising, 'dmi', 'adx', 27), 100);
      expect(
        _value(rising, 'roc', 'roc', 12),
        closeTo(120, _tolerance),
      );
    });

    test('uses cumulative typical-price volume for VWAP', () {
      final values = [
        _kline(0, 10, volume: 1),
        _kline(1, 20, volume: 2),
        _kline(2, 30, volume: 3),
      ];
      final results = _calculate(_snapshot(values));

      expect(
        _last(results, 'vwap', 'vwap'),
        closeTo((10 + 40 + 90) / 6, _tolerance),
      );
    });

    test('keeps zero-volume and zero-price denominators finite', () {
      final zeroVolume = _calculate(
        _snapshot([
          _kline(0, 10, volume: 0),
          _kline(1, 11, volume: 0),
        ]),
      );
      expect(_last(zeroVolume, 'vwap', 'vwap'), isNull);

      final rocData = <Kline>[
        _zeroPriceKline(0),
        ...List<Kline>.generate(
          12,
          (offset) => _kline(offset + 1, offset + 1.0),
        ),
      ];
      final roc = _calculate(_snapshot(rocData));
      expect(_value(roc, 'roc', 'roc', 12), 0);
    });

    test('publishes null until every warmup window is available', () {
      final results = _calculate(_snapshot(_linearKlines(40)));

      expect(_value(results, 'atr', 'atr', 12), isNull);
      expect(_value(results, 'cci', 'cci', 18), isNull);
      expect(_value(results, 'dmi', 'plusDi', 13), isNull);
      expect(_value(results, 'dmi', 'adx', 26), isNull);
      expect(_value(results, 'roc', 'roc', 11), isNull);
      expect(_value(results, 'stochRsi', 'k', 28), isNull);
      expect(_value(results, 'stochRsi', 'd', 30), isNull);
      expect(_value(results, 'stochRsi', 'd', 31), isNotNull);
    });

    test('incremental append and update match fresh calculations', () {
      final all = buildV2KlineFixture(101);
      final store = KlineStore()..replace(all.take(100));
      final registry = IndicatorRegistry();
      registerAdditionalIndicatorDefinitions(registry);
      final cache = IndicatorCache(registry);
      final configs = _configs();
      for (final config in configs) {
        cache.resolve(store.snapshot, config);
      }

      store.append([all.last]);
      _expectCacheMatchesFresh(cache, store.snapshot, configs);
      expect(cache.incrementalCalculations, 6);

      final last = store.snapshot.lastOrNull!;
      store.update(
        last.copyWith(
          close: last.close + 0.1,
          high: last.high + 0.1,
          baseVolume: last.baseVolume + 10,
          quoteVolume: last.quoteVolume + 10000,
        ),
      );
      _expectCacheMatchesFresh(cache, store.snapshot, configs);
      expect(cache.incrementalCalculations, 12);
    });

    test('rejects fractional, zero, and negative parameters', () {
      final registry = IndicatorRegistry();
      registerAdditionalIndicatorDefinitions(registry);
      final snapshot = _snapshot(_linearKlines(30));

      expect(
        () => registry.calculate(
          snapshot,
          IndicatorConfig(
            instanceId: 'atr',
            definitionId: AtrIndicatorDefinition.definitionId,
            parameters: const {'period': 2.5},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => registry.calculate(
          snapshot,
          IndicatorConfig(
            instanceId: 'cci',
            definitionId: CciIndicatorDefinition.definitionId,
            parameters: const {'constant': 0},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => registry.calculate(
          snapshot,
          IndicatorConfig(
            instanceId: 'stoch',
            definitionId: StochRsiIndicatorDefinition.definitionId,
            parameters: const {'dPeriod': -1},
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

List<IndicatorConfig> _configs() => [
      IndicatorConfig(
        instanceId: 'vwap',
        definitionId: VwapIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'atr',
        definitionId: AtrIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'cci',
        definitionId: CciIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'dmi',
        definitionId: DmiIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'roc',
        definitionId: RocIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'stochRsi',
        definitionId: StochRsiIndicatorDefinition.definitionId,
      ),
    ];

Map<String, IndicatorResult> _calculate(VersionedKlineData input) {
  final registry = IndicatorRegistry();
  registerAdditionalIndicatorDefinitions(registry);
  return {
    for (final config in _configs())
      config.instanceId: registry.calculate(input, config),
  };
}

void _expectCacheMatchesFresh(
  IndicatorCache cache,
  VersionedKlineData input,
  List<IndicatorConfig> configs,
) {
  final fresh = _calculate(input);
  for (final config in configs) {
    final actual = cache.resolve(input, config);
    final expected = fresh[config.instanceId]!;
    for (final series in actual.series) {
      final actualValue = series.values.last;
      final expectedValue = expected.seriesById(series.id)!.values.last;
      if (expectedValue == null) {
        expect(
          actualValue,
          isNull,
          reason: '${config.instanceId}.${series.id}',
        );
      } else {
        expect(
          actualValue,
          closeTo(expectedValue, _tolerance),
          reason: '${config.instanceId}.${series.id}',
        );
      }
    }
  }
}

KlineSnapshot _snapshot(List<Kline> values) =>
    (KlineStore()..replace(values)).snapshot;

List<Kline> _linearKlines(int count, {double step = 1}) => List<Kline>.generate(
      count,
      (index) => _kline(index, 10 + index * step),
      growable: false,
    );

Kline _kline(int index, double price, {double volume = 1}) {
  final openTime = 1704067200000 + index * 60000;
  return Kline(
    symbol: 'TEST',
    interval: KlineInterval.oneMinute,
    openTime: openTime,
    closeTime: openTime + 59999,
    open: price,
    high: price + 1,
    low: price - 1,
    close: price,
    baseVolume: volume,
    quoteVolume: volume * price,
    tradeCount: 1,
    isClosed: true,
  );
}

Kline _zeroPriceKline(int index) {
  final openTime = 1704067200000 + index * 60000;
  return Kline(
    symbol: 'TEST',
    interval: KlineInterval.oneMinute,
    openTime: openTime,
    closeTime: openTime + 59999,
    open: 0,
    high: 0,
    low: 0,
    close: 0,
    baseVolume: 0,
    quoteVolume: 0,
    tradeCount: 0,
    isClosed: true,
  );
}

double? _value(
  Map<String, IndicatorResult> results,
  String resultId,
  String seriesId,
  int index,
) =>
    results[resultId]!.seriesById(seriesId)!.values[index];

double? _last(
  Map<String, IndicatorResult> results,
  String resultId,
  String seriesId,
) =>
    results[resultId]!.seriesById(seriesId)!.values.last;
