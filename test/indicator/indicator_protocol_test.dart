import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  group('IndicatorParameterSpec', () {
    test('默认值与计算时读取共用正整数和正数约束', () {
      const period = IndicatorParameterSpec.integer('period', '周期', 10);
      const multiplier = IndicatorParameterSpec.number('multiplier', '倍数', 3);
      final defaults =
          IndicatorConfig(instanceId: 'super', definitionId: 'builtin.super');
      expect(period.readInt(defaults), 10);
      expect(multiplier.readDouble(defaults), 3);
      expect(period.parse(' 12 '), 12);
      expect(period.parse('12.0'), 12);
      expect(multiplier.parse('1.5'), 1.5);
      expect(() => period.parse('1.5'), throwsArgumentError);
      expect(() => period.parse('0'), throwsArgumentError);
      expect(() => multiplier.parse('-1'), throwsArgumentError);
      expect(
        () => period.readInt(
          IndicatorConfig(
            instanceId: 'super',
            definitionId: 'builtin.super',
            parameters: const {'period': 1.5},
          ),
        ),
        throwsArgumentError,
      );
    });

    test('已接入的定义公开与计算一致的参数元数据', () {
      final registry = IndicatorRegistry();
      registerBuiltInIndicatorDefinitions(registry);
      for (final id in [
        'legacy.ma',
        'legacy.ema',
        'legacy.boll',
        'legacy.sar',
        'legacy.vol',
        'legacy.macd',
        'legacy.rsi',
        'legacy.kdj',
        'legacy.wr',
        'legacy.obv',
        'builtin.super',
        'builtin.atr',
        'builtin.cci',
        'builtin.dmi',
        'builtin.roc',
        'builtin.stochRsi',
      ]) {
        final definition =
            registry.find(id)! as ParameterizedIndicatorDefinition;
        expect(definition.parameterSpecs, isNotEmpty);
        expect(
          definition.parameterSpecs.map((spec) => spec.key).toSet().length,
          definition.parameterSpecs.length,
        );
      }
      final ma =
          registry.find('legacy.ma')! as ParameterizedIndicatorDefinition;
      expect(ma.parameterSpecs.length, 4); // 旧算法保留第四路以兼容已有接入。
      expect(
        ma.parameterSpecs.where((spec) => spec.visibleInSettings).length,
        3,
      ); // 候选主图只呈现三条线。
      expect(
        registry.find('builtin.avl'),
        isNot(isA<ParameterizedIndicatorDefinition>()),
      );
      expect(
        registry.find('builtin.vwap'),
        isNot(isA<ParameterizedIndicatorDefinition>()),
      );
    });

    test('SAR 的关联上限由参数描述统一校验', () {
      const specs = [
        IndicatorParameterSpec.number(
          'afStart',
          '初始加速',
          0.02,
          notGreaterThanKey: 'afMax',
        ),
        IndicatorParameterSpec.number(
          'afIncrement',
          '加速步长',
          0.02,
          notGreaterThanKey: 'afMax',
        ),
        IndicatorParameterSpec.number('afMax', '加速上限', 0.2),
      ];
      final invalid = IndicatorConfig(
        instanceId: 'sar',
        definitionId: 'legacy.sar',
        parameters: const {'afStart': 0.3},
      );
      expect(
        () => IndicatorParameterSpec.validateSet(specs, invalid),
        throwsArgumentError,
      );
      final valid = IndicatorConfig(
        instanceId: 'sar',
        definitionId: 'legacy.sar',
        parameters: const {'afStart': 0.3, 'afMax': 0.4},
      );
      expect(
        () => IndicatorParameterSpec.validateSet(specs, valid),
        returnsNormally,
      );
    });
  });

  group('IndicatorConfig', () {
    test('is immutable and compares by value independent of map order', () {
      final parameters = <String, num>{'period': 7, 'multiplier': 2};
      final first = IndicatorConfig(
        instanceId: 'ma-fast',
        definitionId: 'ma',
        parameters: parameters,
        seriesStyleKeys: const {'value': 'indicator.fast'},
      );
      parameters['period'] = 99;
      final equal = IndicatorConfig(
        instanceId: 'ma-fast',
        definitionId: 'ma',
        parameters: const {'multiplier': 2, 'period': 7},
        seriesStyleKeys: const {'value': 'indicator.fast'},
      );

      expect(first, equal);
      expect(first.hashCode, equal.hashCode);
      expect(first.parameter('period'), 7);
      expect(() => first.parameters['period'] = 10, throwsUnsupportedError);
    });

    test('rejects empty ids, keys, style refs, and non-finite parameters', () {
      expect(
        () => IndicatorConfig(instanceId: '', definitionId: 'ma'),
        throwsArgumentError,
      );
      expect(
        () => IndicatorConfig(
          instanceId: 'one',
          definitionId: 'ma',
          parameters: const {'': 7},
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorConfig(
          instanceId: 'one',
          definitionId: 'ma',
          parameters: const {'period': double.nan},
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorConfig(
          instanceId: 'one',
          definitionId: 'ma',
          seriesStyleKeys: const {'value': ' '},
        ),
        throwsArgumentError,
      );
    });
  });

  group('renderer and series contracts', () {
    test('freeze renderer metadata without Flutter drawing types', () {
      final descriptor = _CloseIndicator().rendererDescriptor;

      expect(descriptor.placement, IndicatorPlacement.mainChart);
      expect(descriptor.series.single.id, 'value');
      expect(descriptor.series.single.drawingKind, IndicatorDrawingKind.line);
      expect(() => descriptor.series.clear(), throwsUnsupportedError);
    });

    test('reject duplicate descriptors and malformed calculated values', () {
      final duplicate = IndicatorSeriesDescriptor(
        id: 'value',
        label: 'Value',
        drawingKind: IndicatorDrawingKind.line,
      );

      expect(
        () => IndicatorRendererDescriptor(
          placement: IndicatorPlacement.mainChart,
          series: [duplicate, duplicate],
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorRendererDescriptor(
          placement: IndicatorPlacement.mainChart,
          series: [duplicate],
          legend: IndicatorLegendDescriptor(
            labelTemplates: const {'missing': 'Missing'},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorSeriesDescriptor(
          id: 'line',
          label: 'Line',
          drawingKind: IndicatorDrawingKind.line,
          colorStrategy: IndicatorColorStrategy.valueSign,
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorSeriesDescriptor(
          id: 'line',
          label: 'Line',
          drawingKind: IndicatorDrawingKind.line,
          lineStrokeWidthMultiplier: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorSeriesDescriptor(
          id: 'bars',
          label: 'Bars',
          drawingKind: IndicatorDrawingKind.histogram,
          areaBaseline: IndicatorAreaBaseline.candleClose,
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorSeriesDescriptor(
          id: 'line',
          label: 'Line',
          drawingKind: IndicatorDrawingKind.line,
          areaFillOpacity: 1.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorSeriesDescriptor(
          id: 'point',
          label: 'Point',
          drawingKind: IndicatorDrawingKind.points,
          histogramStyle: IndicatorHistogramStyle.valueTrend,
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorSeries(id: 'value', values: const [double.infinity]),
        throwsArgumentError,
      );
      expect(
        () => IndicatorResult(
          instanceId: 'one',
          definitionId: 'close',
          dataVersion: KlineDataVersion.zero,
          length: 2,
          series: [
            IndicatorSeries(id: 'value', values: const [1]),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => IndicatorResult(
          instanceId: 'one',
          definitionId: 'close',
          dataVersion: KlineDataVersion.zero,
          length: 2,
          series: [
            IndicatorSeries(id: 'value', values: const [1, 2]),
          ],
          computationState: IndicatorComputationState(
            length: 1,
            series: [
              IndicatorSeries(id: 'state', values: const [1]),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('keeps copy-on-write incremental values immutable and bounded', () {
      var series = IndicatorSeries(
        id: 'value',
        values: List<double?>.generate(1000, (index) => index.toDouble()),
      );
      for (var iteration = 0; iteration < 520; iteration++) {
        final buffer = IndicatorValueBuffer.from(series.values, 1000)
          ..[999] = iteration.toDouble();
        series = IndicatorSeries.takeOwnership(id: 'value', values: buffer);
      }

      expect(series.values.first, 0);
      expect(series.values.last, 519);
      expect(() => series.values[999] = 0, throwsUnsupportedError);
    });
  });

  group('IndicatorRegistry', () {
    test('参数栏模板引用未声明参数或括号不完整时拒绝注册', () {
      final registry = IndicatorRegistry();
      expect(
        () =>
            registry.register(const _InvalidLegendIndicator('Value({period})')),
        throwsArgumentError,
      );
      expect(
        () => registry.register(const _InvalidLegendIndicator('Value({period')),
        throwsArgumentError,
      );
      expect(registry.definitions, isEmpty);
    });

    test('registers a custom indicator without a core enum or switch', () {
      final store = KlineStore()..replace(buildV2KlineFixture(3));
      final registry = IndicatorRegistry()..register(_CloseIndicator());
      final config = IndicatorConfig(
        instanceId: 'close-primary',
        definitionId: 'test.close',
      );

      final result = registry.calculate(store.snapshot, config);

      expect(result.instanceId, 'close-primary');
      expect(result.dataVersion, store.snapshot.version);
      expect(result.length, 3);
      expect(
        result.seriesById('value')?.values,
        store.snapshot.data.map((item) => item.close),
      );
      expect(() => result.series.single.values.add(1), throwsUnsupportedError);
    });

    test('supports independent instances of the same definition', () {
      final store = KlineStore()..replace(buildV2KlineFixture(2));
      final registry = IndicatorRegistry()..register(_CloseIndicator());

      final first = registry.calculate(
        store.snapshot,
        IndicatorConfig(instanceId: 'one', definitionId: 'test.close'),
      );
      final second = registry.calculate(
        store.snapshot,
        IndicatorConfig(instanceId: 'two', definitionId: 'test.close'),
      );

      expect(first.instanceId, 'one');
      expect(second.instanceId, 'two');
      expect(identical(first, second), isFalse);
    });

    test('rejects duplicate, missing, and contract-breaking definitions', () {
      final registry = IndicatorRegistry()..register(_CloseIndicator());
      final snapshot = KlineStore().snapshot;

      expect(() => registry.register(_CloseIndicator()), throwsStateError);
      expect(
        () => registry.calculate(
          snapshot,
          IndicatorConfig(instanceId: 'one', definitionId: 'missing'),
        ),
        throwsStateError,
      );

      final broken = IndicatorRegistry()..register(_BrokenIndicator());
      expect(
        () => broken.calculate(
          snapshot,
          IndicatorConfig(instanceId: 'one', definitionId: 'test.broken'),
        ),
        throwsStateError,
      );
    });

    test('exposes a read-only registry view', () {
      final registry = IndicatorRegistry()..register(_CloseIndicator());

      expect(registry.find('test.close'), isA<_CloseIndicator>());
      expect(() => registry.definitions.clear(), throwsUnsupportedError);
    });
  });
}

final class _CloseIndicator implements IndicatorDefinition {
  @override
  String get id => 'test.close';

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.mainChart,
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: 'Close',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

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
            values: input.data.map((item) => item.close),
          ),
        ],
      );
}

final class _InvalidLegendIndicator implements IndicatorDefinition {
  const _InvalidLegendIndicator(this.template);

  final String template;

  @override
  String get id => 'test.invalidLegend';

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.mainChart,
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: 'Value',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
        legend: IndicatorLegendDescriptor(
          labelTemplates: {'value': template},
        ),
      );

  @override
  IndicatorResult calculate(VersionedKlineData input, IndicatorConfig config) =>
      _CloseIndicator().calculate(input, config);
}

final class _BrokenIndicator implements IndicatorDefinition {
  @override
  String get id => 'test.broken';

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.separatePanel,
        series: [
          IndicatorSeriesDescriptor(
            id: 'expected',
            label: 'Expected',
            drawingKind: IndicatorDrawingKind.histogram,
          ),
        ],
      );

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
            id: 'unexpected',
            values: List.filled(input.data.length, null),
          ),
        ],
      );
}
