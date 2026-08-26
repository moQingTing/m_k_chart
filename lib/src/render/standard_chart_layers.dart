import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/painting.dart';

import '../indicator/indicator.dart';
import '../theme/theme.dart';
import '../viewport/viewport.dart';
import 'chart_candle_projection.dart';
import 'chart_main_mode.dart';
import 'render_cache.dart';
import 'render_layer.dart';
import 'render_repaint.dart';
import 'render_snapshot.dart';

final class ChartGridLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartGridLayer(this.cache)
      : super(
          id: 'grid',
          dependencies: const {
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    final picture = cache.picture(
      (
        'grid',
        snapshot.versions.layout,
        snapshot.versions.theme,
        snapshot.layout,
      ),
      () => _recordGridPicture(snapshot),
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
          text: _formatNumber(value),
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
    for (final x in layout.gridColumnXs) {
      final time = xTransform.localXToTime(x);
      _drawText(
        canvas: context.canvas,
        text: _formatTime(time),
        color: theme.axisTextColor,
        fontSize: theme.axisFontSize,
        x: x,
        y: layout.timeAxisBounds.top + 2,
        horizontalAnchor: x == layout.gridColumnXs.first
            ? 0
            : x == layout.gridColumnXs.last
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
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final snapshot = context.snapshot;
    final window = cache.windowFor(snapshot);
    final visible = window.range;
    if (visible.isEmpty) {
      return;
    }
    final panel = snapshot.layout.mainPanel;
    final transform = cache
        .panelRangeFor(
          snapshot,
          panel.spec.id,
        )
        .transform(panel.bounds);
    final xTransform = window.xTransform;
    final extrema = cache.extremaFor(snapshot)!;
    final midpoint = (panel.bounds.left + panel.bounds.right) / 2;
    final paint = Paint()
      ..color = snapshot.theme.markerColor
      ..strokeWidth = snapshot.theme.overlayStrokeWidth
      ..style = PaintingStyle.stroke;
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
        text: '${point.$3} ${_formatNumber(point.$2)}',
        color: snapshot.theme.markerColor,
        fontSize: snapshot.theme.axisFontSize,
        x: x < midpoint ? x + 5 : x - 5,
        y: y,
        horizontalAnchor: x < midpoint ? 0 : 1,
        verticalAnchor: 0.5,
        cache: cache,
      );
    }

    final latestIndex = snapshot.data.data.length - 1;
    if (!visible.contains(latestIndex)) {
      return;
    }
    final latest = cache.candlesFor(snapshot).candles[latestIndex];
    final localX = xTransform.indexToLocalX(latestIndex);
    final localY = transform.priceToLocalY(latest.close);
    final latestColor = latest.close >= latest.open
        ? snapshot.theme.upColor
        : snapshot.theme.downColor;
    paint.color = latestColor;
    context.canvas.drawLine(
      Offset(localX, localY),
      Offset(panel.bounds.right, localY),
      paint,
    );
    _drawText(
      canvas: context.canvas,
      text: _formatNumber(latest.close),
      color: latestColor,
      fontSize: snapshot.theme.axisFontSize,
      x: panel.bounds.right - 3,
      y: localY,
      horizontalAnchor: 1,
      verticalAnchor: 0.5,
      cache: cache,
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
          },
        );

  final ChartRenderCache cache;

  @override
  void paint(RenderLayerContext<TTheme> context) {
    final selection = context.snapshot.selection;
    if (!selection.isVisible) {
      return;
    }
    final bounds = context.snapshot.layout.drawingBounds;
    if (!bounds.contains(x: selection.localX, y: selection.localY)) {
      return;
    }
    final paint = Paint()
      ..color = context.snapshot.theme.crosshairColor
      ..strokeWidth = context.snapshot.theme.overlayStrokeWidth
      ..style = PaintingStyle.stroke;
    context.canvas.drawLine(
      Offset(selection.localX, bounds.top),
      Offset(selection.localX, bounds.bottom),
      paint,
    );
    context.canvas.drawLine(
      Offset(bounds.left, selection.localY),
      Offset(bounds.right, selection.localY),
      paint,
    );
    if (selection.price != null) {
      _drawText(
        canvas: context.canvas,
        text: _formatNumber(selection.price!),
        color: context.snapshot.theme.crosshairColor,
        fontSize: context.snapshot.theme.axisFontSize,
        x: bounds.right - 3,
        y: selection.localY,
        horizontalAnchor: 1,
        verticalAnchor: 0.5,
        cache: cache,
      );
    }
  }
}

/// Projected chart-local drawing primitives. P7 will add anchored tools.
final class ChartDrawingLayer<TTheme extends ChartRenderStyle>
    extends ChartRenderLayer<TTheme> {
  ChartDrawingLayer()
      : super(
          id: 'drawing',
          dependencies: const {
            RenderSnapshotSlice.data,
            RenderSnapshotSlice.layout,
            RenderSnapshotSlice.theme,
          },
        );

  @override
  void paint(RenderLayerContext<TTheme> context) {
    if (context.snapshot.drawings.isEmpty) {
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
          ChartDrawingLayer<TTheme>(),
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
  for (final x in layout.gridColumnXs) {
    canvas.drawLine(
      Offset(x, layout.drawingBounds.top),
      Offset(x, layout.drawingBounds.bottom),
      paint,
    );
  }
  for (final panel in layout.panels) {
    for (final y in layout.gridRowYsFor(panel.spec.id)) {
      canvas.drawLine(
        Offset(panel.bounds.left, y),
        Offset(panel.bounds.right, y),
        paint,
      );
    }
  }
  return recorder.endRecording();
}

Path _buildLinePath({
  required IndicatorSeries series,
  required VisibleIndexRange visible,
  required ChartXTransform xTransform,
  required ChartPriceTransform valueTransform,
}) {
  final path = Path();
  var active = false;
  for (var index = visible.start; index < visible.end; index++) {
    final value = series.values[index];
    if (value == null) {
      active = false;
      continue;
    }
    final x = xTransform.indexToLocalX(index);
    final y = valueTransform.priceToLocalY(value);
    if (active) {
      path.lineTo(x, y);
    } else {
      path.moveTo(x, y);
      active = true;
    }
  }
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

void _drawIndicators<TTheme extends ChartRenderStyle>({
  required Canvas canvas,
  required RenderSnapshot<TTheme> snapshot,
  required String panelId,
  required ChartLayoutRect bounds,
  required ChartVisibleWindow window,
  required ChartPriceTransform valueTransform,
  required ChartRenderCache cache,
}) {
  final visible = window.range;
  for (final indicator in snapshot.indicators) {
    if (indicator.panelId != panelId) {
      continue;
    }
    for (final descriptor in indicator.descriptor.series) {
      final series = indicator.seriesById(descriptor.id)!;
      final paint = Paint()
        ..color = snapshot.theme.indicatorColor(
          indicator.instanceId,
          descriptor.id,
        )
        ..strokeWidth = snapshot.theme.indicatorStrokeWidth
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
            ),
            () => _buildLinePath(
              series: series,
              visible: visible,
              xTransform: window.xTransform,
              valueTransform: valueTransform,
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

String _formatNumber(double value) {
  final absolute = value.abs();
  if (absolute >= 1000) {
    return value.toStringAsFixed(0);
  }
  if (absolute >= 1) {
    return value.toStringAsFixed(2);
  }
  return value.toStringAsFixed(4);
}

String _formatTime(int epochMilliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    epochMilliseconds,
    isUtc: true,
  );
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

Rect _rect(ChartLayoutRect bounds) => Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    );
