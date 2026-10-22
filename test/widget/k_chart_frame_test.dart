import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/k_chart_theme.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/controller/k_chart_indicator_binding.dart';
import 'package:m_k_chart/src/controller/k_chart_options.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render_layer.dart';
import 'package:m_k_chart/src/render/chart_layer_geometry.dart';
import 'package:m_k_chart/src/render/render_snapshot.dart';
import 'package:m_k_chart/src/render/standard_chart_layers.dart';
import 'package:m_k_chart/src/widget/k_chart_frame.dart';

import '../support/v2_kline_fixture.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_custom_indicator_example.dart';

void main() {
  final candles = buildV2KlineFixture(100);
  final theme = KChartTheme.light();
  KChartDataCoordinator create({
    KChartOptions? options,
    Iterable<IndicatorDefinition> definitions = const [],
  }) {
    final chart = KChartDataCoordinator(
      series: KlineSeries.fromKline(candles.first),
      initialData: candles,
      options: options,
      indicatorDefinitions: definitions,
    );
    chart.setViewportSize(480);
    addTearDown(chart.dispose);
    return chart;
  }

  KChartFrame frame(KChartDataCoordinator runtime, {int? time}) =>
      KChartFrame.project(
        runtime: runtime,
        size: const Size(480, 500),
        style: theme,
        versions: const RenderSnapshotVersions(),
        currentTime: time ?? candles.last.openTime + 10000,
      );

  test('18 个内置指标使用协调器结果；跨面板绑定只改变绘制归属', () {
    final registry = IndicatorRegistry();
    registerBuiltInIndicatorDefinitions(registry);
    final runtime = create(
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
        indicators: [
          for (final definition in registry.definitions.values)
            KChartIndicatorBinding(
              // 故意与定义默认位置相反，覆盖自由组合面板。
              panelId: definition.rendererDescriptor.placement ==
                      IndicatorPlacement.mainChart
                  ? 'sub'
                  : 'main',
              config: IndicatorConfig(
                instanceId: definition.id,
                definitionId: definition.id,
              ),
            ),
        ],
      ),
    );
    var notifications = 0;
    runtime.addListener(() => notifications++);
    final batch = runtime.value.indicatorBatch;
    final projected = frame(runtime);
    expect(projected.snapshot.indicators.length, 18);
    for (final indicator in projected.snapshot.indicators) {
      expect(indicator.dataVersion, runtime.value.data.version);
      expect(
        indicator.series.first,
        same(batch.results[indicator.instanceId]!.series.first),
      );
      expect(
        indicator.descriptor.placement,
        indicator.panelId == 'main'
            ? IndicatorPlacement.mainChart
            : IndicatorPlacement.separatePanel,
      );
    }
    // 实际跑完整绘制管线，不只检查快照可构造。
    final pipeline = StandardChartRenderPipeline();
    final recorder = PictureRecorder();
    pipeline.paint(
      RenderLayerContext(
        canvas: Canvas(recorder),
        snapshot: projected.snapshot,
      ),
    );
    recorder.endRecording().dispose();
    pipeline.dispose();
    expect(runtime.value.indicatorBatch, same(batch));
    expect(notifications, 0);
  });

  test('指标失败隔离，成功实例仍进入绘制快照', () {
    final runtime = create(
      options: KChartOptions(
        indicators: [
          KChartIndicatorBinding(
            panelId: 'main',
            config:
                IndicatorConfig(instanceId: 'ok', definitionId: 'legacy.ema'),
          ),
          KChartIndicatorBinding(
            panelId: 'main',
            config: IndicatorConfig(instanceId: 'bad', definitionId: 'missing'),
          ),
        ],
      ),
    );
    expect(runtime.value.indicatorBatch.failures.keys, ['bad']);
    expect(
      frame(runtime).snapshot.indicators.map((item) => item.instanceId),
      ['ok'],
    );
    expect(runtime.view.value.issues.single.instanceId, 'bad');
  });

  test('MA 仅投射三条线，参数图例按当前配置和定义元数据更新', () {
    final runtime = create(
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
        indicators: [
          KChartIndicatorBinding(
            panelId: 'main',
            config: IndicatorConfig(
              instanceId: 'ma',
              definitionId: 'legacy.ma',
              parameters: const {'period1': 7, 'period4': 44},
            ),
          ),
          KChartIndicatorBinding(
            panelId: 'sub',
            config: IndicatorConfig(
              instanceId: 'rsi',
              definitionId: 'legacy.rsi',
              parameters: const {'period': 6},
            ),
          ),
        ],
      ),
    );
    final projected = frame(runtime);
    expect(
      projected.snapshot.indicators
          .firstWhere((item) => item.instanceId == 'ma')
          .series
          .length,
      3,
    );
    final mainLabels = projected.legends['main']!.items
        .map((item) => item.text.toPlainText())
        .toList();
    expect(mainLabels.any((label) => label.startsWith('MA(7)')), isTrue);
    expect(mainLabels.any((label) => label.contains('44')), isFalse);
    expect(
      projected.legends['sub']!.items.single.text.toPlainText(),
      startsWith('RSI(6)'),
    );
  });

  test('自定义指标参数模板、同类多实例及 SUPER 单值图例均来自描述符', () {
    final runtime = create(
      definitions: const [V2TypicalPriceIndicator()],
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
        indicators: [
          for (final (id, scale) in [('first', 1), ('second', 2)])
            KChartIndicatorBinding(
              panelId: 'sub',
              config: IndicatorConfig(
                instanceId: id,
                definitionId: V2TypicalPriceIndicator.definitionId,
                parameters: {'scale': scale},
              ),
            ),
          KChartIndicatorBinding(
            panelId: 'main',
            config: IndicatorConfig(
              instanceId: 'super',
              definitionId: SuperTrendIndicatorDefinition.definitionId,
              parameters: const {'period': 7, 'multiplier': 2},
            ),
          ),
        ],
      ),
    );
    final projected = frame(runtime);
    expect(
      projected.legends['sub']!.items.map((item) => item.text.toPlainText()),
      [startsWith('典型价×1:'), startsWith('典型价×2:')],
    );
    expect(projected.legends['main']!.items, hasLength(1));
    expect(
      projected.legends['main']!.items.single.text.toPlainText(),
      startsWith('SUPERTREND(7,2) '),
    );
    expect(projected.legends['main']!.items.single.id, 'super:selected');
  });

  test('可见序列同时约束绘制、量程和图例，切换不重算指标', () {
    KChartIndicatorBinding binding({Set<String>? visible}) =>
        KChartIndicatorBinding(
          panelId: 'sub',
          config: IndicatorConfig(
            instanceId: 'two',
            definitionId: 'test.twoLine',
          ),
          visibleSeriesIds: visible,
        );
    final runtime = create(
      definitions: const [_TwoLineIndicator()],
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
        indicators: [binding()],
      ),
    );
    final batch = runtime.value.indicatorBatch;
    final all = frame(runtime);
    expect(
      ChartLayerGeometry.rangeFor(all.snapshot, 'sub').max,
      greaterThan(1000),
    );
    expect(all.legends['sub']!.items, hasLength(2));

    runtime.setOptions(
      runtime.value.options.copyWith(
        indicators: [
          binding(visible: {'low'}),
        ],
      ),
    );
    expect(runtime.value.indicatorBatch, same(batch));
    final filtered = frame(runtime);
    expect(filtered.snapshot.indicators.single.series.single.id, 'low');
    expect(
      filtered.snapshot.indicators.single.descriptor.series.single.id,
      'low',
    );
    expect(
      ChartLayerGeometry.rangeFor(filtered.snapshot, 'sub').max,
      lessThan(100),
    );
    expect(
      filtered.legends['sub']!.items.single.text.toPlainText(),
      startsWith('LOW:'),
    );
  });

  test('布局命中共用面板量程，实时更新后以同一时间身份重新投射', () {
    final runtime = create(
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
      ),
    );
    final initial = frame(runtime);
    expect(initial.hitTest(const Offset(150, 8)), isNull);
    expect(initial.hitTest(const Offset(150, 335)), isNull);
    final hit = initial.hitTest(const Offset(150, 450))!;
    runtime.select(
      openTime: hit.openTime,
      panelId: hit.panelId,
      price: hit.price,
    );
    final selected = frame(runtime);
    expect(selected.snapshot.selection.localY, closeTo(450, 0.0001));
    runtime.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: runtime.session,
    );
    final updated = frame(runtime);
    expect(updated.snapshot.selection.isVisible, isTrue);
    expect(
      updated.snapshot.selection.dataIndex,
      selected.snapshot.selection.dataIndex,
    );
    expect(updated.snapshot.selection.price, hit.price);
    // 旧帧仍保持旧数据，异步刷新不能在 paint 途中改变快照。
    expect(initial.snapshot.data.data.last.close, candles.last.close);
  });

  test('主图模式、时区、覆盖物和倒计时均来自同一帧输入', () {
    final runtime = create(
      options: KChartOptions(
        timeZoneOffset: const Duration(hours: 8),
        mainMode: ChartMainMode.line,
      ),
    );
    final line = ChartPriceLine(id: 'order', price: candles.last.close);
    runtime.setOverlays(session: runtime.session, priceLines: [line]);
    final batch = runtime.value.indicatorBatch;
    final first = frame(runtime);
    final second = frame(runtime, time: candles.last.openTime + 20000);
    expect(first.snapshot.latestPriceCountdownText, '00:50');
    expect(first.snapshot.mainMode, ChartMainMode.line);
    expect(second.snapshot.latestPriceCountdownText, '00:40');
    expect(first.snapshot.priceLines.single, same(line));
    expect(
      first.snapshot.formatAxisTime(candles.first.openTime),
      '2024-01-01 08:00',
    );
    expect(
      first.snapshot.formatCrosshairTime(candles.first),
      '2024-01-01 08:00',
    );
    expect(runtime.value.indicatorBatch, same(batch));
    runtime.beginSeries(runtime.session.series, initialData: [candles.last]);
    final single = frame(runtime);
    expect(single.snapshot.latestPriceCountdownText, '00:00');
    expect(single.snapshot.priceLines, isEmpty);
  });

  test('仅时钟快照允许浅复制；其他版本变化必须重新投射', () {
    final runtime = create();
    final first = frame(runtime);
    final second = first.withClock(
      currentTime: candles.last.openTime + 20000,
      versions: const RenderSnapshotVersions(clock: 1),
    );
    expect(second.snapshot.latestPriceCountdownText, '00:40');
    expect(second.snapshot.indicators, same(first.snapshot.indicators));
    expect(second.snapshot.layout, same(first.snapshot.layout));
    expect(second.legends, same(first.legends));
    expect(
      () => first.withClock(
        currentTime: candles.last.openTime + 20000,
        versions: const RenderSnapshotVersions(data: 1, clock: 1),
      ),
      throwsArgumentError,
    );
  });

  test('时间精度使用周期数值，支持自定义 code 与显示时区', () {
    final time = DateTime.utc(2024, 2, 3, 4, 5, 6).millisecondsSinceEpoch;
    String formatted(Duration duration) => formatKChartTime(
          time,
          KlineInterval.fixed(code: 'custom', duration: duration),
          const Duration(hours: 8),
        );
    expect(formatted(const Duration(seconds: 5)), '2024-02-03 12:05:06');
    expect(formatted(const Duration(minutes: 5)), '2024-02-03 12:05');
    expect(formatted(const Duration(hours: 4)), '2024-02-03 12:00');
    expect(formatted(const Duration(days: 7)), '2024-02-03');
    expect(
      formatKChartTime(
        time,
        KlineInterval.calendarMonth(code: 'custom'),
        Duration.zero,
      ),
      '2024-02',
    );
  });

  test('选中副图数值移出范围时仍夹在所属面板内，不丢失副图数值格式身份', () {
    final runtime = create(
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
      ),
    );
    runtime.scrollToTime(epochMilliseconds: candles.first.openTime);
    runtime.select(
      openTime: candles.last.openTime,
      panelId: 'sub',
      price: -999,
    );
    final projected = frame(runtime);
    final selection = projected.snapshot.selection;
    expect(
      projected.snapshot.layout.panel('sub').bounds.contains(
            x: selection.localX,
            y: selection.localY,
          ),
      isTrue,
    );
    expect(selection.price, -999);
  });
}

final class _TwoLineIndicator implements IndicatorDefinition {
  const _TwoLineIndicator();

  @override
  String get id => 'test.twoLine';

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.separatePanel,
        series: [
          IndicatorSeriesDescriptor(
            id: 'low',
            label: 'LOW',
            drawingKind: IndicatorDrawingKind.line,
          ),
          IndicatorSeriesDescriptor(
            id: 'high',
            label: 'HIGH',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

  @override
  IndicatorResult calculate(VersionedKlineData input, IndicatorConfig config) =>
      IndicatorResult(
        instanceId: config.instanceId,
        definitionId: id,
        dataVersion: input.version,
        length: input.data.length,
        series: [
          IndicatorSeries(
            id: 'low',
            values: List<double>.filled(input.data.length, 1),
          ),
          IndicatorSeries(
            id: 'high',
            values: List<double>.filled(input.data.length, 1000),
          ),
        ],
      );
}
