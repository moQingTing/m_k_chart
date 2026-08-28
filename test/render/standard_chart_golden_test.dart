import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  testWidgets('standard Layer visuals match the size/theme/panel matrix',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scenarios = <_GoldenScenario>[
      _GoldenScenario(
        name: 'wide_dark_candlestick',
        width: 360,
        height: 320,
        secondaryPanelIds: const ['volume', 'momentum'],
        mainMode: ChartMainMode.candlestick,
        theme: DefaultChartRenderStyle(),
      ),
      _GoldenScenario(
        name: 'compact_light_area',
        width: 240,
        height: 260,
        secondaryPanelIds: const ['volume'],
        mainMode: ChartMainMode.area,
        theme: _lightTheme(),
      ),
      _GoldenScenario(
        name: 'tall_dark_line',
        width: 300,
        height: 520,
        secondaryPanelIds: const ['volume', 'momentum', 'flow'],
        mainMode: ChartMainMode.line,
        theme: DefaultChartRenderStyle(),
      ),
      _GoldenScenario(
        name: 'wide_dark_hollow_candlestick',
        width: 360,
        height: 320,
        secondaryPanelIds: const ['volume', 'momentum'],
        mainMode: ChartMainMode.hollowCandlestick,
        theme: DefaultChartRenderStyle(),
      ),
      _GoldenScenario(
        name: 'compact_light_ohlc',
        width: 240,
        height: 260,
        secondaryPanelIds: const ['volume'],
        mainMode: ChartMainMode.ohlc,
        theme: _lightTheme(),
      ),
      _GoldenScenario(
        name: 'tall_dark_heikin_ashi',
        width: 300,
        height: 520,
        secondaryPanelIds: const ['volume', 'momentum', 'flow'],
        mainMode: ChartMainMode.heikinAshi,
        theme: DefaultChartRenderStyle(),
      ),
    ];

    for (final scenario in scenarios) {
      await tester.binding.setSurfaceSize(
        Size(scenario.width, scenario.height),
      );
      final pipeline = StandardChartRenderPipeline<DefaultChartRenderStyle>();
      addTearDown(pipeline.dispose);
      await tester.pumpWidget(
        _PipelineHost(
          paintKey: ValueKey('chart-${scenario.name}'),
          pipeline: pipeline,
          snapshot: _snapshot(
            width: scenario.width,
            height: scenario.height,
            secondaryPanelIds: scenario.secondaryPanelIds,
            mainMode: scenario.mainMode,
            theme: scenario.theme,
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(ValueKey('chart-${scenario.name}')),
        matchesGoldenFile('goldens/${scenario.name}.png'),
      );
    }
  });

  testWidgets('Widget frame reports retain all Layers for selection-only input',
      (tester) async {
    final reports = <RenderLayerFrameReport>[];
    final pipeline = StandardChartRenderPipeline<DefaultChartRenderStyle>();
    addTearDown(pipeline.dispose);
    final initial = _snapshot(
      width: 320,
      height: 300,
      secondaryPanelIds: const ['volume', 'momentum'],
    );

    await tester.pumpWidget(
      _PipelineHost(
        pipeline: pipeline,
        snapshot: initial,
        onReport: reports.add,
      ),
    );
    await tester.pump();
    expect(reports.single.repaintedLayerIds, _layerIds);

    final selection = _copySnapshot(
      initial,
      selection: RenderSelectionSnapshot.visible(localX: 180, localY: 90),
      versions: const RenderSnapshotVersions(selection: 1),
    );
    await tester.pumpWidget(
      _PipelineHost(
        pipeline: pipeline,
        snapshot: selection,
        onReport: reports.add,
      ),
    );
    await tester.pump();
    expect(reports.last.repaintedLayerIds, ['crosshair']);
    expect(pipeline.repaintStats.repaintCount('main'), 1);
    expect(pipeline.repaintStats.repaintCount('crosshair'), 2);

    final reportCount = reports.length;
    await tester.pumpWidget(
      _PipelineHost(
        pipeline: pipeline,
        snapshot: selection,
        onReport: reports.add,
      ),
    );
    await tester.pump();
    expect(reports, hasLength(reportCount));

    final viewport = _copySnapshot(
      selection,
      viewport: ChartViewport(
        itemCount: selection.data.data.length,
        width: selection.layout.drawingBounds.width,
        itemExtent: 9,
        scrollOffsetItems: 8,
      ),
      versions: const RenderSnapshotVersions(viewport: 1, selection: 1),
    );
    await tester.pumpWidget(
      _PipelineHost(
        pipeline: pipeline,
        snapshot: viewport,
        onReport: reports.add,
      ),
    );
    await tester.pump();
    expect(reports.last.repaintedLayerIds,
        ['main', 'secondary', 'axis', 'marker']);
    expect(pipeline.repaintStats.repaintCount('grid'), 1);
    expect(pipeline.repaintStats.repaintCount('main'), 2);
    expect(pipeline.repaintStats.repaintCount('crosshair'), 2);
  });
}

const _layerIds = [
  'grid',
  'main',
  'secondary',
  'axis',
  'marker',
  'drawing',
  'crosshair',
];

final class _GoldenScenario {
  const _GoldenScenario({
    required this.name,
    required this.width,
    required this.height,
    required this.secondaryPanelIds,
    required this.mainMode,
    required this.theme,
  });

  final String name;
  final double width;
  final double height;
  final List<String> secondaryPanelIds;
  final ChartMainMode mainMode;
  final DefaultChartRenderStyle theme;
}

final class _PipelineHost extends StatelessWidget {
  const _PipelineHost({
    super.key,
    required this.pipeline,
    required this.snapshot,
    this.paintKey,
    this.onReport,
  });

  final StandardChartRenderPipeline<DefaultChartRenderStyle> pipeline;
  final RenderSnapshot<DefaultChartRenderStyle> snapshot;
  final Key? paintKey;
  final ValueChanged<RenderLayerFrameReport>? onReport;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SizedBox(
          width: snapshot.layout.width,
          height: snapshot.layout.height,
          child: CustomPaint(
            key: paintKey,
            painter: _PipelinePainter(
              pipeline: pipeline,
              snapshot: snapshot,
              onReport: onReport,
            ),
          ),
        ),
      );
}

final class _PipelinePainter extends CustomPainter {
  _PipelinePainter({
    required this.pipeline,
    required this.snapshot,
    required this.onReport,
  });

  final StandardChartRenderPipeline<DefaultChartRenderStyle> pipeline;
  final RenderSnapshot<DefaultChartRenderStyle> snapshot;
  final ValueChanged<RenderLayerFrameReport>? onReport;

  @override
  void paint(Canvas canvas, Size size) {
    final report = pipeline.paint(
      RenderLayerContext(canvas: canvas, snapshot: snapshot),
    );
    onReport?.call(report);
  }

  @override
  bool shouldRepaint(covariant _PipelinePainter oldDelegate) =>
      oldDelegate.pipeline != pipeline ||
      oldDelegate.snapshot.data != snapshot.data ||
      oldDelegate.snapshot.viewport != snapshot.viewport ||
      oldDelegate.snapshot.layout != snapshot.layout ||
      oldDelegate.snapshot.theme != snapshot.theme ||
      oldDelegate.snapshot.selection.isVisible !=
          snapshot.selection.isVisible ||
      oldDelegate.snapshot.selection.localX != snapshot.selection.localX ||
      oldDelegate.snapshot.selection.localY != snapshot.selection.localY ||
      oldDelegate.snapshot.mainMode != snapshot.mainMode ||
      !_sameVersions(oldDelegate.snapshot.versions, snapshot.versions);
}

bool _sameVersions(
        RenderSnapshotVersions first, RenderSnapshotVersions second) =>
    first.data == second.data &&
    first.viewport == second.viewport &&
    first.selection == second.selection &&
    first.history == second.history &&
    first.layout == second.layout &&
    first.theme == second.theme &&
    first.clock == second.clock;

RenderSnapshot<DefaultChartRenderStyle> _snapshot({
  required double width,
  required double height,
  required List<String> secondaryPanelIds,
  ChartMainMode mainMode = ChartMainMode.candlestick,
  DefaultChartRenderStyle? theme,
}) {
  final data = _StableData(UnmodifiableListView(buildV2KlineFixture(64)));
  final layout = ChartLayoutModel(
    width: width,
    height: height,
    bottomAxisHeight: 24,
    panelSpacing: 4,
    gridColumns: 4,
    mainPanel: const ChartPanelSpec.main(minHeight: 120, gridRows: 4),
    secondaryPanels: [
      for (final id in secondaryPanelIds)
        ChartPanelSpec.secondary(id: id, minHeight: 52, gridRows: 2),
    ],
  );
  final viewport = ChartViewport(
    itemCount: data.data.length,
    width: layout.drawingBounds.width,
    itemExtent: 8,
    scrollOffsetItems: 8,
  );
  return RenderSnapshot(
    data: data,
    viewport: viewport,
    layout: layout,
    theme: theme ?? DefaultChartRenderStyle(),
    versions: const RenderSnapshotVersions(),
    indicators: _indicators(data, secondaryPanelIds),
    selection: RenderSelectionSnapshot.visible(
      localX: width * 0.55,
      localY: height * 0.26,
    ),
    mainMode: mainMode,
    currentTime: data.data.last.openTime + 44500,
  );
}

RenderSnapshot<DefaultChartRenderStyle> _copySnapshot(
  RenderSnapshot<DefaultChartRenderStyle> source, {
  ChartViewport? viewport,
  RenderSelectionSnapshot? selection,
  RenderSnapshotVersions? versions,
}) =>
    RenderSnapshot(
      data: source.data,
      viewport: viewport ?? source.viewport,
      layout: source.layout,
      theme: source.theme,
      versions: versions ?? source.versions,
      indicators: source.indicators,
      selection: selection ?? source.selection,
      history: source.history,
      drawings: source.drawings,
      mainMode: source.mainMode,
      currentTime: source.currentTime,
    );

List<RenderIndicatorSnapshot> _indicators(
  _StableData data,
  List<String> panelIds,
) {
  final output = <RenderIndicatorSnapshot>[
    _indicator(
      data: data,
      instanceId: 'ma.fast',
      panelId: 'main',
      placement: IndicatorPlacement.mainChart,
      series: [
        _series('line', data.data.map((item) => item.close - 0.35)),
      ],
      descriptorSeries: [
        _descriptor('line', IndicatorDrawingKind.line),
      ],
    ),
  ];
  for (var panelIndex = 0; panelIndex < panelIds.length; panelIndex++) {
    final panelId = panelIds[panelIndex];
    final isVolume = panelId == 'volume';
    output.add(
      _indicator(
        data: data,
        instanceId: panelId,
        panelId: panelId,
        placement: IndicatorPlacement.separatePanel,
        includeZero: true,
        series: [
          _series(
            'bars',
            List<double?>.generate(
              data.data.length,
              (index) => (index % 9 - 4) * (isVolume ? 110.0 : 1.5),
              growable: false,
            ),
          ),
          _series(
            'line',
            List<double?>.generate(
              data.data.length,
              (index) => math.sin((index + panelIndex) / 4) * 3,
              growable: false,
            ),
          ),
        ],
        descriptorSeries: [
          _descriptor(
            'bars',
            IndicatorDrawingKind.histogram,
            colorStrategy: isVolume
                ? IndicatorColorStrategy.candleDirection
                : IndicatorColorStrategy.valueSign,
            histogramStyle: isVolume
                ? IndicatorHistogramStyle.solid
                : IndicatorHistogramStyle.valueTrend,
          ),
          _descriptor('line', IndicatorDrawingKind.line),
        ],
      ),
    );
  }
  return output;
}

RenderIndicatorSnapshot _indicator({
  required _StableData data,
  required String instanceId,
  required String panelId,
  required IndicatorPlacement placement,
  required List<IndicatorSeries> series,
  required List<IndicatorSeriesDescriptor> descriptorSeries,
  bool includeZero = false,
}) =>
    RenderIndicatorSnapshot.fromResult(
      result: IndicatorResult(
        instanceId: instanceId,
        definitionId: 'golden.$instanceId',
        dataVersion: data.version,
        length: data.data.length,
        series: series,
      ),
      descriptor: IndicatorRendererDescriptor(
        placement: placement,
        includeZeroInRange: includeZero,
        series: descriptorSeries,
      ),
      panelId: panelId,
    );

IndicatorSeries _series(String id, Iterable<double?> values) =>
    IndicatorSeries(id: id, values: values);

IndicatorSeriesDescriptor _descriptor(
  String id,
  IndicatorDrawingKind drawingKind, {
  IndicatorColorStrategy colorStrategy = IndicatorColorStrategy.series,
  IndicatorHistogramStyle histogramStyle = IndicatorHistogramStyle.solid,
}) =>
    IndicatorSeriesDescriptor(
      id: id,
      label: id,
      drawingKind: drawingKind,
      colorStrategy: colorStrategy,
      histogramStyle: histogramStyle,
    );

DefaultChartRenderStyle _lightTheme() => DefaultChartRenderStyle(
      backgroundColor: const Color(0xfff8fafc),
      gridColor: const Color(0xffd9e0e8),
      axisTextColor: const Color(0xff52606d),
      upColor: const Color(0xff0a9f6e),
      downColor: const Color(0xffdd3c52),
      markerColor: const Color(0xffa96d00),
      crosshairColor: const Color(0xff536171),
      drawingColor: const Color(0xff6b54c6),
      mainLineColor: const Color(0xff007f8d),
      areaFillColors: const [Color(0x99007f8d), Color(0x1a007f8d)],
      indicatorPalette: const [
        Color(0xffa96d00),
        Color(0xff6b54c6),
        Color(0xff087f5b),
      ],
    );

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
