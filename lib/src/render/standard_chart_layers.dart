import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/painting.dart';

import '../indicator/indicator.dart';
import '../model/chart_overlay.dart';
import '../theme/theme.dart';
import '../viewport/viewport.dart';
import 'chart_candle_projection.dart';
import 'chart_drawing_renderer.dart';
import 'chart_main_mode.dart';
import 'render_cache.dart';
import 'render_layer.dart';
import 'render_repaint.dart';
import 'render_snapshot.dart';

/// Hit-test geometry for the latest-price label painted by the marker layer.
final class ChartLatestPriceMarkerHitRegion {
  const ChartLatestPriceMarkerHitRegion({
    required this.bounds,
    required this.showsChevron,
  });

  final Rect bounds;
  final bool showsChevron;

  bool contains(Offset position) => bounds.contains(position);
}

/// Resolves the exact label bounds used by [ChartMarkerLayer].
///
/// A host can use the returned chevron region as a "return to latest" target
/// without duplicating marker measurement or positioning rules.
ChartLatestPriceMarkerHitRegion?
    latestPriceMarkerHitRegionFor<TTheme extends ChartRenderStyle>(
  RenderSnapshot<TTheme> snapshot,
  ChartRenderCache cache,
) {
  if (snapshot.data.data.isEmpty) return null;
  final layout = _latestPriceLayoutForSnapshot(snapshot, cache);
  return ChartLatestPriceMarkerHitRegion(
    bounds: layout.labelBounds,
    showsChevron: layout.showChevron,
  );
}

final class ChartGridLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartGridLayer(this.cache)
      : super(
          id: 'grid',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.viewport,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    final window = cache.windowFor(snapshot);
    final picture = cache.picture(
      (
        'grid',
        snapshot.data.version,
        snapshot.versions.data,
        snapshot.versions.viewport,
        snapshot.versions.layout,
        snapshot.versions.theme,
        snapshot.layout,
        snapshot.viewport,
      ),
      () => _recordGridPicture(snapshot, window),
    );
    context.canvas.drawPicture(picture);
  }
}

final class ChartMainLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartMainLayer(this.cache)
      : super(
          id: 'main',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.viewport,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    if (snapshot.data.data.isEmpty) {
      return;
    }
    final panel = snapshot.layout.mainPanel;
    final priceTransform = cache
        .panelRangeFor(
          snapshot,
          panel.spec.id,
        )
        .transform(panel.bounds);
    final window = cache.windowFor(snapshot);
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRect(_rect(panel.bounds));
    switch (snapshot.mainMode) {
      case ChartMainMode.candlestick:
      case ChartMainMode.hollowCandlestick:
      case ChartMainMode.ohlc:
      case ChartMainMode.heikinAshi:
        _drawIndicators(
          canvas: canvas,
          snapshot: snapshot,
          panelId: panel.spec.id,
          bounds: panel.bounds,
          window: window,
          valueTransform: priceTransform,
          cache: cache,
          pass: _IndicatorPaintPass.area,
        );
        _drawCandles(
          canvas: canvas,
          snapshot: snapshot,
          window: window,
          priceTransform: priceTransform,
          candles: cache.candlesFor(snapshot),
        );
        _drawIndicators(
          canvas: canvas,
          snapshot: snapshot,
          panelId: panel.spec.id,
          bounds: panel.bounds,
          window: window,
          valueTransform: priceTransform,
          cache: cache,
          pass: _IndicatorPaintPass.series,
        );
      case ChartMainMode.line:
        _drawMainPriceSeries(
          canvas: canvas,
          snapshot: snapshot,
          panel: panel.bounds,
          window: window,
          priceTransform: priceTransform,
          cache: cache,
          fillArea: false,
        );
      case ChartMainMode.area:
        _drawMainPriceSeries(
          canvas: canvas,
          snapshot: snapshot,
          panel: panel.bounds,
          window: window,
          priceTransform: priceTransform,
          cache: cache,
          fillArea: true,
        );
    }
    canvas.restore();
  }
}

final class ChartSecondaryLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartSecondaryLayer(this.cache)
      : super(
          id: 'secondary',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.viewport,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    if (snapshot.data.data.isEmpty) {
      return;
    }
    final window = cache.windowFor(snapshot);
    for (final panel in snapshot.layout.secondaryPanels) {
      final valueTransform = cache
          .panelRangeFor(
            snapshot,
            panel.spec.id,
          )
          .transform(panel.bounds);
      context.canvas.save();
      context.canvas.clipRect(_rect(panel.bounds));
      _drawIndicators(
        canvas: context.canvas,
        snapshot: snapshot,
        panelId: panel.spec.id,
        bounds: panel.bounds,
        window: window,
        valueTransform: valueTransform,
        cache: cache,
        pass: _IndicatorPaintPass.series,
      );
      context.canvas.restore();
    }
  }
}

final class ChartAxisLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartAxisLayer(this.cache)
      : super(
          id: 'axis',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.viewport,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
            RenderSnapshotSlice.locale,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    final layout = snapshot.layout;
    final theme = snapshot.theme;
    for (final panel in layout.panels) {
      final range = cache.panelRangeFor(snapshot, panel.spec.id);
      final rows = layout.gridRowYsFor(panel.spec.id);
      for (var index = 0; index < rows.length; index++) {
        final ratio = index / (rows.length - 1);
        final value = range.max - (range.max - range.min) * ratio;
        _drawText(
          canvas: context.canvas,
          text: panel.spec.kind == ChartPanelKind.main
              ? theme.formatMainValue(value)
              : theme.formatSecondaryValue(value),
          color: theme.axisTextColor,
          fontSize: theme.axisFontSize,
          x: panel.bounds.right - 3,
          y: rows[index],
          horizontalAnchor: 1,
          verticalAnchor: index == 0
              ? 0
              : index == rows.length - 1
                  ? 1
                  : 0.5,
          cache: cache,
        );
      }
    }
    if (snapshot.data.data.isEmpty || layout.timeAxisBounds.height <= 0) {
      return;
    }
    final xTransform = cache.windowFor(snapshot).xTransform;
    final gridColumnXs = _scrollingGridColumnXs(snapshot, xTransform);
    for (final x in gridColumnXs) {
      final time = xTransform.localXToTime(x - layout.drawingBounds.left);
      _drawText(
        canvas: context.canvas,
        text: snapshot.formatAxisTime(time),
        color: theme.axisTextColor,
        fontSize: theme.axisFontSize,
        x: x,
        y: layout.timeAxisBounds.top + 2,
        horizontalAnchor: x <= layout.drawingBounds.left
            ? 0
            : x >= layout.drawingBounds.right
                ? 1
                : 0.5,
        cache: cache,
      );
    }
  }
}

final class ChartMarkerLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartMarkerLayer(this.cache)
      : super(
          id: 'marker',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.viewport,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
            RenderSnapshotSlice.clock,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    if (snapshot.data.data.isEmpty) return;
    final window = cache.windowFor(snapshot);
    final panel = snapshot.layout.mainPanel;
    final transform = cache
        .panelRangeFor(
          snapshot,
          panel.spec.id,
        )
        .transform(panel.bounds);
    final xTransform = window.xTransform;
    final midpoint = (panel.bounds.left + panel.bounds.right) / 2;
    final paint = Paint()
      ..color = snapshot.theme.markerColor
      ..strokeWidth = snapshot.theme.overlayStrokeWidth
      ..style = PaintingStyle.stroke;
    final extrema = cache.extremaFor(snapshot);
    if (extrema != null) {
      for (final point in <(int, double, String)>[
        (extrema.maxIndex, extrema.max, 'H'),
        (extrema.minIndex, extrema.min, 'L'),
      ]) {
        final x = xTransform.indexToLocalX(point.$1);
        final y = transform.priceToLocalY(point.$2);
        context.canvas.drawCircle(
          Offset(x, y),
          3,
          paint,
        );
        _drawText(
          canvas: context.canvas,
          text: '${point.$3} ${snapshot.theme.formatMainValue(point.$2)}',
          color: snapshot.theme.markerColor,
          fontSize: snapshot.theme.axisFontSize,
          x: x < midpoint ? x + 5 : x - 5,
          y: y,
          horizontalAnchor: x < midpoint ? 0 : 1,
          verticalAnchor: 0.5,
          cache: cache,
        );
      }
    }

    _drawLatestPrice(
      canvas: context.canvas,
      layout: _latestPriceLayoutForSnapshot(snapshot, cache),
      theme: snapshot.theme,
    );
  }
}

final class ChartCrosshairLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartCrosshairLayer(this.cache)
      : super(
          id: 'crosshair',
          dependencies: const {
            RenderSnapshotSlice.selection,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
            RenderSnapshotSlice.locale,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final selection = context.snapshot.selection;
    if (!selection.isVisible) {
      return;
    }
    final layout = context.snapshot.layout;
    final bounds = layout.drawingBounds;
    if (!bounds.contains(x: selection.localX, y: selection.localY)) {
      return;
    }
    ChartPanelLayout? selectedPanel;
    for (final panel in layout.panels) {
      if (panel.bounds.contains(
        x: selection.localX,
        y: selection.localY,
      )) {
        selectedPanel = panel;
        break;
      }
    }
    final paint = Paint()
      ..color = context.snapshot.theme.crosshairColor
      ..strokeWidth = context.snapshot.theme.overlayStrokeWidth
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
      canvas: context.canvas,
      start: Offset(selection.localX, bounds.top),
      end: Offset(selection.localX, bounds.bottom),
      paint: paint,
      dashLength: context.snapshot.theme.crosshairDashLength,
      dashGap: context.snapshot.theme.crosshairDashGap,
    );
    final horizontalBounds = selectedPanel?.bounds;
    _drawDashedLine(
      canvas: context.canvas,
      start: Offset(horizontalBounds?.left ?? bounds.left, selection.localY),
      end: Offset(horizontalBounds?.right ?? bounds.right, selection.localY),
      paint: paint,
      dashLength: context.snapshot.theme.crosshairDashLength,
      dashGap: context.snapshot.theme.crosshairDashGap,
    );
    context.canvas.drawCircle(
      Offset(selection.localX, selection.localY),
      context.snapshot.theme.crosshairPointRadius,
      Paint()
        ..color = context.snapshot.theme.crosshairColor
        ..style = PaintingStyle.fill,
    );
    if (selection.price != null) {
      final labelBounds = selectedPanel?.bounds ?? bounds;
      _drawCrosshairLabel(
        canvas: context.canvas,
        text: selectedPanel?.spec.kind == ChartPanelKind.secondary
            ? context.snapshot.theme.formatSecondaryValue(selection.price!)
            : context.snapshot.theme.formatMainValue(selection.price!),
        bounds: labelBounds,
        fontSize: context.snapshot.theme.axisFontSize,
        x: labelBounds.right,
        y: selection.localY,
        horizontalAnchor: 1,
        verticalAnchor: 0.5,
        cache: cache,
        theme: context.snapshot.theme,
      );
    }
    final selectedIndex = selection.dataIndex;
    if (selectedIndex == null ||
        selectedIndex >= context.snapshot.data.data.length) {
      return;
    }
    final timeBounds = layout.mainTimeAxisBounds.height > 0
        ? layout.mainTimeAxisBounds
        : layout.timeAxisBounds;
    if (timeBounds.height <= 0) return;
    final candle = context.snapshot.data.data[selectedIndex];
    _drawCrosshairLabel(
      canvas: context.canvas,
      text: context.snapshot.formatCrosshairTime(candle),
      bounds: timeBounds,
      fontSize: context.snapshot.theme.axisFontSize,
      x: selection.localX,
      y: timeBounds.top + timeBounds.height / 2,
      horizontalAnchor: 0.5,
      verticalAnchor: 0.5,
      cache: cache,
      theme: context.snapshot.theme,
    );
  }
}

/// Paints host-supplied trading references without invalidating chart data.
final class ChartTradeOverlayLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartTradeOverlayLayer(this.cache)
      : super(
          id: 'tradeOverlay',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.viewport,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
            RenderSnapshotSlice.overlays,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    if (snapshot.data.data.isEmpty ||
        (snapshot.priceLines.isEmpty &&
            snapshot.eventOverlays.isEmpty &&
            snapshot.valueMarkers.isEmpty)) {
      return;
    }
    final panel = snapshot.layout.mainPanel;
    final priceTransform =
        cache.panelRangeFor(snapshot, panel.spec.id).transform(panel.bounds);
    final window = cache.windowFor(snapshot);
    final xTransform = window.xTransform;
    final panelMidY = (panel.bounds.top + panel.bounds.bottom) / 2;
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRect(_rect(panel.bounds));

    for (final line in snapshot.priceLines) {
      if (!line.visible) continue;
      final color = _tradeOverlayColor(snapshot.theme, line.side);
      final y = priceTransform.priceToLocalY(line.price);
      canvas.drawLine(
        Offset(panel.bounds.left, y),
        Offset(panel.bounds.right, y),
        Paint()
          ..color = color
          ..strokeWidth = snapshot.theme.overlayStrokeWidth
          ..style = PaintingStyle.stroke,
      );
      _drawText(
        canvas: canvas,
        text: line.label == null
            ? snapshot.theme.formatMainValue(line.price)
            : '${line.label} ${snapshot.theme.formatMainValue(line.price)}',
        color: color,
        fontSize: snapshot.theme.axisFontSize,
        x: panel.bounds.right - 3,
        y: y,
        horizontalAnchor: 1,
        verticalAnchor: y < panelMidY ? 0 : 1,
        cache: cache,
      );
    }

    for (final marker in snapshot.valueMarkers) {
      final color = _tradeOverlayColor(snapshot.theme, marker.side);
      final y = priceTransform.priceToLocalY(marker.price);
      final center = Offset(panel.bounds.right - 6, y);
      canvas.drawCircle(center, 3, Paint()..color = color);
      _drawText(
        canvas: canvas,
        text: marker.text,
        color: color,
        fontSize: snapshot.theme.axisFontSize,
        x: center.dx - 5,
        y: y,
        horizontalAnchor: 1,
        verticalAnchor: 0.5,
        cache: cache,
      );
    }

    for (final event in snapshot.eventOverlays) {
      if (window.range.isEmpty) continue;
      final firstVisibleTime = snapshot.data.data[window.range.start].openTime;
      final lastVisibleTime = snapshot.data.data[window.range.end - 1].openTime;
      if (event.epochMilliseconds < firstVisibleTime ||
          event.epochMilliseconds > lastVisibleTime) {
        continue;
      }
      final x = xTransform.timeToLocalX(event.epochMilliseconds) +
          snapshot.layout.drawingBounds.left;
      if (x < panel.bounds.left || x > panel.bounds.right) continue;
      final y = priceTransform.priceToLocalY(event.price);
      final color = _tradeOverlayColor(snapshot.theme, event.side);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
      if (event.label != null) {
        _drawText(
          canvas: canvas,
          text: event.label!,
          color: color,
          fontSize: snapshot.theme.axisFontSize,
          x: x,
          y: y < panelMidY ? y + 5 : y - 5,
          horizontalAnchor: 0.5,
          verticalAnchor: y < panelMidY ? 0 : 1,
          cache: cache,
        );
      }
    }
    canvas.restore();
  }
}

Color _tradeOverlayColor(
  ChartRenderStyle theme,
  ChartOverlaySide side,
) =>
    switch (side) {
      ChartOverlaySide.buy => theme.upColor,
      ChartOverlaySide.sell => theme.downColor,
      ChartOverlaySide.neutral => theme.markerColor,
    };

/// Paints legacy local lines and P7 time/price-anchored drawing tools.
final class ChartDrawingLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartDrawingLayer(this.cache)
      : super(
          id: 'drawing',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.viewport,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
            RenderSnapshotSlice.drawings,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    if (context.snapshot.drawings.isEmpty &&
        context.snapshot.anchoredDrawings.isEmpty) {
      return;
    }
    final canvas = context.canvas;
    final bounds = context.snapshot.layout.drawingBounds;
    canvas.save();
    canvas.clipRect(_rect(bounds));
    final paint = Paint()
      ..color = context.snapshot.theme.drawingColor
      ..strokeWidth = context.snapshot.theme.overlayStrokeWidth
      ..style = PaintingStyle.stroke;
    for (final drawing in context.snapshot.drawings) {
      canvas.drawLine(drawing.start, drawing.end, paint);
    }
    if (context.snapshot.data.data.isNotEmpty) {
      final xTransform = cache.windowFor(context.snapshot).xTransform;
      final panel = context.snapshot.layout.mainPanel;
      final priceTransform = cache
          .panelRangeFor(context.snapshot, panel.spec.id)
          .transform(panel.bounds);
      for (final drawing in context.snapshot.anchoredDrawings) {
        ChartDrawingRenderer.paintAnchored(
          canvas: canvas,
          drawing: drawing,
          xTransform: xTransform,
          priceTransform: priceTransform,
          bounds: _rect(bounds),
          color: context.snapshot.theme.drawingColor,
          formatPrice: context.snapshot.theme.formatMainValue,
          textFontSize: context.snapshot.theme.axisFontSize,
        );
      }
    }
    canvas.restore();
  }
}

RenderLayerStack<TTheme>
    buildStandardChartLayerStack<TTheme extends ChartRenderStyle>(
  ChartRenderCache cache,
) =>
        RenderLayerStack<TTheme>([
          ChartGridLayer<TTheme>(cache),
          ChartMainLayer<TTheme>(cache),
          ChartSecondaryLayer<TTheme>(cache),
          ChartAxisLayer<TTheme>(cache),
          ChartMarkerLayer<TTheme>(cache),
          ChartTradeOverlayLayer<TTheme>(cache),
          ChartDrawingLayer<TTheme>(cache),
          ChartCrosshairLayer<TTheme>(cache),
        ]);

final class StandardChartRenderPipeline<TTheme extends ChartRenderStyle> {
  /// Creates a complete standard pipeline and takes ownership of [cache].
  ///
  /// Supplying a cache is intended for capacity tuning and diagnostics. The
  /// caller must not reuse it after this pipeline has been disposed.
  StandardChartRenderPipeline({ChartRenderCache? cache})
      : cache = cache ?? ChartRenderCache() {
    layers = buildStandardChartLayerStack<TTheme>(this.cache);
    compositor = RetainedRenderLayerCompositor(layers);
  }

  final ChartRenderCache cache;
  late final RenderLayerStack<TTheme> layers;
  late final RetainedRenderLayerCompositor<TTheme> compositor;

  RenderLayerRepaintStats get repaintStats => compositor.stats;

  RenderLayerFrameReport paint(RenderLayerContext<TTheme> context) =>
      compositor.paint(context);

  void clearRetainedLayers() => compositor.clear();

  void dispose() {
    compositor.dispose();
    cache.dispose();
  }
}

Picture _recordGridPicture<TTheme extends ChartRenderStyle>(
  RenderSnapshot<TTheme> snapshot,
  ChartVisibleWindow window,
) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final layout = snapshot.layout;
  final theme = snapshot.theme;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, layout.width, layout.height),
    Paint()..color = theme.backgroundColor,
  );
  final paint = Paint()
    ..color = theme.gridColor
    ..strokeWidth = theme.gridStrokeWidth
    ..style = PaintingStyle.stroke;
  final gridColumnXs = _scrollingGridColumnXs(snapshot, window.xTransform);
  for (final panel in layout.panels) {
    final gridBounds = panel.gridBounds;
    for (final x in gridColumnXs) {
      canvas.drawLine(
        Offset(x, gridBounds.top),
        Offset(x, gridBounds.bottom),
        paint,
      );
    }
    if (panel.spec.showHorizontalGrid) {
      if (panel.headerBounds.height > 0) {
        canvas.drawLine(
          Offset(gridBounds.left, gridBounds.top),
          Offset(gridBounds.right, gridBounds.top),
          paint,
        );
      }
      for (final y in layout.gridRowYsFor(panel.spec.id)) {
        canvas.drawLine(
          Offset(panel.bounds.left, y),
          Offset(panel.bounds.right, y),
          paint,
        );
      }
    } else {
      canvas.drawLine(
        Offset(gridBounds.left, gridBounds.top),
        Offset(gridBounds.right, gridBounds.top),
        paint,
      );
      canvas.drawLine(
        Offset(gridBounds.left, gridBounds.bottom),
        Offset(gridBounds.right, gridBounds.bottom),
        paint,
      );
    }
  }
  return recorder.endRecording();
}

/// Resolves vertical grid lines from globally anchored data slots.
///
/// The horizontal row grid remains panel-relative because its price range is
/// recomputed for every viewport. Vertical lines, however, must share the X
/// transform with candles and indicators so a pan or zoom moves the grid with
/// the chart instead of leaving a stationary window behind.
List<double> _scrollingGridColumnXs<TTheme extends Object>(
  RenderSnapshot<TTheme> snapshot,
  ChartXTransform xTransform,
) {
  if (snapshot.data.data.isEmpty) {
    return snapshot.layout.gridColumnXs;
  }
  final layout = snapshot.layout;
  final viewport = snapshot.viewport;
  final stepItems = math.max(
    1,
    (viewport.visibleItemCapacity / layout.gridColumns).round(),
  );
  final firstAnchor =
      (viewport.visibleLeftDataPosition / stepItems).floor() * stepItems;
  final result = <double>[];
  for (var dataPosition = firstAnchor;
      dataPosition <= viewport.visibleRightDataPosition + stepItems;
      dataPosition += stepItems) {
    final x = xTransform.dataPositionToLocalX(dataPosition.toDouble()) +
        layout.drawingBounds.left;
    if (x >= layout.drawingBounds.left && x <= layout.drawingBounds.right) {
      result.add(x);
    }
  }
  return result;
}

Path _buildLinePath({
  required IndicatorSeries series,
  required VisibleIndexRange visible,
  required ChartXTransform xTransform,
  required ChartPriceTransform valueTransform,
  required IndicatorLineStyle lineStyle,
}) {
  final path = Path();
  var active = false;
  double? previousY;
  for (var index = visible.start; index < visible.end; index++) {
    final value = series.values[index];
    if (value == null) {
      active = false;
      continue;
    }
    final x = xTransform.indexToLocalX(index);
    final y = valueTransform.priceToLocalY(value);
    if (active && lineStyle == IndicatorLineStyle.stepped) {
      path.lineTo(x, previousY!);
      path.lineTo(x, y);
    } else if (active) {
      path.lineTo(x, y);
    } else {
      path.moveTo(x, y);
      active = true;
    }
    previousY = y;
  }
  return path;
}

/// Builds independently closed areas between an indicator line and the
/// matching candle closes. Null values deliberately end a run; this is what
/// prevents a Supertrend reversal from filling diagonally across its two legs.
Path _buildIndicatorAreaPath<TTheme extends ChartRenderStyle>({
  required RenderSnapshot<TTheme> snapshot,
  required IndicatorSeries series,
  required VisibleIndexRange visible,
  required ChartXTransform xTransform,
  required ChartPriceTransform valueTransform,
  required IndicatorLineStyle lineStyle,
}) {
  final path = Path();
  var start = -1;

  void closeRun(int end) {
    if (start < 0 || start >= end) return;
    final firstValue = series.values[start]!;
    final firstX = xTransform.indexToLocalX(start);
    var previousY = valueTransform.priceToLocalY(firstValue);
    path.moveTo(firstX, previousY);
    for (var index = start + 1; index < end; index++) {
      final x = xTransform.indexToLocalX(index);
      final y = valueTransform.priceToLocalY(series.values[index]!);
      if (lineStyle == IndicatorLineStyle.stepped) {
        path.lineTo(x, previousY);
      }
      path.lineTo(x, y);
      previousY = y;
    }
    for (var index = end - 1; index >= start; index--) {
      path.lineTo(
        xTransform.indexToLocalX(index),
        valueTransform.priceToLocalY(snapshot.data.data[index].close),
      );
    }
    path.close();
  }

  for (var index = visible.start; index < visible.end; index++) {
    if (series.values[index] != null) {
      start = start < 0 ? index : start;
    } else {
      closeRun(index);
      start = -1;
    }
  }
  closeRun(visible.end);
  return path;
}

Path _buildMainPricePath<TTheme extends Object>({
  required RenderSnapshot<TTheme> snapshot,
  required ChartVisibleWindow window,
  required ChartPriceTransform priceTransform,
  required bool closeArea,
  required double areaBottom,
}) {
  final path = Path();
  final visible = window.range;
  if (visible.isEmpty) {
    return path;
  }
  final firstIndex = visible.start;
  final firstX = window.xTransform.indexToLocalX(firstIndex);
  final firstY = priceTransform.priceToLocalY(
    snapshot.data.data[firstIndex].close,
  );
  path.moveTo(firstX, firstY);
  var previousX = firstX;
  var previousY = firstY;
  for (var index = firstIndex + 1; index < visible.end; index++) {
    final x = window.xTransform.indexToLocalX(index);
    final y = priceTransform.priceToLocalY(snapshot.data.data[index].close);
    final middleX = (previousX + x) / 2;
    path.cubicTo(middleX, previousY, middleX, y, x, y);
    previousX = x;
    previousY = y;
  }
  if (closeArea) {
    path
      ..lineTo(previousX, areaBottom)
      ..lineTo(firstX, areaBottom)
      ..close();
  }
  return path;
}

void _drawMainPriceSeries<TTheme extends ChartRenderStyle>({
  required Canvas canvas,
  required RenderSnapshot<TTheme> snapshot,
  required ChartLayoutRect panel,
  required ChartVisibleWindow window,
  required ChartPriceTransform priceTransform,
  required ChartRenderCache cache,
  required bool fillArea,
}) {
  final commonKey = (
    'main-price',
    snapshot.data.version,
    snapshot.versions.data,
    snapshot.versions.viewport,
    snapshot.versions.layout,
    snapshot.mainMode,
    priceTransform,
  );
  if (fillArea) {
    final areaPath = cache.path(
      (commonKey, 'area'),
      () => _buildMainPricePath(
        snapshot: snapshot,
        window: window,
        priceTransform: priceTransform,
        closeArea: true,
        areaBottom: panel.bottom,
      ),
    );
    canvas.drawPath(
      areaPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: snapshot.theme.areaFillColors,
        ).createShader(_rect(panel)),
    );
  }
  final linePath = cache.path(
    (commonKey, 'line'),
    () => _buildMainPricePath(
      snapshot: snapshot,
      window: window,
      priceTransform: priceTransform,
      closeArea: false,
      areaBottom: panel.bottom,
    ),
  );
  canvas.drawPath(
    linePath,
    Paint()
      ..color = snapshot.theme.mainLineColor
      ..strokeWidth = snapshot.theme.mainLineStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  if (window.range.length == 1) {
    final index = window.range.start;
    canvas.drawCircle(
      Offset(
        window.xTransform.indexToLocalX(index),
        priceTransform.priceToLocalY(snapshot.data.data[index].close),
      ),
      snapshot.theme.mainLineStrokeWidth,
      Paint()..color = snapshot.theme.mainLineColor,
    );
  }
}

void _drawCandles<TTheme extends ChartRenderStyle>({
  required Canvas canvas,
  required RenderSnapshot<TTheme> snapshot,
  required ChartVisibleWindow window,
  required ChartPriceTransform priceTransform,
  required ChartCandleProjection candles,
}) {
  final bodyWidth = math.max(
    1.0,
    snapshot.viewport.itemExtent * snapshot.theme.candleWidthRatio,
  );
  for (var index = window.range.start; index < window.range.end; index++) {
    final candle = candles.candles[index];
    final x = window.xTransform.indexToLocalX(index);
    final openY = priceTransform.priceToLocalY(candle.open);
    final closeY = priceTransform.priceToLocalY(candle.close);
    final highY = priceTransform.priceToLocalY(candle.high);
    final lowY = priceTransform.priceToLocalY(candle.low);
    final paint = Paint()
      ..color = candle.close >= candle.open
          ? snapshot.theme.upColor
          : snapshot.theme.downColor
      ..strokeWidth = snapshot.theme.dataStrokeWidth;
    canvas.drawLine(Offset(x, highY), Offset(x, lowY), paint);
    final top = math.min(openY, closeY);
    final bottom = math.max(openY, closeY);
    if (snapshot.mainMode == ChartMainMode.ohlc) {
      final halfWidth = bodyWidth / 2;
      canvas
        ..drawLine(Offset(x - halfWidth, openY), Offset(x, openY), paint)
        ..drawLine(Offset(x, closeY), Offset(x + halfWidth, closeY), paint);
    } else if (bottom - top < 1) {
      canvas.drawLine(
        Offset(x - bodyWidth / 2, top),
        Offset(x + bodyWidth / 2, top),
        paint,
      );
    } else if (snapshot.mainMode == ChartMainMode.hollowCandlestick) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(
        Rect.fromLTRB(x - bodyWidth / 2, top, x + bodyWidth / 2, bottom),
        paint,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTRB(x - bodyWidth / 2, top, x + bodyWidth / 2, bottom),
        paint,
      );
    }
  }
}

enum _IndicatorPaintPass { area, series }

void _drawIndicators<TTheme extends ChartRenderStyle>({
  required Canvas canvas,
  required RenderSnapshot<TTheme> snapshot,
  required String panelId,
  required ChartLayoutRect bounds,
  required ChartVisibleWindow window,
  required ChartPriceTransform valueTransform,
  required ChartRenderCache cache,
  required _IndicatorPaintPass pass,
}) {
  final visible = window.range;
  for (final indicator in snapshot.indicators) {
    if (indicator.panelId != panelId) {
      continue;
    }
    for (final descriptor in indicator.descriptor.series) {
      final series = indicator.seriesById(descriptor.id)!;
      final seriesColor = snapshot.theme.indicatorColor(
        indicator.instanceId,
        descriptor.id,
      );
      if (pass == _IndicatorPaintPass.area) {
        final fillOpacity = snapshot.theme.indicatorAreaFillOpacityFor(
          indicator.instanceId,
          descriptor.id,
          descriptor.areaFillOpacity,
        );
        if (descriptor.drawingKind != IndicatorDrawingKind.line ||
            descriptor.areaBaseline != IndicatorAreaBaseline.candleClose ||
            fillOpacity == 0) {
          continue;
        }
        final areaPath = cache.path(
          (
            'indicator-area',
            indicator.instanceId,
            descriptor.id,
            descriptor.lineStyle,
            descriptor.areaBaseline,
            descriptor.areaFillOpacity,
            snapshot.data.version,
            snapshot.versions.data,
            snapshot.versions.viewport,
            snapshot.versions.layout,
            panelId,
            valueTransform,
          ),
          () => _buildIndicatorAreaPath(
            snapshot: snapshot,
            series: series,
            visible: visible,
            xTransform: window.xTransform,
            valueTransform: valueTransform,
            lineStyle: descriptor.lineStyle,
          ),
        );
        canvas.drawPath(
          areaPath,
          Paint()
            ..color = seriesColor.withValues(alpha: fillOpacity)
            ..style = PaintingStyle.fill,
        );
        continue;
      }
      final paint = Paint()
        ..color = seriesColor
        ..strokeWidth = snapshot.theme.indicatorStrokeWidthFor(
          indicator.instanceId,
          descriptor.id,
          snapshot.theme.indicatorStrokeWidth *
              descriptor.lineStrokeWidthMultiplier,
        )
        ..style = PaintingStyle.stroke;
      switch (descriptor.drawingKind) {
        case IndicatorDrawingKind.line:
          final path = cache.path(
            (
              indicator.instanceId,
              descriptor.id,
              snapshot.data.version,
              snapshot.versions.data,
              snapshot.versions.viewport,
              snapshot.versions.layout,
              panelId,
              valueTransform,
              descriptor.lineStyle,
            ),
            () => _buildLinePath(
              series: series,
              visible: visible,
              xTransform: window.xTransform,
              valueTransform: valueTransform,
              lineStyle: descriptor.lineStyle,
            ),
          );
          canvas.drawPath(path, paint);
        case IndicatorDrawingKind.histogram:
          final baseline = valueTransform.priceToLocalY(0).clamp(
                bounds.top,
                bounds.bottom,
              );
          final width = math.max(
            1.0,
            snapshot.viewport.itemExtent * snapshot.theme.histogramWidthRatio,
          );
          for (var index = visible.start; index < visible.end; index++) {
            final value = series.values[index];
            if (value == null) {
              continue;
            }
            paint
              ..color = _resolveIndicatorColor(
                snapshot: snapshot,
                descriptor: descriptor,
                index: index,
                value: value,
                seriesColor: snapshot.theme.indicatorColor(
                  indicator.instanceId,
                  descriptor.id,
                ),
              )
              ..style = _histogramPaintingStyle(
                descriptor: descriptor,
                series: series,
                index: index,
                value: value,
              );
            final x = window.xTransform.indexToLocalX(index);
            final y = valueTransform.priceToLocalY(value);
            canvas.drawRect(
              Rect.fromLTRB(
                x - width / 2,
                math.min(y, baseline),
                x + width / 2,
                math.max(y, baseline),
              ),
              paint,
            );
          }
        case IndicatorDrawingKind.points:
          paint.style = PaintingStyle.fill;
          for (var index = visible.start; index < visible.end; index++) {
            final value = series.values[index];
            if (value == null) {
              continue;
            }
            paint.color = _resolveIndicatorColor(
              snapshot: snapshot,
              descriptor: descriptor,
              index: index,
              value: value,
              seriesColor: snapshot.theme.indicatorColor(
                indicator.instanceId,
                descriptor.id,
              ),
            );
            canvas.drawCircle(
              Offset(
                window.xTransform.indexToLocalX(index),
                valueTransform.priceToLocalY(value),
              ),
              snapshot.theme.indicatorPointRadius,
              paint,
            );
          }
      }
    }
  }
}

Color _resolveIndicatorColor<TTheme extends ChartRenderStyle>({
  required RenderSnapshot<TTheme> snapshot,
  required IndicatorSeriesDescriptor descriptor,
  required int index,
  required double value,
  required Color seriesColor,
}) =>
    switch (descriptor.colorStrategy) {
      IndicatorColorStrategy.series => seriesColor,
      IndicatorColorStrategy.candleDirection =>
        snapshot.data.data[index].close >= snapshot.data.data[index].open
            ? snapshot.theme.upColor
            : snapshot.theme.downColor,
      IndicatorColorStrategy.valueSign =>
        value >= 0 ? snapshot.theme.upColor : snapshot.theme.downColor,
      IndicatorColorStrategy.pricePosition =>
        value <= snapshot.data.data[index].close
            ? snapshot.theme.upColor
            : snapshot.theme.downColor,
    };

PaintingStyle _histogramPaintingStyle({
  required IndicatorSeriesDescriptor descriptor,
  required IndicatorSeries series,
  required int index,
  required double value,
}) {
  if (descriptor.histogramStyle == IndicatorHistogramStyle.solid ||
      index == 0 ||
      series.values[index - 1] == null) {
    return PaintingStyle.fill;
  }
  final previous = series.values[index - 1]!;
  final increasing = value > previous;
  final hollow = value >= 0 ? !increasing : increasing;
  return hollow ? PaintingStyle.stroke : PaintingStyle.fill;
}

_LatestPriceLayout
    _latestPriceLayoutForSnapshot<TTheme extends ChartRenderStyle>(
  RenderSnapshot<TTheme> snapshot,
  ChartRenderCache cache,
) {
  final panel = snapshot.layout.mainPanel.bounds;
  final latestIndex = snapshot.data.data.length - 1;
  final latest = cache.candlesFor(snapshot).candles[latestIndex];
  final latestX =
      cache.windowFor(snapshot).xTransform.indexToLocalX(latestIndex);
  final priceTransform = cache
      .panelRangeFor(snapshot, snapshot.layout.mainPanel.spec.id)
      .transform(panel);
  return _resolveLatestPriceLayout(
    panel: panel,
    latestX: latestX,
    latestPrice: latest.close,
    countdownText: snapshot.latestPriceCountdownText,
    priceTransform: priceTransform,
    mainMode: snapshot.mainMode,
    theme: snapshot.theme,
    cache: cache,
  );
}

_LatestPriceLayout _resolveLatestPriceLayout<TTheme extends ChartRenderStyle>({
  required ChartLayoutRect panel,
  required double latestX,
  required double latestPrice,
  required String countdownText,
  required ChartPriceTransform priceTransform,
  required ChartMainMode mainMode,
  required TTheme theme,
  required ChartRenderCache cache,
}) {
  const horizontalPadding = 7.0;
  const verticalPadding = 4.0;
  const lineGap = 1.0;
  const triangleHeight = 8.0;
  const triangleWidth = 4.0;
  final priceText = theme.formatMainValue(latestPrice);
  final fontSize = theme.axisFontSize + 2;
  final pricePainter = cache.textPainter(
    text: priceText,
    color: theme.axisTextColor,
    fontSize: fontSize,
  );
  final timePainter = cache.textPainter(
    text: countdownText,
    color: theme.axisTextColor,
    fontSize: fontSize,
  );
  final contentWidth = math.max(pricePainter.width, timePainter.width);
  final baseLabelWidth = contentWidth + horizontalPadding * 2;
  final labelHeight =
      pricePainter.height + timePainter.height + lineGap + verticalPadding * 2;
  final remainingRight = panel.right - latestX;
  final lineStartX =
      mainMode == ChartMainMode.line || mainMode == ChartMainMode.area
          ? latestX
          : latestX + ChartViewport.defaultItemExtent / 2;
  final candleClearance = lineStartX - latestX;
  final availableLabelWidth = remainingRight - candleClearance;
  var y = priceTransform.priceToLocalY(latestPrice);

  // The legacy renderer selected this branch from the text width, then fitted
  // the label into the available right margin. Keep that behavior on compact
  // screens by shrinking only the horizontal inset, never the text.
  if (contentWidth < availableLabelWidth) {
    final visibleHorizontalPadding = math.min(
      horizontalPadding,
      (availableLabelWidth - contentWidth) / 2,
    );
    final visibleLabelWidth = contentWidth + visibleHorizontalPadding * 2;
    final labelLeft = panel.right - visibleLabelWidth;
    return _LatestPriceLayout(
      labelBounds: _latestPriceLabelBounds(
        panel: panel,
        left: labelLeft,
        centerY: y,
        width: visibleLabelWidth,
        height: labelHeight,
      ),
      lineStartX: lineStartX,
      lineLength: labelLeft - lineStartX,
      lineY: y,
      horizontalPadding: visibleHorizontalPadding,
      verticalPadding: verticalPadding,
      lineGap: lineGap,
      pricePainter: pricePainter,
      timePainter: timePainter,
      showChevron: false,
    );
  }

  final visibleLatestPrice = latestPrice.clamp(
    priceTransform.minPrice,
    priceTransform.maxPrice,
  );
  y = priceTransform.priceToLocalY(visibleLatestPrice);
  final hiddenLabelWidth = baseLabelWidth + triangleWidth + 5;
  final left = math.max(
    panel.left,
    panel.right - hiddenLabelWidth * 2.25,
  );
  return _LatestPriceLayout(
    labelBounds: _latestPriceLabelBounds(
      panel: panel,
      left: left,
      centerY: y,
      width: hiddenLabelWidth,
      height: labelHeight,
    ),
    lineStartX: panel.left,
    lineLength: panel.width,
    lineY: y,
    horizontalPadding: horizontalPadding,
    verticalPadding: verticalPadding,
    lineGap: lineGap,
    pricePainter: pricePainter,
    timePainter: timePainter,
    showChevron: true,
    chevronWidth: triangleWidth,
    chevronHeight: triangleHeight,
  );
}

Rect _latestPriceLabelBounds({
  required ChartLayoutRect panel,
  required double left,
  required double centerY,
  required double width,
  required double height,
}) {
  final top = (centerY - height / 2)
      .clamp(
        panel.top + 1,
        panel.bottom - height - 1,
      )
      .toDouble();
  return Rect.fromLTWH(left, top, width, height);
}

void _drawLatestPrice<TTheme extends ChartRenderStyle>({
  required Canvas canvas,
  required _LatestPriceLayout layout,
  required TTheme theme,
}) {
  final linePaint = Paint()
    ..color = theme.axisTextColor
    ..strokeWidth = 0.6
    ..style = PaintingStyle.stroke;
  _drawLatestPriceDashedHorizontalLine(
    canvas: canvas,
    startX: layout.lineStartX,
    length: layout.lineLength,
    y: layout.lineY,
    paint: linePaint,
  );
  _drawLatestPriceLabel(
    canvas: canvas,
    bounds: layout.labelBounds,
    horizontalPadding: layout.horizontalPadding,
    verticalPadding: layout.verticalPadding,
    lineGap: layout.lineGap,
    pricePainter: layout.pricePainter,
    timePainter: layout.timePainter,
    theme: theme,
    showChevron: layout.showChevron,
    chevronWidth: layout.chevronWidth,
    chevronHeight: layout.chevronHeight,
  );
}

void _drawLatestPriceLabel<TTheme extends ChartRenderStyle>({
  required Canvas canvas,
  required Rect bounds,
  required double horizontalPadding,
  required double verticalPadding,
  required double lineGap,
  required TextPainter pricePainter,
  required TextPainter timePainter,
  required TTheme theme,
  required bool showChevron,
  double chevronWidth = 0,
  double chevronHeight = 0,
}) {
  final rect = RRect.fromLTRBR(
    bounds.left,
    bounds.top,
    bounds.right,
    bounds.bottom,
    const Radius.circular(5),
  );
  canvas
    ..drawRRect(rect, Paint()..color = theme.backgroundColor)
    ..drawRRect(
      rect,
      Paint()
        ..color = theme.axisTextColor
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
  final contentRightPadding = showChevron ? chevronWidth + 5 : 0;
  final contentWidth =
      bounds.width - horizontalPadding * 2 - contentRightPadding;
  pricePainter.paint(
    canvas,
    Offset(
      bounds.left + horizontalPadding + (contentWidth - pricePainter.width) / 2,
      bounds.top + verticalPadding,
    ),
  );
  timePainter.paint(
    canvas,
    Offset(
      bounds.left + horizontalPadding + (contentWidth - timePainter.width) / 2,
      bounds.top + verticalPadding + pricePainter.height + lineGap,
    ),
  );
  if (!showChevron) return;
  final chevronX = bounds.right - horizontalPadding - chevronWidth;
  final chevronY = bounds.top + (bounds.height - chevronHeight) / 2;
  final chevron = Path()
    ..moveTo(chevronX, chevronY)
    ..lineTo(chevronX + chevronWidth, chevronY + chevronHeight / 2)
    ..lineTo(chevronX, chevronY + chevronHeight);
  canvas.drawPath(
    chevron,
    Paint()
      ..color = theme.axisTextColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke,
  );
}

final class _LatestPriceLayout {
  const _LatestPriceLayout({
    required this.labelBounds,
    required this.lineStartX,
    required this.lineLength,
    required this.lineY,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.lineGap,
    required this.pricePainter,
    required this.timePainter,
    required this.showChevron,
    this.chevronWidth = 0,
    this.chevronHeight = 0,
  });

  final Rect labelBounds;
  final double lineStartX;
  final double lineLength;
  final double lineY;
  final double horizontalPadding;
  final double verticalPadding;
  final double lineGap;
  final TextPainter pricePainter;
  final TextPainter timePainter;
  final bool showChevron;
  final double chevronWidth;
  final double chevronHeight;
}

void _drawLatestPriceDashedHorizontalLine({
  required Canvas canvas,
  required double startX,
  required double length,
  required double y,
  required Paint paint,
  double dashWidth = 4,
  double dashSpace = 4,
}) {
  if (length <= 0) return;
  var offset = 0.0;
  while (offset < length) {
    canvas.drawLine(
      Offset(startX + offset, y),
      Offset(startX + offset + dashWidth, y),
      paint,
    );
    offset += dashWidth + dashSpace;
  }
}

void _drawDashedLine({
  required Canvas canvas,
  required Offset start,
  required Offset end,
  required Paint paint,
  required double dashLength,
  required double dashGap,
}) {
  final delta = end - start;
  final length = delta.distance;
  if (length == 0) return;
  final direction = delta / length;
  for (var offset = 0.0; offset < length; offset += dashLength + dashGap) {
    canvas.drawLine(
      start + direction * offset,
      start + direction * math.min(offset + dashLength, length),
      paint,
    );
  }
}

void _drawCrosshairLabel<TTheme extends ChartRenderStyle>({
  required Canvas canvas,
  required String text,
  required ChartLayoutRect bounds,
  required double fontSize,
  required double x,
  required double y,
  required double horizontalAnchor,
  required double verticalAnchor,
  required ChartRenderCache cache,
  required TTheme theme,
}) {
  final painter = cache.textPainter(
    text: text,
    color: theme.crosshairLabelTextColor,
    fontSize: fontSize,
  );
  final width = painter.width + theme.crosshairLabelHorizontalPadding * 2;
  final height = painter.height + theme.crosshairLabelVerticalPadding * 2;
  final unclampedLeft = x - width * horizontalAnchor;
  final unclampedTop = y - height * verticalAnchor;
  final maxLeft = math.max(bounds.left, bounds.right - width);
  final maxTop = math.max(bounds.top, bounds.bottom - height);
  final left = unclampedLeft.clamp(bounds.left, maxLeft).toDouble();
  final top = unclampedTop.clamp(bounds.top, maxTop).toDouble();
  final rect = Rect.fromLTWH(left, top, width, height);
  canvas.drawRect(rect, Paint()..color = theme.crosshairLabelBackgroundColor);
  painter.paint(
    canvas,
    Offset(
      rect.left + theme.crosshairLabelHorizontalPadding,
      rect.top + theme.crosshairLabelVerticalPadding,
    ),
  );
}

void _drawText({
  required Canvas canvas,
  required String text,
  required Color color,
  required double fontSize,
  required double x,
  required double y,
  double horizontalAnchor = 0,
  double verticalAnchor = 0,
  required ChartRenderCache cache,
}) {
  final painter = cache.textPainter(
    text: text,
    color: color,
    fontSize: fontSize,
  );
  painter.paint(
    canvas,
    Offset(
      x - painter.width * horizontalAnchor,
      y - painter.height * verticalAnchor,
    ),
  );
}

Rect _rect(ChartLayoutRect bounds) => Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    );
