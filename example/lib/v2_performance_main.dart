import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() => runApp(const _V2ProfileApp());

class _V2ProfileApp extends StatelessWidget {
  const _V2ProfileApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Colors.black, body: _V2ProfileChart()),
      );
}

class _V2ProfileChart extends StatefulWidget {
  const _V2ProfileChart();

  @override
  State<_V2ProfileChart> createState() => _V2ProfileChartState();
}

class _V2ProfileChartState extends State<_V2ProfileChart>
    with SingleTickerProviderStateMixin {
  late final _StableData _data;
  late final ChartLayoutModel _layout;
  late final DefaultChartRenderStyle _theme;
  late final List<RenderIndicatorSnapshot> _indicators;
  late final StandardChartRenderPipeline<DefaultChartRenderStyle> _pipeline;
  late final AnimationController _ticker;
  var _frame = 0;
  var _selectionVersion = 0;
  var _viewportVersion = 0;

  @override
  void initState() {
    super.initState();
    _data = _StableData(UnmodifiableListView(_buildData(2000)));
    _layout = ChartLayoutModel(
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
    _theme = DefaultChartRenderStyle();
    _indicators = _buildIndicators(_data);
    _pipeline = StandardChartRenderPipeline();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_advance);
    WidgetsBinding.instance.addTimingsCallback(_reportTimings);
    _ticker.repeat();
  }

  void _advance() {
    _frame++;
    if (_frame.isEven) {
      _selectionVersion++;
    } else {
      _viewportVersion++;
    }
    setState(() {});
  }

  void _reportTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    final build = timings
        .map((item) => item.buildDuration.inMicroseconds)
        .toList()
      ..sort();
    final raster = timings
        .map((item) => item.rasterDuration.inMicroseconds)
        .toList()
      ..sort();
    // ignore: avoid_print
    print(jsonEncode({
      'metric': 'v2_profile_frame_timing_batch',
      'samples': timings.length,
      'build_p95_us': _p95(build),
      'raster_p95_us': _p95(raster),
      'data_points': _data.data.length,
      'secondary_panels': 2,
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_reportTimings);
    _ticker.dispose();
    _pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: _layout.width,
          height: _layout.height,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ProfilePainter(
                pipeline: _pipeline,
                snapshot: _snapshot(),
              ),
            ),
          ),
        ),
      );

  RenderSnapshot<DefaultChartRenderStyle> _snapshot() {
    final viewport = ChartViewport(
      itemCount: _data.data.length,
      width: _layout.drawingBounds.width,
      itemExtent: 8,
      scrollOffsetItems: 200 + (_viewportVersion % 40),
    );
    return RenderSnapshot(
      data: _data,
      viewport: viewport,
      layout: _layout,
      theme: _theme,
      versions: RenderSnapshotVersions(
        viewport: _viewportVersion,
        selection: _selectionVersion,
      ),
      indicators: _indicators,
      selection: RenderSelectionSnapshot.visible(
        localX: 80 + _selectionVersion % 220,
        localY: 200,
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter({required this.pipeline, required this.snapshot});
  final StandardChartRenderPipeline<DefaultChartRenderStyle> pipeline;
  final RenderSnapshot<DefaultChartRenderStyle> snapshot;

  @override
  void paint(Canvas canvas, Size size) => pipeline.paint(
        RenderLayerContext(canvas: canvas, snapshot: snapshot),
      );

  @override
  bool shouldRepaint(covariant _ProfilePainter oldDelegate) => true;
}

List<RenderIndicatorSnapshot> _buildIndicators(_StableData data) => [
      _indicator(data, 'ma', 'main', IndicatorPlacement.mainChart, false),
      _indicator(
          data, 'volume', 'volume', IndicatorPlacement.separatePanel, true),
      _indicator(
          data, 'momentum', 'momentum', IndicatorPlacement.separatePanel, true),
    ];

RenderIndicatorSnapshot _indicator(
  _StableData data,
  String id,
  String panelId,
  IndicatorPlacement placement,
  bool histogram,
) =>
    RenderIndicatorSnapshot.fromResult(
      result: IndicatorResult(
        instanceId: id,
        definitionId: id,
        dataVersion: data.version,
        length: data.data.length,
        series: [
          IndicatorSeries(
            id: 'value',
            values: [
              for (var index = 0; index < data.data.length; index++)
                histogram
                    ? data.data[index].baseVolume
                    : data.data[index].close + (index % 11 - 5) * .2,
            ],
          ),
        ],
      ),
      descriptor: IndicatorRendererDescriptor(
        placement: placement,
        includeZeroInRange: histogram,
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: id,
            drawingKind: histogram
                ? IndicatorDrawingKind.histogram
                : IndicatorDrawingKind.line,
          ),
        ],
      ),
      panelId: panelId,
    );

List<Kline> _buildData(int count) => List.generate(count, (index) {
      final open = 1000 + index * .37 + (index % 23 - 11) * .41;
      final close = open + (index % 7 - 3) * .29;
      final openTime = 1704067200000 + index * 60000;
      return Kline(
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        openTime: openTime,
        closeTime: openTime + 59999,
        open: open,
        close: close,
        high: open > close ? open + 1.2 : close + 1.2,
        low: open < close ? open - 1.2 : close - 1.2,
        baseVolume: 800 + index % 17 * 53,
        quoteVolume: 1000,
        tradeCount: 20,
        isClosed: true,
      );
    });

int _p95(List<int> sorted) => sorted[((sorted.length - 1) * .95).ceil()];

class _StableData implements VersionedKlineData {
  const _StableData(this.data);
  @override
  final List<Kline> data;
  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
