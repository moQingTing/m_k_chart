import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

const _runBenchmark = bool.fromEnvironment('RUN_KLINE_BENCHMARK');
const _hostP95BudgetMicroseconds = 10000.0;
const _retainedP95BudgetMicroseconds = 3000.0;

void main() {
  test(
    'records warm cached standard Layer stack host latency',
    () {
      final pipeline = StandardChartRenderPipeline<DefaultChartRenderStyle>();
      final snapshot = _snapshot();

      for (var index = 0; index < 20; index++) {
        _paintLayerStack(pipeline, snapshot);
      }
      final samples = <double>[];
      const iterations = 20;
      for (var sample = 0; sample < 100; sample++) {
        final stopwatch = Stopwatch()..start();
        for (var iteration = 0; iteration < iterations; iteration++) {
          _paintLayerStack(pipeline, snapshot);
        }
        stopwatch.stop();
        samples.add(stopwatch.elapsedMicroseconds / iterations);
      }
      samples.sort();
      final p50 = _percentile(samples, 0.50);
      final p95 = _percentile(samples, 0.95);
      final p99 = _percentile(samples, 0.99);

      expect(p95, lessThanOrEqualTo(_hostP95BudgetMicroseconds));
      for (final kind in RenderCacheKind.values) {
        expect(
          pipeline.cache.stats.hitCount(kind),
          greaterThan(0),
          reason: '$kind should be exercised by the warm Layer stack',
        );
      }
      // Host Debug is a regression signal, not a UI/Raster frame measurement.
      // ignore: avoid_print
      print(
        jsonEncode(<String, Object>{
          'metric': 'warm_standard_layer_stack',
          'p50_us': p50,
          'p95_us': p95,
          'p99_us': p99,
          'samples': samples.length,
          'data_points': snapshot.data.data.length,
          'secondary_panels': snapshot.layout.secondaryPanels.length,
          'mode': 'flutter_test_host_debug_cached_canvas_recording',
        }),
      );
      pipeline.dispose();
    },
    skip: !_runBenchmark,
  );

  test(
    'records retained unchanged and selection-only host latency',
    () {
      final pipeline = StandardChartRenderPipeline<DefaultChartRenderStyle>();
      final snapshot = _snapshot();
      _paintRetained(pipeline, snapshot);

      final unchanged = _measure(() => _paintRetained(pipeline, snapshot));
      var selectionVersion = 0;
      final selectionOnly = _measure(() {
        selectionVersion++;
        final report = _paintRetained(
          pipeline,
          _selectionSnapshot(snapshot, selectionVersion),
        );
        expect(report.repaintedLayerIds, ['crosshair']);
      });

      for (final entry in <String, _LatencyMetric>{
        'retained_unchanged_frame': unchanged,
        'retained_selection_only_frame': selectionOnly,
      }.entries) {
        expect(
          entry.value.p95,
          lessThanOrEqualTo(_retainedP95BudgetMicroseconds),
        );
        // ignore: avoid_print
        print(
          jsonEncode(<String, Object>{
            'metric': entry.key,
            'p50_us': entry.value.p50,
            'p95_us': entry.value.p95,
            'p99_us': entry.value.p99,
            'samples': entry.value.samples,
            'data_points': snapshot.data.data.length,
            'secondary_panels': snapshot.layout.secondaryPanels.length,
            'mode': 'flutter_test_host_debug_retained_layer_recording',
          }),
        );
      }
      expect(pipeline.repaintStats.repaintCount('grid'), 1);
      expect(pipeline.repaintStats.repaintCount('crosshair'), greaterThan(1));
      pipeline.dispose();
    },
    skip: !_runBenchmark,
  );
}

void _paintLayerStack(
  StandardChartRenderPipeline<DefaultChartRenderStyle> pipeline,
  RenderSnapshot<DefaultChartRenderStyle> snapshot,
) {
  final recorder = PictureRecorder();
  final context = RenderLayerContext(
    canvas: Canvas(recorder),
    snapshot: snapshot,
  );
  for (final layer in pipeline.layers.layers) {
    layer.paint(context);
  }
  recorder.endRecording().dispose();
}

RenderLayerFrameReport _paintRetained(
  StandardChartRenderPipeline<DefaultChartRenderStyle> pipeline,
  RenderSnapshot<DefaultChartRenderStyle> snapshot,
) {
  final recorder = PictureRecorder();
  final report = pipeline.paint(
    RenderLayerContext(
      canvas: Canvas(recorder),
      snapshot: snapshot,
    ),
  );
  recorder.endRecording().dispose();
  return report;
}

_LatencyMetric _measure(void Function() operation) {
  for (var index = 0; index < 20; index++) {
    operation();
  }
  final samples = <double>[];
  const iterations = 20;
  for (var sample = 0; sample < 100; sample++) {
    final stopwatch = Stopwatch()..start();
    for (var iteration = 0; iteration < iterations; iteration++) {
      operation();
    }
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / iterations);
  }
  samples.sort();
  return _LatencyMetric(
    p50: _percentile(samples, 0.50),
    p95: _percentile(samples, 0.95),
    p99: _percentile(samples, 0.99),
    samples: samples.length,
  );
}

RenderSnapshot<DefaultChartRenderStyle> _selectionSnapshot(
  RenderSnapshot<DefaultChartRenderStyle> source,
  int selectionVersion,
) =>
    RenderSnapshot(
      data: source.data,
      viewport: source.viewport,
      layout: source.layout,
      theme: source.theme,
      versions: RenderSnapshotVersions(selection: selectionVersion),
      indicators: source.indicators,
      selection: RenderSelectionSnapshot.visible(
        localX: 100 + selectionVersion % 100,
        localY: 200,
      ),
      history: source.history,
      drawings: source.drawings,
    );

double _percentile(List<double> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}

RenderSnapshot<DefaultChartRenderStyle> _snapshot() {
  const length = 2000;
  final data = _StableData(
    UnmodifiableListView([
      for (var index = 0; index < length; index++) _kline(index),
    ]),
  );
  final layout = ChartLayoutModel(
    width: 390,
    height: 600,
    bottomAxisHeight: 24,
    panelSpacing: 4,
    mainPanel: const ChartPanelSpec.main(minHeight: 220),
    secondaryPanels: const [
      ChartPanelSpec.secondary(id: 'volume', minHeight: 90),
      ChartPanelSpec.secondary(id: 'momentum', minHeight: 90),
    ],
  );
  final viewport = ChartViewport(
    itemCount: length,
    width: layout.drawingBounds.width,
    itemExtent: 8,
    scrollOffsetItems: 200,
  );
  return RenderSnapshot<DefaultChartRenderStyle>(
    data: data,
    viewport: viewport,
    layout: layout,
    theme: DefaultChartRenderStyle(),
    versions: const RenderSnapshotVersions(),
    indicators: [
      _indicator(
        data: data,
        instanceId: 'ma.fast',
        panelId: 'main',
        placement: IndicatorPlacement.mainChart,
        drawingKind: IndicatorDrawingKind.line,
      ),
      _indicator(
        data: data,
        instanceId: 'volume',
        panelId: 'volume',
        placement: IndicatorPlacement.separatePanel,
        drawingKind: IndicatorDrawingKind.histogram,
        includeZero: true,
      ),
      _indicator(
        data: data,
        instanceId: 'momentum',
        panelId: 'momentum',
        placement: IndicatorPlacement.separatePanel,
        drawingKind: IndicatorDrawingKind.line,
        includeZero: true,
      ),
    ],
  );
}

RenderIndicatorSnapshot _indicator({
  required _StableData data,
  required String instanceId,
  required String panelId,
  required IndicatorPlacement placement,
  required IndicatorDrawingKind drawingKind,
  bool includeZero = false,
}) =>
    RenderIndicatorSnapshot.fromResult(
      result: IndicatorResult(
        instanceId: instanceId,
        definitionId: instanceId,
        dataVersion: data.version,
        length: data.data.length,
        series: [
          IndicatorSeries(
            id: 'value',
            values: [
              for (var index = 0; index < data.data.length; index++)
                drawingKind == IndicatorDrawingKind.histogram
                    ? data.data[index].baseVolume
                    : data.data[index].close + (index % 11 - 5) * 0.2,
            ],
          ),
        ],
      ),
      descriptor: IndicatorRendererDescriptor(
        placement: placement,
        includeZeroInRange: includeZero,
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: instanceId,
            drawingKind: drawingKind,
          ),
        ],
      ),
      panelId: panelId,
    );

Kline _kline(int index) {
  final open = 10000.0 + index * 0.8;
  final close = open + (index.isEven ? 4 : -3);
  return Kline(
    symbol: 'BTCUSDT',
    interval: KlineInterval.oneMinute,
    openTime: 1704067200000 + index * 60000,
    closeTime: 1704067259999 + index * 60000,
    open: open,
    high: open + 7,
    low: open - 6,
    close: close,
    baseVolume: 100 + index % 40,
    quoteVolume: 1000000,
    tradeCount: 200,
    isClosed: true,
  );
}

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}

final class _LatencyMetric {
  const _LatencyMetric({
    required this.p50,
    required this.p95,
    required this.p99,
    required this.samples,
  });

  final double p50;
  final double p95;
  final double p99;
  final int samples;
}
