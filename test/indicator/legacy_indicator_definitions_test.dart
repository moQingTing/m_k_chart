import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'package:m_k_chart/src/adapter/adapter.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/kline_fixture.dart';

const _tolerance = 1e-9;

void main() {
  group('legacy indicator migration', () {
    test('registers all ten definitions without a core enum or switch', () {
      final registry = IndicatorRegistry();
      registerLegacyIndicatorDefinitions(registry);

      expect(
        registry.definitions.keys,
        containsAll(<String>{
          MovingAverageIndicatorDefinition.definitionId,
          ExponentialMovingAverageIndicatorDefinition.definitionId,
          BollingerBandsIndicatorDefinition.definitionId,
          ParabolicSarIndicatorDefinition.definitionId,
          VolumeIndicatorDefinition.definitionId,
          MacdIndicatorDefinition.definitionId,
          KdjIndicatorDefinition.definitionId,
          RsiIndicatorDefinition.definitionId,
          WilliamsRIndicatorDefinition.definitionId,
          ObvIndicatorDefinition.definitionId,
        }),
      );
      expect(registry.definitions, hasLength(10));
      expect(
        registry
            .find(VolumeIndicatorDefinition.definitionId)!
            .rendererDescriptor
            .series
            .first
            .colorStrategy,
        IndicatorColorStrategy.candleDirection,
      );
      final macd = registry
          .find(MacdIndicatorDefinition.definitionId)!
          .rendererDescriptor
          .series
          .first;
      expect(macd.colorStrategy, IndicatorColorStrategy.valueSign);
      expect(macd.histogramStyle, IndicatorHistogramStyle.valueTrend);
      expect(
        registry
            .find(ParabolicSarIndicatorDefinition.definitionId)!
            .rendererDescriptor
            .series
            .single
            .colorStrategy,
        IndicatorColorStrategy.pricePosition,
      );
    });

    test('matches every frozen legacy series at representative indexes', () {
      final legacy = buildKlineFixture(100);
      _calculateLegacy(legacy);
      final store = _storeFromLegacy(legacy);
      final results = _calculateV2(store.snapshot);

      for (final index in const [29, 59, 99]) {
        final expected = legacy[index];
        final actual = <String, double?>{
          'ma5': _value(results, 'ma', 'ma5', index),
          'ma10': _value(results, 'ma', 'ma10', index),
          'ma20': _value(results, 'ma', 'ma20', index),
          'ma30': _value(results, 'ma', 'ma30', index),
          'ema5': _value(results, 'ema', 'ema5', index),
          'ema10': _value(results, 'ema', 'ema10', index),
          'ema30': _value(results, 'ema', 'ema30', index),
          'bollUp': _value(results, 'boll', 'up', index),
          'bollMb': _value(results, 'boll', 'mb', index),
          'bollDn': _value(results, 'boll', 'dn', index),
          'sar': _value(results, 'sar', 'sar', index),
          'volume': _value(results, 'vol', 'volume', index),
          'volMa5': _value(results, 'vol', 'ma5', index),
          'volMa10': _value(results, 'vol', 'ma10', index),
          'macd': _value(results, 'macd', 'macd', index),
          'dif': _value(results, 'macd', 'dif', index),
          'dea': _value(results, 'macd', 'dea', index),
          'k': _value(results, 'kdj', 'k', index),
          'd': _value(results, 'kdj', 'd', index),
          'j': _value(results, 'kdj', 'j', index),
          'rsi': _value(results, 'rsi', 'rsi', index),
          'wr': _value(results, 'wr', 'wr', index),
          'obv': _value(results, 'obv', 'obv', index),
          'maObv': _value(results, 'obv', 'ma', index),
        };
        final expectedValues = <String, double>{
          'ma5': expected.MA5Price,
          'ma10': expected.MA10Price,
          'ma20': expected.MA20Price,
          'ma30': expected.MA30Price,
          'ema5': expected.emaValues[5]!,
          'ema10': expected.emaValues[10]!,
          'ema30': expected.emaValues[30]!,
          'bollUp': expected.up,
          'bollMb': expected.mb,
          'bollDn': expected.dn,
          'sar': expected.sar,
          'volume': expected.vol,
          'volMa5': expected.MA5Volume,
          'volMa10': expected.MA10Volume,
          'macd': expected.macd,
          'dif': expected.dif,
          'dea': expected.dea,
          'k': expected.k,
          'd': expected.d,
          'j': expected.j,
          'rsi': expected.rsi,
          'wr': expected.r,
          'obv': expected.obv,
          'maObv': expected.maOBV,
        };
        for (final entry in expectedValues.entries) {
          expect(
            actual[entry.key],
            closeTo(entry.value, _tolerance),
            reason: '${entry.key} at $index',
          );
        }
      }
    });

    test('uses null instead of legacy zero for insufficient values', () {
      final results = _calculateV2(
        (KlineStore()..replace(_v2Fixture(10))).snapshot,
      );

      expect(_value(results, 'ma', 'ma30', 9), isNull);
      expect(_value(results, 'boll', 'mb', 9), isNull);
      expect(_value(results, 'kdj', 'k', 9), isNull);
      expect(_value(results, 'rsi', 'rsi', 9), isNull);
      expect(_value(results, 'wr', 'wr', 9), isNull);
      expect(_value(results, 'obv', 'ma', 9), isNull);
    });

    test('accepts configurable periods and smoothing constants', () {
      final registry = IndicatorRegistry();
      registerLegacyIndicatorDefinitions(registry);
      final snapshot = (KlineStore()..replace(_v2Fixture(60))).snapshot;

      double? last(
        String definitionId,
        String seriesId,
        Map<String, num> parameters,
      ) =>
          registry
              .calculate(
                snapshot,
                IndicatorConfig(
                  instanceId: '$definitionId-$seriesId-${parameters.hashCode}',
                  definitionId: definitionId,
                  parameters: parameters,
                ),
              )
              .seriesById(seriesId)!
              .values
              .last;

      expect(
        last(MovingAverageIndicatorDefinition.definitionId, 'ma5', const {}),
        isNot(
          last(
            MovingAverageIndicatorDefinition.definitionId,
            'ma5',
            const {'period1': 7},
          ),
        ),
      );
      expect(
        last(
          ExponentialMovingAverageIndicatorDefinition.definitionId,
          'ema5',
          const {},
        ),
        isNot(
          last(
            ExponentialMovingAverageIndicatorDefinition.definitionId,
            'ema5',
            const {'period1': 7},
          ),
        ),
      );
      expect(
        last(VolumeIndicatorDefinition.definitionId, 'ma5', const {}),
        isNot(
          last(
            VolumeIndicatorDefinition.definitionId,
            'ma5',
            const {'fastPeriod': 7},
          ),
        ),
      );
      expect(
        last(MacdIndicatorDefinition.definitionId, 'dif', const {}),
        isNot(
          last(
            MacdIndicatorDefinition.definitionId,
            'dif',
            const {'fastPeriod': 6, 'slowPeriod': 18, 'signalPeriod': 5},
          ),
        ),
      );
      expect(
        last(KdjIndicatorDefinition.definitionId, 'k', const {}),
        isNot(
          last(
            KdjIndicatorDefinition.definitionId,
            'k',
            const {'period': 9, 'kSmoothing': 2, 'dSmoothing': 4},
          ),
        ),
      );
    });

    test('cache append results match a fresh full calculation', () {
      final all = _v2Fixture(101);
      final store = KlineStore()..replace(all.take(100));
      final registry = IndicatorRegistry();
      registerLegacyIndicatorDefinitions(registry);
      final cache = IndicatorCache(registry);
      final configs = _configs();
      for (final config in configs) {
        cache.resolve(store.snapshot, config);
      }

      store.append([all.last]);
      final appended = {
        for (final config in configs)
          config.instanceId: cache.resolve(store.snapshot, config),
      };
      final fresh = _calculateV2((KlineStore()..replace(all)).snapshot);

      for (final config in configs) {
        final actual = appended[config.instanceId]!;
        final expected = fresh[config.instanceId]!;
        for (final series in actual.series) {
          expect(
            series.values.last,
            closeTo(expected.seriesById(series.id)!.values.last!, _tolerance),
            reason: '${config.instanceId}.${series.id}',
          );
        }
      }
      expect(cache.incrementalCalculations, 10);

      final previousLast = store.snapshot.lastOrNull!;
      store.update(
        previousLast.copyWith(
          close: previousLast.close + 0.1,
          high: previousLast.high + 0.1,
        ),
      );
      final updated = {
        for (final config in configs)
          config.instanceId: cache.resolve(store.snapshot, config),
      };
      final updatedFresh =
          _calculateV2((KlineStore()..replace(store.snapshot.data)).snapshot);
      for (final config in configs) {
        final actual = updated[config.instanceId]!;
        final expected = updatedFresh[config.instanceId]!;
        for (final series in actual.series) {
          expect(
            series.values.last,
            closeTo(expected.seriesById(series.id)!.values.last!, _tolerance),
            reason: 'updated ${config.instanceId}.${series.id}',
          );
        }
      }
      expect(cache.incrementalCalculations, 20);
    });

    test('rejects invalid algorithm parameters', () {
      final registry = IndicatorRegistry();
      registerLegacyIndicatorDefinitions(registry);
      final snapshot = (KlineStore()..replace(_v2Fixture(3))).snapshot;

      expect(
        () => registry.calculate(
          snapshot,
          IndicatorConfig(
            instanceId: 'boll',
            definitionId: BollingerBandsIndicatorDefinition.definitionId,
            parameters: const {'period': 2.5},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => registry.calculate(
          snapshot,
          IndicatorConfig(
            instanceId: 'sar',
            definitionId: ParabolicSarIndicatorDefinition.definitionId,
            parameters: const {'afStart': 0.3, 'afMax': 0.2},
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

final _emaConfigs = <EMAConfig>[
  EMAConfig(period: 5, color: Colors.yellow),
  EMAConfig(period: 10, color: Colors.pink),
  EMAConfig(period: 30, color: Colors.purple),
];

final _chartStyle = ChartStyle()..emaConfigs = _emaConfigs;

void _calculateLegacy(List<KLineEntity> values) {
  DataUtil.calculate(
    values,
    obvPeriod: 30,
    emaConfigs: _emaConfigs,
    chartStyle: _chartStyle,
  );
}

KlineStore _storeFromLegacy(List<KLineEntity> values) {
  final adapter = KLineEntityAdapter(
    symbol: 'BTCUSDT',
    interval: KlineInterval.oneMinute,
  );
  return KlineStore()
    ..replace(
      values.asMap().entries.map(
            (entry) => adapter.toKline(
              entry.value,
              isClosed: entry.key != values.length - 1,
            ),
          ),
    );
}

List<Kline> _v2Fixture(int count) =>
    _storeFromLegacy(buildKlineFixture(count)).snapshot.data;

Map<String, IndicatorResult> _calculateV2(VersionedKlineData input) {
  final registry = IndicatorRegistry();
  registerLegacyIndicatorDefinitions(registry);
  return {
    for (final config in _configs())
      config.instanceId: registry.calculate(input, config),
  };
}

List<IndicatorConfig> _configs() => [
      IndicatorConfig(
        instanceId: 'ma',
        definitionId: MovingAverageIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'ema',
        definitionId: ExponentialMovingAverageIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'boll',
        definitionId: BollingerBandsIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'sar',
        definitionId: ParabolicSarIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'vol',
        definitionId: VolumeIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'macd',
        definitionId: MacdIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'kdj',
        definitionId: KdjIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'rsi',
        definitionId: RsiIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'wr',
        definitionId: WilliamsRIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'obv',
        definitionId: ObvIndicatorDefinition.definitionId,
        parameters: const {'period': 30},
      ),
    ];

double? _value(
  Map<String, IndicatorResult> results,
  String resultId,
  String seriesId,
  int index,
) =>
    results[resultId]!.seriesById(seriesId)!.values[index];
