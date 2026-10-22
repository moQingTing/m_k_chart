import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/k_chart_theme.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/controller/k_chart_indicator_binding.dart';
import 'package:m_k_chart/src/controller/k_chart_options.dart';
import 'package:m_k_chart/src/indicator/indicator_config.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render_layer.dart';
import 'package:m_k_chart/src/render/render_repaint.dart';
import 'package:m_k_chart/src/render/render_snapshot.dart';
import 'package:m_k_chart/src/render/standard_chart_layers.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/widget/k_chart_frame.dart';
import 'package:m_k_chart/src/widget/k_chart_render_versions.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(100);
  final style = KChartTheme.light();
  const size = Size(480, 500);
  final startTime = candles.last.openTime + 10000;

  KChartDataCoordinator create({KChartOptions? options}) {
    final runtime = KChartDataCoordinator(
      series: KlineSeries.fromKline(candles.first),
      initialData: candles,
      options: options,
    );
    runtime.setViewportSize(size.width);
    addTearDown(runtime.dispose);
    return runtime;
  }

  test('倒计时只推进 clock，复用网格、K 线与坐标轴图层', () {
    final runtime = create();
    final tracker = KChartRenderVersionTracker();
    final pipeline = StandardChartRenderPipeline<ChartRenderStyle>();
    addTearDown(pipeline.dispose);

    RenderLayerFrameReport paint(int time) {
      final versions = tracker.advance(
        state: runtime.value,
        size: size,
        style: style,
        textScaler: TextScaler.noScaling,
        currentTime: time,
      );
      final frame = KChartFrame.project(
        runtime: runtime,
        size: size,
        style: style,
        versions: versions,
        currentTime: time,
      );
      final recorder = PictureRecorder();
      final report = pipeline.paint(
        RenderLayerContext(
          canvas: Canvas(recorder),
          snapshot: frame.snapshot,
        ),
      );
      recorder.endRecording().dispose();
      return report;
    }

    expect(paint(startTime).repaintedLayerIds, isNotEmpty);
    final before = pipeline.repaintStats;
    final tick = paint(startTime + 1000);
    expect(tick.repaintedLayerIds, ['marker']);
    expect(tick.reusedLayerIds, containsAll(['grid', 'main', 'axis']));
    expect(
      pipeline.repaintStats.repaintCount('grid'),
      before.repaintCount('grid'),
    );
    expect(
      pipeline.repaintStats.repaintCount('main'),
      before.repaintCount('main'),
    );
    expect(
      pipeline.repaintStats.repaintCount('axis'),
      before.repaintCount('axis'),
    );

    runtime.select(
      openTime: candles.last.openTime,
      panelId: 'main',
      price: candles.last.close,
    );
    final selected = paint(startTime + 1000);
    expect(selected.repaintedLayerIds, ['crosshair']);
    expect(selected.reusedLayerIds, containsAll(['grid', 'main', 'axis']));

    runtime.updateKline(
      candles.last.copyWith(close: candles.last.close + 1),
      session: runtime.session,
    );
    final update = paint(startTime + 1000);
    expect(
      update.repaintedLayerIds,
      containsAll(['grid', 'main', 'crosshair']),
    );
    expect(
      tracker
          .advance(
            state: runtime.value,
            size: size,
            style: style,
            textScaler: TextScaler.noScaling,
            currentTime: startTime + 1000,
          )
          .clock,
      1,
    );
  });

  test('布局、主题和覆盖物各自推进版本，同一输入不重复推进', () {
    final runtime = create();
    final tracker = KChartRenderVersionTracker();
    RenderSnapshotVersions next({
      Size frameSize = size,
      KChartTheme? frameStyle,
      TextScaler scaler = TextScaler.noScaling,
    }) =>
        tracker.advance(
          state: runtime.value,
          size: frameSize,
          style: frameStyle ?? style,
          textScaler: scaler,
          currentTime: startTime,
        );

    expect(next().data, 0);
    expect(next().layout, 0);
    expect(next().layout, 0);
    expect(next(frameSize: const Size(480, 520)).layout, 1);
    expect(next(frameSize: const Size(480, 520)).layout, 1);
    expect(
      next(
        frameSize: const Size(480, 520),
        scaler: const TextScaler.linear(1.2),
      ).layout,
      2,
    );
    final changedStyle = KChartTheme.light(upColor: const Color(0xff123456));
    final themed = next(
      frameSize: const Size(480, 520),
      scaler: const TextScaler.linear(1.2),
      frameStyle: changedStyle,
    );
    expect(themed.theme, 1);
    expect(themed.data, 0);
    expect(themed.layout, 2);
    runtime.setOverlays(
      session: runtime.session,
      priceLines: [ChartPriceLine(id: 'order', price: candles.last.close)],
    );
    final overlay = next(
      frameSize: const Size(480, 520),
      scaler: const TextScaler.linear(1.2),
      frameStyle: changedStyle,
    );
    expect(overlay.overlays, 1);
    expect(overlay.drawings, 0);
    expect(overlay.data, 0);
  });

  test('仅切换可见曲线推进视觉布局，不伪装成数据变化', () {
    KChartIndicatorBinding ema({Set<String>? visible}) =>
        KChartIndicatorBinding(
          panelId: 'main',
          config:
              IndicatorConfig(instanceId: 'ema', definitionId: 'legacy.ema'),
          visibleSeriesIds: visible,
        );
    final runtime = create(options: KChartOptions(indicators: [ema()]));
    final tracker = KChartRenderVersionTracker();
    RenderSnapshotVersions next() => tracker.advance(
          state: runtime.value,
          size: size,
          style: style,
          textScaler: TextScaler.noScaling,
          currentTime: startTime,
        );

    expect(next().layout, 0);
    final batch = runtime.value.indicatorBatch;
    runtime.setOptions(
      runtime.value.options.copyWith(
        indicators: [
          ema(visible: {'ema5'}),
        ],
      ),
    );
    expect(runtime.value.indicatorBatch, same(batch));
    final changed = next();
    expect(changed.layout, 1);
    expect(changed.data, 0);
    expect(next().layout, 1);
  });
}
