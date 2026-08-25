import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  group('IndicatorEngine', () {
    test('supports multiple instances of one definition and caches each', () {
      final registry = IndicatorRegistry()..register(CciIndicatorDefinition());
      final engine = IndicatorEngine(registry: registry);
      final snapshot =
          (KlineStore()..replace(buildV2KlineFixture(100))).snapshot;
      final configs = [
        IndicatorConfig(
          instanceId: 'cci-fast',
          definitionId: CciIndicatorDefinition.definitionId,
          parameters: const {'period': 5},
          seriesStyleKeys: const {'cci': 'indicator.cci.fast'},
        ),
        IndicatorConfig(
          instanceId: 'cci-slow',
          definitionId: CciIndicatorDefinition.definitionId,
          parameters: const {'period': 20},
          seriesStyleKeys: const {'cci': 'indicator.cci.slow'},
        ),
      ];

      final first = engine.resolveAll(snapshot, configs);
      final second = engine.resolveAll(snapshot, configs);

      expect(first.isSuccessful, isTrue);
      expect(first.results, hasLength(2));
      expect(
        first.results['cci-fast']!.series.single.values.last,
        isNot(first.results['cci-slow']!.series.single.values.last),
      );
      expect(
        identical(second.results['cci-fast'], first.results['cci-fast']),
        isTrue,
      );
      expect(engine.cache.cacheHits, 2);
    });

    test('isolates unknown, throwing, and non-finite instances', () {
      final throwing = _ThrowingDefinition();
      final registry = IndicatorRegistry()
        ..register(RocIndicatorDefinition())
        ..register(throwing)
        ..register(_NonFiniteDefinition());
      final engine = IndicatorEngine(registry: registry);
      final snapshot =
          (KlineStore()..replace(buildV2KlineFixture(20))).snapshot;
      final configs = [
        IndicatorConfig(
          instanceId: 'good',
          definitionId: RocIndicatorDefinition.definitionId,
        ),
        IndicatorConfig(
          instanceId: 'unknown',
          definitionId: 'missing',
        ),
        IndicatorConfig(
          instanceId: 'throwing',
          definitionId: _ThrowingDefinition.definitionId,
        ),
        IndicatorConfig(
          instanceId: 'non-finite',
          definitionId: _NonFiniteDefinition.definitionId,
        ),
      ];

      final batch = engine.resolveAll(snapshot, configs);

      expect(batch.results.keys, ['good']);
      expect(
        batch.failures.keys,
        containsAll(['unknown', 'throwing', 'non-finite']),
      );
      expect(batch.failures['unknown']!.error, isA<StateError>());
      expect(batch.failures['throwing']!.error, isA<StateError>());
      expect(batch.failures['non-finite']!.error, isA<ArgumentError>());
      expect(batch.length, 4);
      expect(batch.hasFailures, isTrue);
      expect(() => batch.results.clear(), throwsUnsupportedError);
      expect(() => batch.failures.clear(), throwsUnsupportedError);

      final retried = engine.resolveAll(snapshot, configs);
      expect(retried.results['good'], same(batch.results['good']));
      expect(throwing.calls, 2, reason: 'Failures must not poison the cache.');
    });

    test('all sixteen built-ins remain finite on short and flat inputs', () {
      final registry = IndicatorRegistry();
      registerBuiltInIndicatorDefinitions(registry);
      final engine = IndicatorEngine(registry: registry);

      for (final values in [
        buildV2KlineFixture(1),
        _flatKlines(100),
      ]) {
        final batch = engine.resolveAll(
          (KlineStore()..replace(values)).snapshot,
          _allBuiltInConfigs(),
        );
        expect(batch.failures, isEmpty);
        expect(batch.results, hasLength(16));
        for (final result in batch.results.values) {
          for (final series in [
            ...result.series,
            ...?result.computationState?.series,
          ]) {
            expect(
              series.values.every(
                (value) => value == null || value.isFinite,
              ),
              isTrue,
              reason: '${result.instanceId}.${series.id}',
            );
          }
        }
      }
    });

    test('rejects duplicate instance ids before doing partial work', () {
      final engine = IndicatorEngine(
        registry: IndicatorRegistry()..register(RocIndicatorDefinition()),
      );
      final snapshot =
          (KlineStore()..replace(buildV2KlineFixture(20))).snapshot;
      final duplicate = IndicatorConfig(
        instanceId: 'same',
        definitionId: RocIndicatorDefinition.definitionId,
      );

      expect(
        () => engine.resolveAll(snapshot, [duplicate, duplicate]),
        throwsArgumentError,
      );
      expect(engine.cache.length, 0);
    });

    test('keeps registries, caches, and failures isolated per engine', () {
      final first = IndicatorEngine(
        registry: IndicatorRegistry()..register(RocIndicatorDefinition()),
      );
      final second = IndicatorEngine();
      final snapshot =
          (KlineStore()..replace(buildV2KlineFixture(20))).snapshot;
      final config = IndicatorConfig(
        instanceId: 'roc',
        definitionId: RocIndicatorDefinition.definitionId,
      );

      expect(first.resolveAll(snapshot, [config]).isSuccessful, isTrue);
      expect(second.resolveAll(snapshot, [config]).hasFailures, isTrue);
      expect(first.cache.length, 1);
      expect(second.cache.length, 0);
      first.clear();
      expect(first.cache.length, 0);
    });
  });
}

List<IndicatorConfig> _allBuiltInConfigs() => [
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
      ),
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
        instanceId: 'stoch-rsi',
        definitionId: StochRsiIndicatorDefinition.definitionId,
      ),
    ];

List<Kline> _flatKlines(int count) => List<Kline>.generate(
      count,
      (index) {
        final openTime = 1704067200000 + index * 60000;
        return Kline(
          symbol: 'FLAT',
          interval: KlineInterval.oneMinute,
          openTime: openTime,
          closeTime: openTime + 59999,
          open: 100,
          high: 100,
          low: 100,
          close: 100,
          baseVolume: 0,
          quoteVolume: 0,
          tradeCount: 0,
          isClosed: true,
        );
      },
      growable: false,
    );

final class _ThrowingDefinition implements IndicatorDefinition {
  static const definitionId = 'test.throwing';
  int calls = 0;

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _descriptor();

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    calls++;
    throw StateError('Expected test failure.');
  }
}

final class _NonFiniteDefinition implements IndicatorDefinition {
  static const definitionId = 'test.non-finite';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _descriptor();

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) =>
      IndicatorResult(
        instanceId: config.instanceId,
        definitionId: id,
        dataVersion: input.version,
        length: input.data.length,
        series: [
          IndicatorSeries(
            id: 'value',
            values: List.filled(input.data.length, double.nan),
          ),
        ],
      );
}

IndicatorRendererDescriptor _descriptor() => IndicatorRendererDescriptor(
      placement: IndicatorPlacement.separatePanel,
      series: [
        IndicatorSeriesDescriptor(
          id: 'value',
          label: 'Value',
          drawingKind: IndicatorDrawingKind.line,
        ),
      ],
    );
