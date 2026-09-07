import 'dart:math' as math;

import 'chart_drawing.dart';

/// A projected, chart-local handle for one [ChartDrawingAnchor].
///
/// The drawing module deliberately receives pixel coordinates from the
/// viewport module instead of depending on viewport transforms itself.
final class ChartDrawingControlPoint {
  factory ChartDrawingControlPoint({
    required String drawingId,
    required int anchorIndex,
    required double localX,
    required double localY,
  }) {
    if (drawingId.trim().isEmpty) {
      throw ArgumentError.value(drawingId, 'drawingId', 'Must not be empty.');
    }
    if (anchorIndex < 0) {
      throw ArgumentError.value(
        anchorIndex,
        'anchorIndex',
        'Must not be negative.',
      );
    }
    _requireFinite(localX, 'localX');
    _requireFinite(localY, 'localY');
    return ChartDrawingControlPoint._(
      drawingId: drawingId,
      anchorIndex: anchorIndex,
      localX: localX,
      localY: localY,
    );
  }

  const ChartDrawingControlPoint._({
    required this.drawingId,
    required this.anchorIndex,
    required this.localX,
    required this.localY,
  });

  final String drawingId;
  final int anchorIndex;
  final double localX;
  final double localY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDrawingControlPoint &&
          drawingId == other.drawingId &&
          anchorIndex == other.anchorIndex &&
          localX == other.localX &&
          localY == other.localY;

  @override
  int get hashCode => Object.hash(drawingId, anchorIndex, localX, localY);
}

/// The visual part of a drawing selected by [ChartDrawingHitTester].
enum ChartDrawingHitKind {
  controlPoint,
  body,
}

/// Immutable result of one drawing hit test.
final class ChartDrawingHit {
  factory ChartDrawingHit({
    required ChartDrawing drawing,
    required ChartDrawingHitKind kind,
    required double distance,
    int? anchorIndex,
  }) {
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError.value(
        distance,
        'distance',
        'Must be finite and non-negative.',
      );
    }
    if (kind == ChartDrawingHitKind.controlPoint && anchorIndex == null) {
      throw ArgumentError.value(
        anchorIndex,
        'anchorIndex',
        'A control-point hit requires an anchor index.',
      );
    }
    if (anchorIndex != null &&
        (anchorIndex < 0 || anchorIndex >= drawing.anchors.length)) {
      throw RangeError.index(anchorIndex, drawing.anchors, 'anchorIndex');
    }
    return ChartDrawingHit._(
      drawing: drawing,
      kind: kind,
      distance: distance,
      anchorIndex: anchorIndex,
    );
  }

  const ChartDrawingHit._({
    required this.drawing,
    required this.kind,
    required this.distance,
    required this.anchorIndex,
  });

  final ChartDrawing drawing;
  final ChartDrawingHitKind kind;
  final double distance;
  final int? anchorIndex;
}

/// Geometry-only hit testing for projected drawing control points.
///
/// This layer has no Flutter or viewport dependency. The caller projects the
/// time/price anchors first, making hit behavior deterministic across panels,
/// zoom levels, and render backends.
final class ChartDrawingHitTester {
  const ChartDrawingHitTester._();

  static ChartDrawingHit? hitTest({
    required ChartDrawing drawing,
    required Iterable<ChartDrawingControlPoint> controlPoints,
    required double localX,
    required double localY,
    double controlPointTolerance = 12,
    double bodyTolerance = 8,
  }) {
    _requireFinite(localX, 'localX');
    _requireFinite(localY, 'localY');
    _requireNonNegativeFinite(controlPointTolerance, 'controlPointTolerance');
    _requireNonNegativeFinite(bodyTolerance, 'bodyTolerance');
    if (!drawing.style.visible) return null;

    final points = _validatedPoints(drawing, controlPoints);
    final controlHit = _nearestControlPoint(
      drawing: drawing,
      points: points,
      localX: localX,
      localY: localY,
      tolerance: controlPointTolerance,
    );
    if (controlHit != null) return controlHit;

    final distance = _bodyDistance(drawing.kind, points, localX, localY);
    final effectiveTolerance = bodyTolerance + drawing.style.strokeWidth / 2;
    if (distance > effectiveTolerance) return null;
    return ChartDrawingHit(
      drawing: drawing,
      kind: ChartDrawingHitKind.body,
      distance: distance,
    );
  }
}

List<ChartDrawingControlPoint> _validatedPoints(
  ChartDrawing drawing,
  Iterable<ChartDrawingControlPoint> values,
) {
  final points = List<ChartDrawingControlPoint>.of(values)
    ..sort((first, second) => first.anchorIndex.compareTo(second.anchorIndex));
  if (points.length != drawing.anchors.length) {
    throw ArgumentError.value(
      values,
      'controlPoints',
      'Must contain exactly one point for every drawing anchor.',
    );
  }
  for (var index = 0; index < points.length; index++) {
    final point = points[index];
    if (point.drawingId != drawing.id || point.anchorIndex != index) {
      throw ArgumentError.value(
        values,
        'controlPoints',
        'Points must belong to ${drawing.id} and use consecutive anchor indexes.',
      );
    }
  }
  return points;
}

ChartDrawingHit? _nearestControlPoint({
  required ChartDrawing drawing,
  required List<ChartDrawingControlPoint> points,
  required double localX,
  required double localY,
  required double tolerance,
}) {
  ChartDrawingControlPoint? nearest;
  var nearestDistance = double.infinity;
  for (final point in points) {
    final distance = _pointDistance(localX, localY, point.localX, point.localY);
    if (distance <= tolerance && distance < nearestDistance) {
      nearest = point;
      nearestDistance = distance;
    }
  }
  if (nearest == null) return null;
  return ChartDrawingHit(
    drawing: drawing,
    kind: ChartDrawingHitKind.controlPoint,
    distance: nearestDistance,
    anchorIndex: nearest.anchorIndex,
  );
}

double _bodyDistance(
  ChartDrawingKind kind,
  List<ChartDrawingControlPoint> points,
  double localX,
  double localY,
) =>
    switch (kind) {
      ChartDrawingKind.horizontalLine => (localY - points.first.localY).abs(),
      ChartDrawingKind.verticalLine => (localX - points.first.localX).abs(),
      ChartDrawingKind.ray => _rayDistance(
          localX,
          localY,
          points.first,
          points[1],
        ),
      ChartDrawingKind.rectangle => _rectangleDistance(
          localX,
          localY,
          points.first,
          points[1],
        ),
      ChartDrawingKind.text || ChartDrawingKind.priceMarker => double.infinity,
      _ => _polylineDistance(localX, localY, points),
    };

double _polylineDistance(
  double localX,
  double localY,
  List<ChartDrawingControlPoint> points,
) {
  var minimum = double.infinity;
  for (var index = 1; index < points.length; index++) {
    minimum = _min(
      minimum,
      _segmentDistance(localX, localY, points[index - 1], points[index]),
    );
  }
  return minimum;
}

double _rayDistance(
  double localX,
  double localY,
  ChartDrawingControlPoint start,
  ChartDrawingControlPoint through,
) {
  final deltaX = through.localX - start.localX;
  final deltaY = through.localY - start.localY;
  final lengthSquared = deltaX * deltaX + deltaY * deltaY;
  if (lengthSquared == 0) {
    return _pointDistance(localX, localY, start.localX, start.localY);
  }
  final projection =
      ((localX - start.localX) * deltaX + (localY - start.localY) * deltaY) /
          lengthSquared;
  if (projection <= 0) {
    return _pointDistance(localX, localY, start.localX, start.localY);
  }
  return _pointDistance(
    localX,
    localY,
    start.localX + projection * deltaX,
    start.localY + projection * deltaY,
  );
}

double _rectangleDistance(
  double localX,
  double localY,
  ChartDrawingControlPoint first,
  ChartDrawingControlPoint second,
) {
  final topLeft = ChartDrawingControlPoint(
    drawingId: first.drawingId,
    anchorIndex: first.anchorIndex,
    localX: _min(first.localX, second.localX),
    localY: _min(first.localY, second.localY),
  );
  final topRight = ChartDrawingControlPoint(
    drawingId: first.drawingId,
    anchorIndex: first.anchorIndex,
    localX: _max(first.localX, second.localX),
    localY: _min(first.localY, second.localY),
  );
  final bottomLeft = ChartDrawingControlPoint(
    drawingId: first.drawingId,
    anchorIndex: first.anchorIndex,
    localX: _min(first.localX, second.localX),
    localY: _max(first.localY, second.localY),
  );
  final bottomRight = ChartDrawingControlPoint(
    drawingId: first.drawingId,
    anchorIndex: first.anchorIndex,
    localX: _max(first.localX, second.localX),
    localY: _max(first.localY, second.localY),
  );
  return _min(
    _min(
      _segmentDistance(localX, localY, topLeft, topRight),
      _segmentDistance(localX, localY, topLeft, bottomLeft),
    ),
    _min(
      _segmentDistance(localX, localY, bottomLeft, bottomRight),
      _segmentDistance(localX, localY, topRight, bottomRight),
    ),
  );
}

double _segmentDistance(
  double localX,
  double localY,
  ChartDrawingControlPoint start,
  ChartDrawingControlPoint end,
) {
  final deltaX = end.localX - start.localX;
  final deltaY = end.localY - start.localY;
  final lengthSquared = deltaX * deltaX + deltaY * deltaY;
  if (lengthSquared == 0) {
    return _pointDistance(localX, localY, start.localX, start.localY);
  }
  final projection = _clamp(
    ((localX - start.localX) * deltaX + (localY - start.localY) * deltaY) /
        lengthSquared,
    0,
    1,
  );
  return _pointDistance(
    localX,
    localY,
    start.localX + projection * deltaX,
    start.localY + projection * deltaY,
  );
}

double _pointDistance(
  double firstX,
  double firstY,
  double secondX,
  double secondY,
) {
  final deltaX = firstX - secondX;
  final deltaY = firstY - secondY;
  return math.sqrt(deltaX * deltaX + deltaY * deltaY);
}

double _clamp(double value, double minimum, double maximum) =>
    value.clamp(minimum, maximum).toDouble();

double _min(double first, double second) => first < second ? first : second;
double _max(double first, double second) => first > second ? first : second;

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}

void _requireNonNegativeFinite(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and non-negative.');
  }
}
