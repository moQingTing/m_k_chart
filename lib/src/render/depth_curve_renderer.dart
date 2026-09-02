import 'dart:collection';

import 'package:flutter/painting.dart';

import '../model/depth_book.dart';
import '../theme/chart_render_style.dart';

/// Deterministic geometry for a two-sided cumulative depth chart.
final class DepthChartLayout {
  factory DepthChartLayout({
    required Size size,
    double axisHeight = 24,
    double centerGap = 12,
    double topPadding = 8,
  }) {
    for (final entry in <String, double>{
      'width': size.width,
      'height': size.height,
      'axisHeight': axisHeight,
      'centerGap': centerGap,
      'topPadding': topPadding,
    }.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must be finite and non-negative.',
        );
      }
    }
    final plotBottom = size.height - axisHeight;
    if (size.width <= centerGap || plotBottom <= topPadding) {
      throw ArgumentError(
        'Depth chart size cannot satisfy its reserved areas.',
      );
    }
    final sideWidth = (size.width - centerGap) / 2;
    final bidBounds = Rect.fromLTRB(0, topPadding, sideWidth, plotBottom);
    final askBounds = Rect.fromLTRB(
      sideWidth + centerGap,
      topPadding,
      size.width,
      plotBottom,
    );
    return DepthChartLayout._(
      size: size,
      plotBounds: Rect.fromLTRB(0, topPadding, size.width, plotBottom),
      bidBounds: bidBounds,
      askBounds: askBounds,
      axisBounds: Rect.fromLTRB(0, plotBottom, size.width, size.height),
      centerGap: centerGap,
    );
  }

  const DepthChartLayout._({
    required this.size,
    required this.plotBounds,
    required this.bidBounds,
    required this.askBounds,
    required this.axisBounds,
    required this.centerGap,
  });

  final Size size;
  final Rect plotBounds;
  final Rect bidBounds;
  final Rect askBounds;
  final Rect axisBounds;
  final double centerGap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthChartLayout &&
          size == other.size &&
          plotBounds == other.plotBounds &&
          bidBounds == other.bidBounds &&
          askBounds == other.askBounds &&
          axisBounds == other.axisBounds &&
          centerGap == other.centerGap;

  @override
  int get hashCode => Object.hash(
        size,
        plotBounds,
        bidBounds,
        askBounds,
        axisBounds,
        centerGap,
      );
}

/// Immutable renderer input, separate from the K-line [RenderSnapshot].
final class DepthRenderSnapshot<TTheme extends ChartRenderStyle> {
  factory DepthRenderSnapshot({
    required DepthBook book,
    required TTheme theme,
    required DepthChartLayout layout,
    int version = 0,
  }) {
    if (version < 0) {
      throw ArgumentError.value(version, 'version', 'Must not be negative.');
    }
    return DepthRenderSnapshot._(
      book: book,
      curve: DepthCurve.fromBook(book),
      theme: theme,
      layout: layout,
      version: version,
    );
  }

  const DepthRenderSnapshot._({
    required this.book,
    required this.curve,
    required this.theme,
    required this.layout,
    required this.version,
  });

  final DepthBook book;
  final DepthCurve curve;
  final TTheme theme;
  final DepthChartLayout layout;
  final int version;
}

final class DepthCurvePoint {
  const DepthCurvePoint({required this.level, required this.position});

  final DepthCumulativeLevel level;
  final Offset position;
}

/// Price-aware local coordinates for both cumulative sides.
final class DepthCurveProjection {
  static DepthCurveProjection fromSnapshot<TTheme extends ChartRenderStyle>(
    DepthRenderSnapshot<TTheme> snapshot,
  ) {
    final maximum = snapshot.curve.maxCumulativeQuantity;
    if (maximum == 0) {
      return const DepthCurveProjection._(bids: [], asks: []);
    }
    return DepthCurveProjection._(
      bids: UnmodifiableListView(
        _projectSide(
          snapshot.curve.bids,
          snapshot.layout.bidBounds,
          maximum,
          side: DepthSide.bid,
        ),
      ),
      asks: UnmodifiableListView(
        _projectSide(
          snapshot.curve.asks,
          snapshot.layout.askBounds,
          maximum,
          side: DepthSide.ask,
        ),
      ),
    );
  }

  const DepthCurveProjection._({required this.bids, required this.asks});

  /// Best-to-outward source order. Bid X decreases; ask X increases.
  final List<DepthCurvePoint> bids;
  final List<DepthCurvePoint> asks;
}

/// Pure Canvas renderer for price-aware cumulative bid and ask curves.
abstract final class StandardDepthCurveRenderer {
  static void paint<TTheme extends ChartRenderStyle>({
    required Canvas canvas,
    required DepthRenderSnapshot<TTheme> snapshot,
  }) {
    final theme = snapshot.theme;
    final layout = snapshot.layout;
    canvas.drawRect(
      Offset.zero & layout.size,
      Paint()..color = theme.backgroundColor,
    );
    final gridPaint = Paint()
      ..color = theme.gridColor
      ..strokeWidth = theme.gridStrokeWidth
      ..style = PaintingStyle.stroke;
    for (var row = 0; row <= 2; row++) {
      final y = layout.plotBounds.top + layout.plotBounds.height * row / 2;
      canvas.drawLine(
        Offset(layout.plotBounds.left, y),
        Offset(layout.plotBounds.right, y),
        gridPaint,
      );
    }
    canvas.drawLine(
      Offset(
        layout.bidBounds.right + layout.centerGap / 2,
        layout.plotBounds.top,
      ),
      Offset(
        layout.bidBounds.right + layout.centerGap / 2,
        layout.plotBounds.bottom,
      ),
      gridPaint,
    );
    final projection = DepthCurveProjection.fromSnapshot(snapshot);
    _drawSide(
      canvas: canvas,
      points: projection.bids.reversed.toList(growable: false),
      bottom: layout.plotBounds.bottom,
      color: theme.upColor,
      strokeWidth: theme.dataStrokeWidth,
    );
    _drawSide(
      canvas: canvas,
      points: projection.asks,
      bottom: layout.plotBounds.bottom,
      color: theme.downColor,
      strokeWidth: theme.dataStrokeWidth,
    );
    _drawAxes(canvas, snapshot);
  }
}

List<DepthCurvePoint> _projectSide(
  List<DepthCumulativeLevel> levels,
  Rect bounds,
  double maximum, {
  required DepthSide side,
}) {
  if (levels.isEmpty) return const [];
  final bestPrice = levels.first.price;
  final outwardPrice = levels.last.price;
  final span = (bestPrice - outwardPrice).abs();
  return [
    for (final level in levels)
      DepthCurvePoint(
        level: level,
        position: Offset(
          switch (side) {
            DepthSide.bid => span == 0
                ? bounds.right
                : bounds.left +
                    (level.price - outwardPrice) / span * bounds.width,
            DepthSide.ask => span == 0
                ? bounds.left
                : bounds.left + (level.price - bestPrice) / span * bounds.width,
          },
          bounds.bottom - level.cumulativeQuantity / maximum * bounds.height,
        ),
      ),
  ];
}

void _drawSide({
  required Canvas canvas,
  required List<DepthCurvePoint> points,
  required double bottom,
  required Color color,
  required double strokeWidth,
}) {
  if (points.isEmpty) return;
  final line = Path()
    ..moveTo(points.first.position.dx, points.first.position.dy);
  for (var index = 1; index < points.length; index++) {
    final previous = points[index - 1].position;
    final current = points[index].position;
    line
      ..lineTo(current.dx, previous.dy)
      ..lineTo(current.dx, current.dy);
  }
  final fill = Path()
    ..moveTo(points.first.position.dx, bottom)
    ..lineTo(points.first.position.dx, points.first.position.dy);
  for (var index = 1; index < points.length; index++) {
    final previous = points[index - 1].position;
    final current = points[index].position;
    fill
      ..lineTo(current.dx, previous.dy)
      ..lineTo(current.dx, current.dy);
  }
  fill
    ..lineTo(points.last.position.dx, bottom)
    ..close();
  canvas
    ..drawPath(fill, Paint()..color = color.withAlpha(52))
    ..drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
}

void _drawAxes<TTheme extends ChartRenderStyle>(
  Canvas canvas,
  DepthRenderSnapshot<TTheme> snapshot,
) {
  final book = snapshot.book;
  final theme = snapshot.theme;
  final layout = snapshot.layout;
  final bidOuter = book.bids.isEmpty ? null : book.bids.last.price;
  final askOuter = book.asks.isEmpty ? null : book.asks.last.price;
  final middle = book.midPrice;
  if (bidOuter != null) {
    _drawText(
      canvas,
      theme.formatMainValue(bidOuter),
      Offset(layout.axisBounds.left + 2, layout.axisBounds.center.dy),
      theme,
      horizontalAnchor: 0,
    );
  }
  if (middle != null) {
    _drawText(
      canvas,
      theme.formatMainValue(middle),
      layout.axisBounds.center,
      theme,
      horizontalAnchor: 0.5,
    );
  }
  if (askOuter != null) {
    _drawText(
      canvas,
      theme.formatMainValue(askOuter),
      Offset(layout.axisBounds.right - 2, layout.axisBounds.center.dy),
      theme,
      horizontalAnchor: 1,
    );
  }
  if (snapshot.curve.maxCumulativeQuantity > 0) {
    _drawText(
      canvas,
      theme.formatSecondaryValue(snapshot.curve.maxCumulativeQuantity),
      Offset(layout.plotBounds.right - 2, layout.plotBounds.top + 2),
      theme,
      horizontalAnchor: 1,
      verticalAnchor: 0,
    );
  }
}

void _drawText<TTheme extends ChartRenderStyle>(
  Canvas canvas,
  String text,
  Offset anchor,
  TTheme theme, {
  required double horizontalAnchor,
  double verticalAnchor = 0.5,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style:
          TextStyle(color: theme.axisTextColor, fontSize: theme.axisFontSize),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      anchor.dx - painter.width * horizontalAnchor,
      anchor.dy - painter.height * verticalAnchor,
    ),
  );
}
