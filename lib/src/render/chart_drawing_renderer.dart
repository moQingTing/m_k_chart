import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../drawing/drawing.dart';
import '../viewport/viewport.dart';

/// Stateless Canvas renderer for P7 time/price-anchored drawing tools.
///
/// Projection is recomputed from the current viewport for every render pass;
/// persisted drawings never contain panel-local pixels.
final class ChartDrawingRenderer {
  const ChartDrawingRenderer._();

  static void paintAnchored({
    required Canvas canvas,
    required ChartDrawing drawing,
    required ChartXTransform xTransform,
    required ChartPriceTransform priceTransform,
    required Rect bounds,
    required Color color,
    required String Function(double value) formatPrice,
    double textFontSize = 12,
  }) {
    if (!drawing.style.visible || xTransform.isEmpty) return;
    final points = ChartDrawingAnchorProjector.project(
      drawing: drawing,
      xTransform: xTransform,
      priceTransform: priceTransform,
      localXOffset: bounds.left,
    );
    paint(
      canvas: canvas,
      drawing: drawing,
      controlPoints: points,
      bounds: bounds,
      color: color,
      formatPrice: formatPrice,
      textFontSize: textFontSize,
    );
  }

  static void paint({
    required Canvas canvas,
    required ChartDrawing drawing,
    required Iterable<ChartDrawingControlPoint> controlPoints,
    required Rect bounds,
    required Color color,
    required String Function(double value) formatPrice,
    double textFontSize = 12,
  }) {
    if (!drawing.style.visible) return;
    if (!bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.right.isFinite ||
        !bounds.bottom.isFinite ||
        bounds.isEmpty) {
      throw ArgumentError.value(
        bounds,
        'bounds',
        'Must be finite and nonempty.',
      );
    }
    if (!textFontSize.isFinite || textFontSize <= 0) {
      throw ArgumentError.value(
        textFontSize,
        'textFontSize',
        'Must be finite and positive.',
      );
    }
    final points = _orderedPoints(drawing, controlPoints);
    final paint = Paint()
      ..color = color
      ..strokeWidth = drawing.style.strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(bounds);
    switch (drawing.kind) {
      case ChartDrawingKind.trendLine:
        _drawSegment(canvas, points[0], points[1], paint, drawing.style);
      case ChartDrawingKind.horizontalLine:
        _drawLine(
          canvas,
          Offset(bounds.left, points.first.localY),
          Offset(bounds.right, points.first.localY),
          paint,
          drawing.style,
        );
      case ChartDrawingKind.verticalLine:
        _drawLine(
          canvas,
          Offset(points.first.localX, bounds.top),
          Offset(points.first.localX, bounds.bottom),
          paint,
          drawing.style,
        );
      case ChartDrawingKind.ray:
        _drawRay(canvas, points[0], points[1], bounds, paint, drawing.style);
      case ChartDrawingKind.rectangle:
        _drawRectangle(canvas, points[0], points[1], paint, drawing.style);
      case ChartDrawingKind.parallelChannel:
        _drawParallelChannel(canvas, points, paint, drawing.style);
      case ChartDrawingKind.fibonacciRetracement:
        _drawFibonacci(canvas, points[0], points[1], paint, drawing.style);
      case ChartDrawingKind.text:
        _drawText(
          canvas,
          drawing.text!,
          Offset(points.first.localX, points.first.localY),
          color,
          textFontSize,
        );
      case ChartDrawingKind.priceMarker:
        _drawLine(
          canvas,
          Offset(bounds.left, points.first.localY),
          Offset(bounds.right, points.first.localY),
          paint,
          drawing.style,
        );
        _drawText(
          canvas,
          formatPrice(drawing.anchors.first.price),
          Offset(bounds.right - 3, points.first.localY),
          color,
          textFontSize,
          horizontalAnchor: 1,
          verticalAnchor: 1,
        );
    }
    canvas.restore();
  }
}

List<ChartDrawingControlPoint> _orderedPoints(
  ChartDrawing drawing,
  Iterable<ChartDrawingControlPoint> values,
) {
  final points = List<ChartDrawingControlPoint>.of(values)
    ..sort((first, second) => first.anchorIndex.compareTo(second.anchorIndex));
  if (points.length != drawing.anchors.length) {
    throw ArgumentError.value(
      values,
      'controlPoints',
      'Must contain one projected point for every drawing anchor.',
    );
  }
  for (var index = 0; index < points.length; index++) {
    if (points[index].drawingId != drawing.id ||
        points[index].anchorIndex != index) {
      throw ArgumentError.value(
        values,
        'controlPoints',
        'Points must match the drawing ID and consecutive anchor indexes.',
      );
    }
  }
  return points;
}

void _drawSegment(
  Canvas canvas,
  ChartDrawingControlPoint start,
  ChartDrawingControlPoint end,
  Paint paint,
  ChartDrawingStyle style,
) =>
    _drawLine(
      canvas,
      Offset(start.localX, start.localY),
      Offset(end.localX, end.localY),
      paint,
      style,
    );

void _drawLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  ChartDrawingStyle style,
) {
  if (style.dashPattern.isEmpty) {
    canvas.drawLine(start, end, paint);
    return;
  }
  final vector = end - start;
  final length = vector.distance;
  if (length == 0) return;
  final direction = vector / length;
  var position = 0.0;
  var patternIndex = 0;
  var draw = true;
  while (position < length) {
    final next = math.min(position + style.dashPattern[patternIndex], length);
    if (draw) {
      canvas.drawLine(
        start + direction * position,
        start + direction * next,
        paint,
      );
    }
    position = next;
    patternIndex = (patternIndex + 1) % style.dashPattern.length;
    draw = !draw;
  }
}

void _drawRay(
  Canvas canvas,
  ChartDrawingControlPoint start,
  ChartDrawingControlPoint through,
  Rect bounds,
  Paint paint,
  ChartDrawingStyle style,
) {
  final origin = Offset(start.localX, start.localY);
  final vector =
      Offset(through.localX - start.localX, through.localY - start.localY);
  if (vector.distanceSquared == 0) return;
  final end = _rayExit(origin, vector, bounds);
  _drawLine(canvas, origin, end, paint, style);
}

Offset _rayExit(Offset origin, Offset vector, Rect bounds) {
  final candidates = <double>[];
  if (vector.dx != 0) {
    for (final edge in [bounds.left, bounds.right]) {
      final factor = (edge - origin.dx) / vector.dx;
      final y = origin.dy + factor * vector.dy;
      if (factor >= 0 && y >= bounds.top && y <= bounds.bottom) {
        candidates.add(factor);
      }
    }
  }
  if (vector.dy != 0) {
    for (final edge in [bounds.top, bounds.bottom]) {
      final factor = (edge - origin.dy) / vector.dy;
      final x = origin.dx + factor * vector.dx;
      if (factor >= 0 && x >= bounds.left && x <= bounds.right) {
        candidates.add(factor);
      }
    }
  }
  final factor =
      candidates.isEmpty ? 1.0 : candidates.reduce(math.max).toDouble();
  return origin + vector * factor;
}

void _drawRectangle(
  Canvas canvas,
  ChartDrawingControlPoint first,
  ChartDrawingControlPoint second,
  Paint paint,
  ChartDrawingStyle style,
) {
  final rect = Rect.fromPoints(
    Offset(first.localX, first.localY),
    Offset(second.localX, second.localY),
  );
  if (style.dashPattern.isEmpty) {
    canvas.drawRect(rect, paint);
    return;
  }
  final corners = [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ];
  for (var index = 0; index < corners.length; index++) {
    _drawLine(
      canvas,
      corners[index],
      corners[(index + 1) % corners.length],
      paint,
      style,
    );
  }
}

void _drawParallelChannel(
  Canvas canvas,
  List<ChartDrawingControlPoint> points,
  Paint paint,
  ChartDrawingStyle style,
) {
  _drawSegment(canvas, points[0], points[1], paint, style);
  final vector = Offset(
    points[1].localX - points[0].localX,
    points[1].localY - points[0].localY,
  );
  _drawLine(
    canvas,
    Offset(points[2].localX, points[2].localY),
    Offset(points[2].localX + vector.dx, points[2].localY + vector.dy),
    paint,
    style,
  );
}

void _drawFibonacci(
  Canvas canvas,
  ChartDrawingControlPoint first,
  ChartDrawingControlPoint second,
  Paint paint,
  ChartDrawingStyle style,
) {
  final left = math.min(first.localX, second.localX);
  final right = math.max(first.localX, second.localX);
  final span = second.localY - first.localY;
  for (final ratio in const [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]) {
    final y = first.localY + span * ratio;
    _drawLine(canvas, Offset(left, y), Offset(right, y), paint, style);
  }
}

void _drawText(
  Canvas canvas,
  String text,
  Offset anchor,
  Color color,
  double fontSize, {
  double horizontalAnchor = 0,
  double verticalAnchor = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      anchor.dx - painter.width * horizontalAnchor,
      anchor.dy - painter.height * verticalAnchor,
    ),
  );
}
