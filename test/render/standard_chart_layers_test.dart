import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  late ChartRenderCache cache;

  setUp(() => cache = ChartRenderCache());
  tearDown(() => cache.dispose());

  test('standard stack freezes deterministic independent Layer order', () {
    final stack = buildStandardChartLayerStack<DefaultChartRenderStyle>(cache);

    expect(
      stack.layers.map((layer) => layer.id),
      ['grid', 'main', 'secondary', 'axis', 'marker', 'drawing', 'crosshair'],
    );
    expect(
      stack.layer('crosshair').dependencies,
      {
        RenderSnapshotSlice.selection,
        RenderSnapshotSlice.layout,
        RenderSnapshotSlice.theme,
      },
    );
    expect(
      stack.layer('marker').dependencies,
      contains(RenderSnapshotSlice.clock),
    );
    expect(
      stack.layer('grid').dependencies,
      {
        RenderSnapshotSlice.data,
        RenderSnapshotSlice.viewport,
        RenderSnapshotSlice.layout,
        RenderSnapshotSlice.theme,
      },
    );
  });

  test('grid Layer paints background and deterministic layout lines', () async {
    final fixture = _fixture();
    final pixels = await _paint(
      fixture.snapshot,
      [ChartGridLayer<DefaultChartRenderStyle>(cache)],
    );

    expect(
      _pixel(pixels, fixture.width, 13, 13),
      fixture.style.backgroundColor,
    );
    expect(
      _hasColor(
        pixels,
        fixture.width,
        const Rect.fromLTWH(0, 0, 3, 220),
        fixture.style.gridColor,
        tolerance: 140,
      ),
      isTrue,
    );
    final main = fixture.layout.mainPanel;
    final timeAxis = fixture.layout.mainTimeAxisBounds;
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromCenter(
          center: Offset(
            fixture.layout.gridColumnXs[1],
            main.headerBounds.top + main.headerBounds.height / 2,
          ),
          width: 3,
          height: 3,
        ),
        fixture.style.gridColor,
        tolerance: 140,
      ),
      isTrue,
      reason: '主图指标参数区域应作为网格内的专用首行。',
    );
    expect(
      _pixel(
        pixels,
        fixture.width,
        fixture.layout.gridColumnXs[1].round(),
        (timeAxis.top + timeAxis.height / 2).round(),
      ),
      fixture.style.backgroundColor,
      reason: '主图时间区域不应绘制纵向网格。',
    );
  });

  test('grid Layer anchors vertical lines to data slots while panning',
      () async {
    final fixture = _fixture();
    final viewport = fixture.viewport.copyWith(
      itemExtent: 40,
      scrollOffsetItems: 1,
    );
    final pixels = await _paint(
      fixture.snapshotWithViewport(viewport),
      [ChartGridLayer<DefaultChartRenderStyle>(cache)],
    );
    final headerY = fixture.layout.mainPanel.headerBounds.top +
        fixture.layout.mainPanel.headerBounds.height / 2;

    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromCenter(
          center: Offset(140, headerY),
          width: 3,
          height: 3,
        ),
        fixture.style.gridColor,
        tolerance: 140,
      ),
      isTrue,
      reason: '数据槽位锚定的网格应随 viewport 平移到新的 X 坐标。',
    );
    expect(
      _pixel(pixels, fixture.width, 120, headerY.round()),
      fixture.style.backgroundColor,
      reason: '旧的固定布局列不能在平移后继续保留。',
    );
  });

  test('grid Layer can omit secondary internal horizontal lines', () async {
    final fixture = _fixture(secondaryHorizontalGrid: false);
    final pixels = await _paint(
      fixture.snapshot,
      [ChartGridLayer<DefaultChartRenderStyle>(cache)],
    );
    final secondary = fixture.layout.panel('volume');

    expect(
      _pixel(
        pixels,
        fixture.width,
        90,
        (secondary.bounds.top + secondary.bounds.height / 2).round(),
      ),
      fixture.style.backgroundColor,
      reason: '副图关闭横向网格后，内容区域不应绘制水平分隔线。',
    );
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromCenter(
          center: Offset(90, secondary.gridBounds.top),
          width: 3,
          height: 3,
        ),
        fixture.style.gridColor,
        tolerance: 140,
      ),
      isTrue,
      reason: '副图关闭内部横线后仍应保留上边界。',
    );
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromCenter(
          center: Offset(90, secondary.gridBounds.bottom),
          width: 3,
          height: 3,
        ),
        fixture.style.gridColor,
        tolerance: 140,
      ),
      isTrue,
      reason: '副图关闭内部横线后仍应保留下边界。',
    );
  });

  test('main Layer paints both rising and falling candle bodies', () async {
    final fixture = _fixture();
    final pixels = await _paint(
      fixture.snapshot,
      [ChartMainLayer<DefaultChartRenderStyle>(cache)],
    );
    final main = fixture.layout.mainPanel.bounds;

    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromLTRB(main.left, main.top, main.right, main.bottom),
        fixture.style.upColor,
      ),
      isTrue,
    );
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromLTRB(main.left, main.top, main.right, main.bottom),
        fixture.style.downColor,
      ),
      isTrue,
    );
  });

  test('data layers keep reserved legend rows clear', () async {
    final fixture = _fixture();
    final pixels = await _paint(
      fixture.snapshot,
      [
        ChartMainLayer<DefaultChartRenderStyle>(cache),
        ChartSecondaryLayer<DefaultChartRenderStyle>(cache),
      ],
    );

    for (final panel in fixture.layout.panels) {
      final header = panel.headerBounds;
      expect(
        _nonTransparentCount(
          pixels,
          fixture.width,
          Rect.fromLTRB(header.left, header.top, header.right, header.bottom),
        ),
        0,
        reason: '${panel.spec.id} 参数行不得被 K 线或指标数据覆盖。',
      );
    }
  });

  test('main Layer renders distinct candle, line and area modes', () async {
    final fixture = _fixture();
    final layer = ChartMainLayer<DefaultChartRenderStyle>(cache);
    final line = await _paint(
      fixture.snapshotWithMode(ChartMainMode.line),
      [layer],
    );
    final area = await _paint(
      fixture.snapshotWithMode(ChartMainMode.area),
      [layer],
    );
    final solid = await _paint(
      fixture.snapshotWithMode(ChartMainMode.candlestick),
      [layer],
    );
    final hollow = await _paint(
      fixture.snapshotWithMode(ChartMainMode.hollowCandlestick),
      [layer],
    );
    final ohlc = await _paint(
      fixture.snapshotWithMode(ChartMainMode.ohlc),
      [layer],
    );
    final heikinAshi = await _paint(
      fixture.snapshotWithMode(ChartMainMode.heikinAshi),
      [layer],
    );
    final main = fixture.layout.mainPanel.bounds;
    final region = Rect.fromLTRB(
      main.left,
      main.top,
      main.right,
      main.bottom,
    );

    expect(
      _hasColor(line, fixture.width, region, fixture.style.mainLineColor),
      isTrue,
    );
    expect(
      _hasColor(line, fixture.width, region, fixture.style.upColor),
      isFalse,
    );
    expect(
      _hasColor(line, fixture.width, region, fixture.style.downColor),
      isFalse,
    );
    expect(
      _hasColor(area, fixture.width, region, fixture.style.mainLineColor),
      isTrue,
    );
    expect(
      _nonTransparentCount(area, fixture.width, region),
      greaterThan(_nonTransparentCount(line, fixture.width, region) * 4),
    );
    expect(_pixelDifferenceCount(hollow, solid), greaterThan(0));
    expect(_pixelDifferenceCount(ohlc, solid), greaterThan(0));
    expect(
      _pixelDifferenceCount(heikinAshi, solid),
      greaterThan(0),
    );
  });

  test('secondary Layer renders line histogram and point descriptors',
      () async {
    final fixture = _fixture();
    final pixels = await _paint(
      fixture.snapshot,
      [ChartSecondaryLayer<DefaultChartRenderStyle>(cache)],
    );
    final panel = fixture.layout.panel('volume').bounds;
    final panelRect = Rect.fromLTRB(
      panel.left,
      panel.top,
      panel.right,
      panel.bottom,
    );
    final indicatorColor = fixture.style.indicatorColor('oscillator', 'line');

    expect(
      _hasColor(
        pixels,
        fixture.width,
        panelRect,
        indicatorColor,
      ),
      isTrue,
    );
    expect(
      _nonTransparentCount(
        pixels,
        fixture.width,
        panelRect,
      ),
      greaterThan(40),
    );
    expect(
      _hasColor(pixels, fixture.width, panelRect, fixture.style.upColor),
      isTrue,
    );
    expect(
      _hasColor(pixels, fixture.width, panelRect, fixture.style.downColor),
      isTrue,
    );
  });

  test('axis Layer paints price labels and time labels in their regions',
      () async {
    final fixture = _fixture();
    final pixels = await _paint(
      fixture.snapshot,
      [ChartAxisLayer<DefaultChartRenderStyle>(cache)],
    );

    expect(
      _nonTransparentCount(
        pixels,
        fixture.width,
        Rect.fromLTWH(120, 0, 60, fixture.layout.drawingBounds.height),
      ),
      greaterThan(0),
    );
    expect(
      _nonTransparentCount(
        pixels,
        fixture.width,
        Rect.fromLTRB(
          0,
          fixture.layout.timeAxisBounds.top,
          fixture.layout.width,
          fixture.layout.height,
        ),
      ),
      greaterThan(0),
    );
  });

  test('main and secondary panels route values to separate formatters',
      () async {
    final mainValues = <double>[];
    final secondaryValues = <double>[];
    final fixture = _fixture(
      mainValueFormatter: (value, _) {
        mainValues.add(value);
        return 'M';
      },
      secondaryValueFormatter: (value, _) {
        secondaryValues.add(value);
        return 'S';
      },
    );

    await _paint(
      fixture.snapshot,
      [
        ChartAxisLayer<DefaultChartRenderStyle>(cache),
        ChartMarkerLayer<DefaultChartRenderStyle>(cache),
      ],
    );

    expect(mainValues, isNotEmpty);
    expect(secondaryValues, isNotEmpty);
    expect(mainValues, contains(fixture.data.data.last.close));

    mainValues.clear();
    secondaryValues.clear();
    final secondaryPanel = fixture.layout.panel('volume').bounds;
    await _paint(
      fixture.snapshotWithSelection(
        RenderSelectionSnapshot.visible(
          localX: (secondaryPanel.left + secondaryPanel.right) / 2,
          localY: (secondaryPanel.top + secondaryPanel.bottom) / 2,
          dataIndex: 2,
          price: 1234.567,
          valueKind: RenderSelectionValueKind.close,
        ),
      ),
      [ChartCrosshairLayer<DefaultChartRenderStyle>(cache)],
    );

    expect(mainValues, isEmpty);
    expect(secondaryValues, contains(1234.567));
  });

  test('marker, drawing and crosshair Layers paint isolated overlay colors',
      () async {
    final fixture = _fixture();
    final layers = <ChartRenderLayer<DefaultChartRenderStyle>>[
      ChartMarkerLayer<DefaultChartRenderStyle>(cache),
      ChartDrawingLayer<DefaultChartRenderStyle>(),
      ChartCrosshairLayer<DefaultChartRenderStyle>(cache),
    ];
    final pixels = await _paint(fixture.snapshot, layers);
    final bounds = fixture.layout.drawingBounds;

    for (final color in <Color>[
      fixture.style.markerColor,
      fixture.style.drawingColor,
      fixture.style.crosshairColor,
    ]) {
      expect(
        _hasColor(
          pixels,
          fixture.width,
          Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom),
          color,
          tolerance: 80,
        ),
        isTrue,
        reason: 'Missing overlay color $color',
      );
    }
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromLTRB(
          fixture.layout.mainTimeAxisBounds.left,
          fixture.layout.mainTimeAxisBounds.top,
          fixture.layout.mainTimeAxisBounds.right,
          fixture.layout.mainTimeAxisBounds.bottom,
        ),
        fixture.style.crosshairLabelTextColor,
      ),
      isTrue,
      reason: '十字光标的时间标签必须绘制在主图与副图之间的时间区域。',
    );
  });

  test('marker keeps the latest-price label when latest candle is hidden',
      () async {
    final fixture = _fixture();
    final hiddenLatestViewport = fixture.viewport.copyWith(
      itemExtent: 40,
      scrollOffsetItems: double.maxFinite,
    );
    final pixels = await _paint(
      fixture.snapshotWithViewport(hiddenLatestViewport),
      [ChartMarkerLayer<DefaultChartRenderStyle>(cache)],
    );
    final main = fixture.layout.mainPanel.bounds;
    final hitRegion = latestPriceMarkerHitRegionFor(
      fixture.snapshotWithViewport(hiddenLatestViewport),
      cache,
    )!;

    expect(hiddenLatestViewport.visibleRange.contains(5), isFalse);
    expect(hitRegion.showsChevron, isTrue);
    expect(hitRegion.contains(hitRegion.bounds.center), isTrue);
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromLTRB(main.left, main.top, main.right, main.bottom),
        fixture.style.axisTextColor,
      ),
      isTrue,
      reason: '最新 K 线滑出右侧后仍绘制实时价虚线和双行价格标签。',
    );
  });

  test('visible latest price uses a bordered two-line label', () async {
    final fixture = _fixture();
    final paddedViewport = fixture.viewport.copyWith(
      trailingPaddingItems: 2,
    );
    final pixels = await _paint(
      fixture.snapshotWithViewport(paddedViewport),
      [ChartMarkerLayer<DefaultChartRenderStyle>(cache)],
    );
    final main = fixture.layout.mainPanel.bounds;
    final spaciousViewport = paddedViewport.copyWith(
      futurePaddingItems: 5,
      scrollOffsetItems: -5,
    );
    final hitRegion = latestPriceMarkerHitRegionFor(
      fixture.snapshotWithViewport(spaciousViewport),
      cache,
    )!;

    expect(hitRegion.showsChevron, isFalse);
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromLTRB(main.width * 0.65, main.top, main.right, main.bottom),
        fixture.style.backgroundColor,
      ),
      isTrue,
    );
    expect(
      _hasColor(
        pixels,
        fixture.width,
        Rect.fromLTRB(main.width * 0.65, main.top, main.right, main.bottom),
        fixture.style.axisTextColor,
        tolerance: 80,
      ),
      isTrue,
    );
  });

  test('hidden or out-of-bounds crosshair produces no Canvas output', () async {
    final fixture = _fixture();
    final layer = ChartCrosshairLayer<DefaultChartRenderStyle>(cache);
    final hidden = await _paint(fixture.snapshotWithSelection(), [layer]);
    final outside = await _paint(
      fixture.snapshotWithSelection(
        RenderSelectionSnapshot.visible(localX: -1, localY: -1),
      ),
      [layer],
    );

    expect(_nonTransparentCount(hidden, fixture.width, fixture.fullRect), 0);
    expect(_nonTransparentCount(outside, fixture.width, fixture.fullRect), 0);
  });

  test('drawing projection validates identity, coordinates and immutability',
      () {
    final source = <RenderLineDrawing>[
      RenderLineDrawing(
        id: 'line',
        start: Offset.zero,
        end: const Offset(10, 10),
      ),
    ];
    final fixture = _fixture();
    final snapshot = fixture.snapshotWithDrawings(source);
    source.clear();

    expect(snapshot.drawings, hasLength(1));
    expect(snapshot.drawing('line'), same(snapshot.drawings.first));
    expect(() => snapshot.drawings.clear(), throwsUnsupportedError);
    expect(
      () => RenderLineDrawing(
        id: '',
        start: Offset.zero,
        end: const Offset(1, 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => fixture.snapshotWithDrawings([
        snapshot.drawings.first,
        RenderLineDrawing(
          id: 'line',
          start: Offset.zero,
          end: const Offset(2, 2),
        ),
      ]),
      throwsArgumentError,
    );
  });
}

Future<ByteData> _paint(
  RenderSnapshot<DefaultChartRenderStyle> snapshot,
  Iterable<ChartRenderLayer<DefaultChartRenderStyle>> layers,
) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final context = RenderLayerContext(canvas: canvas, snapshot: snapshot);
  for (final layer in layers) {
    layer.paint(context);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    snapshot.layout.width.ceil(),
    snapshot.layout.height.ceil(),
  );
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return bytes!;
}

int _pixelDifferenceCount(ByteData first, ByteData second) {
  expect(first.lengthInBytes, second.lengthInBytes);
  var count = 0;
  for (var index = 0; index < first.lengthInBytes; index++) {
    if (first.getUint8(index) != second.getUint8(index)) {
      count++;
    }
  }
  return count;
}

Color _pixel(ByteData pixels, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return Color.fromARGB(
    pixels.getUint8(offset + 3),
    pixels.getUint8(offset),
    pixels.getUint8(offset + 1),
    pixels.getUint8(offset + 2),
  );
}

bool _hasColor(
  ByteData pixels,
  int width,
  Rect region,
  Color target, {
  int tolerance = 20,
}) {
  final targetArgb = target.toARGB32();
  final targetR = (targetArgb >> 16) & 0xff;
  final targetG = (targetArgb >> 8) & 0xff;
  final targetB = targetArgb & 0xff;
  for (var y = region.top.floor(); y < region.bottom.ceil(); y++) {
    for (var x = region.left.floor(); x < region.right.ceil(); x++) {
      final color = _pixel(pixels, width, x, y).toARGB32();
      final red = (color >> 16) & 0xff;
      final green = (color >> 8) & 0xff;
      final blue = color & 0xff;
      if ((red - targetR).abs() <= tolerance &&
          (green - targetG).abs() <= tolerance &&
          (blue - targetB).abs() <= tolerance &&
          ((color >> 24) & 0xff) > 0) {
        return true;
      }
    }
  }
  return false;
}

int _nonTransparentCount(
  ByteData pixels,
  int width,
  Rect region,
) {
  var count = 0;
  for (var y = region.top.floor(); y < region.bottom.ceil(); y++) {
    for (var x = region.left.floor(); x < region.right.ceil(); x++) {
      if ((_pixel(pixels, width, x, y).toARGB32() >> 24) & 0xff > 0) {
        count++;
      }
    }
  }
  return count;
}

_Fixture _fixture({
  String Function(double value, int decimalPlaces)? mainValueFormatter,
  String Function(double value, int decimalPlaces)? secondaryValueFormatter,
  bool secondaryHorizontalGrid = true,
}) {
  final data = _StableData(
    UnmodifiableListView([
      _kline(0, 100, 104, 98, 103),
      _kline(1, 103, 105, 99, 100),
      _kline(2, 100, 106, 99, 105),
      _kline(3, 105, 107, 101, 102),
      _kline(4, 102, 108, 101, 107),
      _kline(5, 107, 109, 103, 104),
    ]),
  );
  final layout = ChartLayoutModel(
    width: 180,
    height: 240,
    bottomAxisHeight: 20,
    mainTimeAxisHeight: 12,
    gridColumns: 3,
    mainPanel: const ChartPanelSpec.main(
      weight: 2,
      minHeight: 100,
      headerHeight: 10,
      gridRows: 2,
    ),
    secondaryPanels: [
      ChartPanelSpec.secondary(
        id: 'volume',
        minHeight: 60,
        headerHeight: 10,
        gridRows: 2,
        showHorizontalGrid: secondaryHorizontalGrid,
      ),
    ],
  );
  final viewport = ChartViewport(
    itemCount: data.data.length,
    width: layout.drawingBounds.width,
    itemExtent: 30,
    minItemExtent: 4,
    maxItemExtent: 40,
  );
  final main = RenderIndicatorSnapshot.fromResult(
    result: IndicatorResult(
      instanceId: 'ma.fast',
      definitionId: 'ma',
      dataVersion: data.version,
      length: data.data.length,
      series: [
        IndicatorSeries(
          id: 'line',
          values: const [101, 102, 103, 104, 105, 106],
        ),
      ],
    ),
    descriptor: IndicatorRendererDescriptor(
      placement: IndicatorPlacement.mainChart,
      series: [
        IndicatorSeriesDescriptor(
          id: 'line',
          label: 'MA',
          drawingKind: IndicatorDrawingKind.line,
        ),
      ],
    ),
    panelId: 'main',
  );
  final secondary = RenderIndicatorSnapshot.fromResult(
    result: IndicatorResult(
      instanceId: 'oscillator',
      definitionId: 'test',
      dataVersion: data.version,
      length: data.data.length,
      series: [
        IndicatorSeries(id: 'line', values: const [-2, -1, 0, 1, 2, 1]),
        IndicatorSeries(id: 'bars', values: const [1, -1, 2, -2, 1, -1]),
        IndicatorSeries(id: 'dots', values: const [0, 1, 0, -1, 0, 1]),
      ],
    ),
    descriptor: IndicatorRendererDescriptor(
      placement: IndicatorPlacement.separatePanel,
      includeZeroInRange: true,
      series: [
        IndicatorSeriesDescriptor(
          id: 'line',
          label: 'Line',
          drawingKind: IndicatorDrawingKind.line,
        ),
        IndicatorSeriesDescriptor(
          id: 'bars',
          label: 'Bars',
          drawingKind: IndicatorDrawingKind.histogram,
          colorStrategy: IndicatorColorStrategy.valueSign,
          histogramStyle: IndicatorHistogramStyle.valueTrend,
        ),
        IndicatorSeriesDescriptor(
          id: 'dots',
          label: 'Dots',
          drawingKind: IndicatorDrawingKind.points,
        ),
      ],
    ),
    panelId: 'volume',
  );
  final style = DefaultChartRenderStyle(
    backgroundColor: const Color(0xff010203),
    gridColor: const Color(0xff2030e0),
    upColor: const Color(0xff00ee44),
    downColor: const Color(0xffee2244),
    markerColor: const Color(0xffffdd00),
    crosshairColor: const Color(0xffeeeeee),
    drawingColor: const Color(0xffff00dd),
    indicatorPalette: const [Color(0xff00ddff)],
    mainValueFormatter: mainValueFormatter,
    secondaryValueFormatter: secondaryValueFormatter,
  );
  return _Fixture(data, layout, viewport, style, [main, secondary]);
}

Kline _kline(
  int index,
  double open,
  double high,
  double low,
  double close,
) =>
    Kline(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      openTime: 1704067200000 + index * 60000,
      closeTime: 1704067259999 + index * 60000,
      open: open,
      high: high,
      low: low,
      close: close,
      baseVolume: 10,
      quoteVolume: 1000,
      tradeCount: 20,
      isClosed: true,
    );

final class _Fixture {
  const _Fixture(
    this.data,
    this.layout,
    this.viewport,
    this.style,
    this.indicators,
  );

  final _StableData data;
  final ChartLayoutModel layout;
  final ChartViewport viewport;
  final DefaultChartRenderStyle style;
  final List<RenderIndicatorSnapshot> indicators;

  int get width => layout.width.ceil();
  Rect get fullRect => Rect.fromLTWH(0, 0, layout.width, layout.height);

  RenderSnapshot<DefaultChartRenderStyle> get snapshot => _snapshot(
        selection: RenderSelectionSnapshot.visible(
          localX: 90,
          localY: 80,
          dataIndex: 2,
          price: 105,
          valueKind: RenderSelectionValueKind.close,
        ),
        drawings: [
          RenderLineDrawing(
            id: 'trend',
            start: const Offset(10, 10),
            end: const Offset(170, 210),
          ),
        ],
      );

  RenderSnapshot<DefaultChartRenderStyle> snapshotWithSelection([
    RenderSelectionSnapshot selection = const RenderSelectionSnapshot.hidden(),
  ]) =>
      _snapshot(selection: selection);

  RenderSnapshot<DefaultChartRenderStyle> snapshotWithDrawings(
    Iterable<RenderLineDrawing> drawings,
  ) =>
      _snapshot(drawings: drawings);

  RenderSnapshot<DefaultChartRenderStyle> snapshotWithMode(
    ChartMainMode mainMode,
  ) =>
      _snapshot(mainMode: mainMode);

  RenderSnapshot<DefaultChartRenderStyle> snapshotWithViewport(
    ChartViewport viewport,
  ) =>
      _snapshot(viewport: viewport);

  RenderSnapshot<DefaultChartRenderStyle> _snapshot({
    RenderSelectionSnapshot selection = const RenderSelectionSnapshot.hidden(),
    Iterable<RenderLineDrawing> drawings = const [],
    ChartMainMode mainMode = ChartMainMode.candlestick,
    ChartViewport? viewport,
  }) =>
      RenderSnapshot<DefaultChartRenderStyle>(
        data: data,
        viewport: viewport ?? this.viewport,
        layout: layout,
        theme: style,
        versions: const RenderSnapshotVersions(),
        indicators: indicators,
        selection: selection,
        drawings: drawings,
        mainMode: mainMode,
      );
}

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
