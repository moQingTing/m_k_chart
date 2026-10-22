import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/controller/k_chart_history_contract.dart';
import 'package:m_k_chart/src/controller/k_chart_indicator_binding.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(100);
  final series = KlineSeries.fromKline(candles.first);

  KChartIndicatorBinding binding({
    String id = 'count',
    String definition = 'test.count',
    String panel = 'main',
    Map<String, num> parameters = const {},
    Iterable<String>? visibleSeriesIds,
  }) =>
      KChartIndicatorBinding(
        panelId: panel,
        visibleSeriesIds: visibleSeriesIds,
        config: IndicatorConfig(
          instanceId: id,
          definitionId: definition,
          parameters: parameters,
        ),
      );

  KChartDataCoordinator create({
    Iterable<KChartIndicatorBinding> bindings = const [],
    Iterable<IndicatorDefinition> definitions = const [],
    List<Kline>? data,
    KChartHistoryLoader? historyLoader,
  }) {
    final chart = KChartDataCoordinator(
      series: series,
      initialData: data ?? candles,
      panelIds: const ['main', 'one', 'two'],
      initialViewport: ChartViewport(width: 80),
      indicators: bindings,
      indicatorDefinitions: definitions,
      historyLoader: historyLoader,
    );
    addTearDown(chart.dispose);
    return chart;
  }

  test('bindings are immutable structural values and freeze host configuration',
      () {
    final parameters = <String, num>{'factor': 2};
    final first = binding(parameters: parameters);
    parameters['factor'] = 3;
    expect(first.config.parameters['factor'], 2);
    expect(first.copyWith(), first);
    expect(first.copyWith().hashCode, first.hashCode);
    expect(first.copyWith(panelId: 'one'), isNot(first));
    final visible = binding(
      definition: 'legacy.ema',
      visibleSeriesIds: ['ema5', 'ema10'],
    );
    expect(visible.copyWith(visibleSeriesIds: ['ema10', 'ema5']), visible);
    expect(
      visible.copyWith(resetVisibleSeriesIds: true).visibleSeriesIds,
      isNull,
    );
    expect(
      () => visible.visibleSeriesIds!.add('ema30'),
      throwsUnsupportedError,
    );
    expect(
      () => binding(visibleSeriesIds: const []),
      throwsArgumentError,
    );
    expect(() => binding(panel: ' '), throwsArgumentError);
    final input = [first];
    final chart = create(bindings: input, definitions: [_CountingDefinition()]);
    input.clear();
    expect(chart.value.indicators, [first]);
    expect(() => chart.value.indicators.clear(), throwsUnsupportedError);
    expect(
      () => chart.value.indicatorBatch.results.clear(),
      throwsUnsupportedError,
    );
  });

  test('built-ins are registered but no indicators are enabled by default', () {
    final chart = create();
    expect(chart.value.indicatorBatch.length, 0);
    final registry = IndicatorRegistry();
    registerBuiltInIndicatorDefinitions(registry);
    final bindings = [
      for (final id in registry.definitions.keys)
        binding(id: id, definition: id),
    ];
    chart.setIndicators(bindings);
    expect(chart.value.indicatorBatch.failures, isEmpty);
    expect(chart.value.indicatorBatch.results, hasLength(18));
    chart.replaceData(const [], session: chart.session);
    expect(chart.value.indicatorBatch.failures, isEmpty);
    for (final result in chart.value.indicatorBatch.results.values) {
      expect(result.length, 0);
      expect(result.dataVersion, chart.value.data.version);
    }
  });

  test('切换可见序列不重算指标；未知或兼容隐藏序列在提交前拒绝', () {
    final chart = create(
      bindings: [binding(id: 'ema', definition: 'legacy.ema')],
    );
    final batch = chart.value.indicatorBatch;
    chart.setIndicators([
      binding(
        id: 'ema',
        definition: 'legacy.ema',
        visibleSeriesIds: const ['ema5'],
      ),
    ]);
    expect(chart.value.indicatorBatch, same(batch));
    expect(chart.value.indicators.single.visibleSeriesIds, {'ema5'});
    final before = chart.value;
    expect(
      () => chart.setIndicators([
        binding(
          id: 'ema',
          definition: 'legacy.ema',
          visibleSeriesIds: const ['missing'],
        ),
      ]),
      throwsArgumentError,
    );
    expect(
      () => chart.setIndicators([
        binding(
          id: 'ma',
          definition: 'legacy.ma',
          visibleSeriesIds: const ['ma30'],
        ),
      ]),
      throwsArgumentError,
    );
    expect(
      () => chart.setOptions(
        chart.value.options.copyWith(
          indicators: [
            binding(
              id: 'ema',
              definition: 'legacy.ema',
              visibleSeriesIds: const ['missing'],
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );
    expect(chart.value, same(before));
  });

  test('config and data updates publish consistent results in one notification',
      () {
    final definition = _CountingDefinition();
    final chart = create(bindings: [binding()], definitions: [definition]);
    final before = chart.value;
    var calls = 0;
    chart.addListener(() {
      calls++;
      final state = chart.value;
      final result = state.indicatorBatch.results['count']!;
      expect(result.dataVersion, state.data.version);
      expect(result.length, state.data.data.length);
      final factor = state.indicators.single.config.parameters['factor'] ?? 1;
      expect(
        result.series.single.values.last,
        state.data.data.last.close * factor,
      );
    });
    chart.setIndicators([
      binding(parameters: const {'factor': 2}),
    ]);
    expect(calls, 1);
    expect(chart.value.data, same(before.data));
    expect(chart.session, same(before.session));
    expect(
      before.indicatorBatch.results['count']!.series.single.values.last,
      candles.last.close,
    );
    final updated = candles.last.copyWith(close: candles.last.close + 0.1);
    chart.updateKline(updated, session: chart.session);
    expect(calls, 2);
    expect(definition.calls, 3);
  });

  test('equivalent config, selection, navigation and mount do not recalculate',
      () {
    final definition = _CountingDefinition();
    final chart = create(bindings: [binding()], definitions: [definition]);
    final before = chart.value;
    chart.setIndicators([binding()]);
    expect(chart.value, same(before));
    chart.select(openTime: candles[50].openTime, panelId: 'main', price: 10);
    chart.applyViewport(chart.value.viewport.copyWith(width: 120));
    chart.scrollToTime(epochMilliseconds: candles[50].openTime);
    chart.scrollToLatest();
    chart.resetViewport();
    chart.retryIndicators();
    final owner = Object();
    chart.attach(owner);
    chart.detach(owner);
    chart.appendData(const [], session: chart.session);
    chart.replaceData(candles, session: chart.session);
    expect(chart.value.indicatorBatch, same(before.indicatorBatch));
    expect(definition.calls, 1);
  });

  test('reordering indicators or moving panels reuses even failed batch', () {
    final definition = _CountingDefinition()..shouldThrow = true;
    final good =
        binding(id: 'good', definition: CciIndicatorDefinition.definitionId);
    final failing = binding();
    final chart = create(bindings: [good, failing], definitions: [definition]);
    final batch = chart.value.indicatorBatch;
    chart.setIndicators([failing.copyWith(panelId: 'one'), good]);
    chart.setPanels(const ['two', 'main', 'one']);
    expect(chart.value.indicatorBatch, same(batch));
    expect(chart.value.indicators.first.panelId, 'one');
    expect(definition.calls, 1);
  });

  test('panel removal removes bindings and selection atomically', () {
    final definition = _CountingDefinition();
    final chart = create(
      bindings: [binding(id: 'main'), binding(id: 'secondary', panel: 'one')],
      definitions: [definition],
    );
    chart.select(openTime: candles[50].openTime, panelId: 'one', price: 1);
    var calls = 0;
    chart.addListener(() {
      calls++;
      expect(chart.value.selection, isNull);
      expect(chart.value.indicatorBatch.results.keys, ['main']);
      expect(
        chart.value.indicators.map((item) => item.config.instanceId),
        ['main'],
      );
    });
    chart.setPanels(const ['main']);
    expect(calls, 1);
    expect(
      definition.calls,
      2,
      reason: 'Unchanged surviving result is cached.',
    );
  });

  test(
      'combined panel and binding changes need no inconsistent intermediate state',
      () {
    final chart = create();
    chart.select(openTime: candles[50].openTime, panelId: 'one', price: 1);
    final token = chart.session;
    var calls = 0;
    chart.addListener(() => calls++);
    chart.setIndicators(
      [
        binding(
          definition: CciIndicatorDefinition.definitionId,
          panel: 'custom',
        ),
      ],
      panelIds: const ['main', 'custom'],
    );
    expect(chart.value.selection, isNull);
    expect(chart.value.panelIds, ['main', 'custom']);
    expect(chart.value.indicatorBatch.failures, isEmpty);
    expect(chart.session, same(token));
    expect(calls, 1);
  });

  test('invalid structural config rejects before changing state or calculating',
      () {
    final definition = _CountingDefinition();
    final chart = create(bindings: [binding()], definitions: [definition]);
    final before = chart.value;
    expect(
      () => chart.setIndicators([binding(), binding(panel: 'one')]),
      throwsArgumentError,
    );
    expect(
      () => chart.setIndicators([binding(panel: 'missing')]),
      throwsArgumentError,
    );
    expect(
      () => chart.setIndicators([binding()], panelIds: const ['one']),
      throwsArgumentError,
    );
    expect(chart.value, same(before));
    expect(definition.calls, 1);
    expect(
      () => create(bindings: [binding(panel: 'missing')]),
      throwsArgumentError,
    );
    expect(
      () => create(definitions: [MovingAverageIndicatorDefinition()]),
      throwsStateError,
    );
  });

  test('unknown, invalid and throwing indicators are isolated and recoverable',
      () {
    final definition = _CountingDefinition()..shouldThrow = true;
    final good =
        binding(id: 'good', definition: CciIndicatorDefinition.definitionId);
    final chart = create(
      bindings: [
        good,
        binding(
          id: 'bad',
          definition: CciIndicatorDefinition.definitionId,
          parameters: const {'period': 0},
        ),
        binding(id: 'missing', definition: 'missing'),
        binding(),
      ],
      definitions: [definition],
    );
    final batch = chart.value.indicatorBatch;
    expect(batch.results.keys, ['good']);
    expect(batch.failures.keys, containsAll(['bad', 'missing', 'count']));
    expect(() => batch.failures.clear(), throwsUnsupportedError);
    definition.shouldThrow = false;
    chart.retryIndicators();
    expect(
      chart.value.indicatorBatch.results.keys,
      containsAll(['good', 'count']),
    );
    expect(
      chart.value.indicatorBatch.results['good'],
      same(batch.results['good']),
    );
    expect(batch.failures.keys, contains('count'));
    chart.setIndicators([good, binding()]);
    expect(chart.value.indicatorBatch.failures, isEmpty);
  });

  test('multiple periods of the same built-in have separate results', () {
    final chart = create(
      bindings: [
        binding(
          id: 'fast',
          definition: CciIndicatorDefinition.definitionId,
          parameters: const {'period': 5},
        ),
        binding(
          id: 'slow',
          definition: CciIndicatorDefinition.definitionId,
          parameters: const {'period': 20},
        ),
      ],
    );
    final results = chart.value.indicatorBatch.results;
    expect(
      results['fast']!.series.single.values.last,
      isNot(results['slow']!.series.single.values.last),
    );
  });

  test(
      'tail updates and history match fresh full calculation for all built-ins',
      () {
    final registry = IndicatorRegistry();
    registerBuiltInIndicatorDefinitions(registry);
    final chart = create(
      data: candles.sublist(10),
      bindings: [
        for (final id in registry.definitions.keys)
          binding(id: id, definition: id),
      ],
    );
    void compare() {
      final expected = IndicatorEngine(registry: registry).resolveAll(
        chart.value.data,
        chart.value.indicators.map((item) => item.config),
      );
      expect(chart.value.indicatorBatch.failures, isEmpty);
      for (final entry in expected.results.entries) {
        final actual = chart.value.indicatorBatch.results[entry.key]!;
        expect(actual.dataVersion, chart.value.data.version);
        for (final series in entry.value.series) {
          final values = actual.seriesById(series.id)!.values;
          expect(values.length, series.values.length);
          for (var i = 0; i < values.length; i++) {
            final value = series.values[i];
            expect(values[i], value == null ? isNull : closeTo(value, 1e-8));
          }
        }
      }
    }

    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: chart.session,
    );
    compare();
    chart.appendData(
      buildV2KlineFixture(1, startIndex: 100),
      session: chart.session,
    );
    compare();
    chart.prependHistory(candles.sublist(0, 10), session: chart.session);
    compare();
    chart.replaceData(candles.sublist(20), session: chart.session);
    compare();
  });

  test(
      'history loading and failure do not calculate; success advances results once',
      () async {
    final definition = _CountingDefinition();
    final responses = <Completer<KChartHistoryPage>>[];
    final chart = create(
      data: candles.sublist(10),
      bindings: [binding()],
      definitions: [definition],
      historyLoader: (_) {
        final response = Completer<KChartHistoryPage>();
        responses.add(response);
        return response.future;
      },
    );
    chart.attach(Object());
    final batch = chart.value.indicatorBatch;
    final first = chart.retryHistory();
    expect(chart.value.indicatorBatch, same(batch));
    responses.first.completeError(StateError('offline'));
    await first;
    expect(chart.value.indicatorBatch, same(batch));
    final second = chart.retryHistory();
    responses.last.complete(
      KChartHistoryPage(candles: candles.sublist(0, 10), hasMore: false),
    );
    await second;
    expect(definition.calls, 2);
    expect(chart.value.indicatorBatch.results['count']!.length, 100);
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
  });

  test('new series clears cache even when refreshing identical data', () {
    final definition = _CountingDefinition();
    final chart = create(bindings: [binding()], definitions: [definition]);
    final before = chart.value.indicatorBatch;
    chart.beginSeries(series, initialData: candles);
    expect(definition.calls, 2);
    expect(
      chart.value.indicatorBatch.results['count'],
      isNot(same(before.results['count'])),
    );
    final other = buildV2KlineFixture(20, symbol: 'ETHUSDT');
    chart.beginSeries(KlineSeries.fromKline(other.first), initialData: other);
    expect(chart.value.indicatorBatch.results['count']!.length, 20);
    expect(chart.value.indicators.single, binding());
  });

  test('chart caches are private and do not collide on equal version numbers',
      () {
    final first = create(
      bindings: [binding(definition: CciIndicatorDefinition.definitionId)],
    );
    final second = create(
      bindings: [binding(definition: CciIndicatorDefinition.definitionId)],
    );
    expect(first.value.data.version, second.value.data.version);
    expect(
      first.value.indicatorBatch.results['count'],
      isNot(same(second.value.indicatorBatch.results['count'])),
    );
    final before = second.value;
    first.setIndicators(const []);
    expect(second.value, same(before));
  });

  test('custom calculations cannot reenter mutating chart commands', () {
    final definition = _CountingDefinition();
    final chart = create(bindings: [binding()], definitions: [definition]);
    final owner = Object();
    chart.attach(owner);
    final commands = <void Function()>[
      () => chart.setIndicators(const []),
      () => chart.replaceData(const [], session: chart.session),
      () => chart.beginSeries(series),
      () => chart.setPanels(const ['main']),
      () => chart.setOptions(chart.value.options.copyWith(gridColumns: 3)),
      () => chart.setViewportSize(480),
      () => chart.setOverlays(session: chart.session),
      chart.scrollToLatest,
      chart.retryIndicators,
      () => chart.detach(owner),
      chart.dispose,
    ];
    for (var index = 0; index < commands.length; index++) {
      definition.duringCalculation = commands[index];
      chart.setIndicators([
        binding(parameters: {'factor': index + 2}),
      ]);
      expect(
        chart.value.indicatorBatch.failures['count']!.error,
        isA<StateError>(),
      );
      expect(chart.value.data.data, candles);
      expect(chart.value.isAttached, isTrue);
      expect(chart.isDisposed, isFalse);
      expect(chart.value.indicators, hasLength(1));
    }
    definition.duringCalculation = null;
    chart.retryIndicators();
    expect(chart.value.indicatorBatch.failures, isEmpty);
  });

  test(
      'listener can submit next config without observing mixed data and results',
      () {
    final definition = _CountingDefinition();
    final chart = create(bindings: [binding()], definitions: [definition]);
    var calls = 0;
    chart.addListener(() {
      calls++;
      final state = chart.value;
      expect(
        state.indicatorBatch.results['count']!.dataVersion,
        state.data.version,
      );
      if (calls == 1) {
        chart.setIndicators([
          binding(parameters: const {'factor': 2}),
        ]);
      }
    });
    chart.appendData(
      buildV2KlineFixture(1, startIndex: 100),
      session: chart.session,
    );
    expect(calls, 2);
    expect(
      chart.value.indicatorBatch.results['count']!.series.single.values.last,
      chart.value.data.data.last.close * 2,
    );
    chart.dispose();
    expect(() => chart.setIndicators(const []), throwsStateError);
    expect(chart.retryIndicators, throwsStateError);
  });
}

/// 仅统计真实引擎对扩展定义的调用；数据事务仍使用生产协调器，不替换实现。
final class _CountingDefinition implements IndicatorDefinition {
  int calls = 0;
  bool shouldThrow = false;
  void Function()? duringCalculation;

  @override
  String get id => 'test.count';

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.mainChart,
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: '测试值',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

  @override
  IndicatorResult calculate(VersionedKlineData input, IndicatorConfig config) {
    calls++;
    duringCalculation?.call();
    if (shouldThrow) throw StateError('Expected indicator failure');
    final factor = config.parameters['factor'] ?? 1;
    return IndicatorResult(
      instanceId: config.instanceId,
      definitionId: id,
      dataVersion: input.version,
      length: input.data.length,
      series: [
        IndicatorSeries(
          id: 'value',
          values: input.data.map((candle) => candle.close * factor),
        ),
      ],
    );
  }
}
