import 'dart:math' as math;
import 'dart:ui';

import '../model/chart_overlay.dart';
import '../viewport/viewport.dart';
import 'chart_layer_geometry.dart';
import 'render_snapshot.dart';

enum ChartTradeOverlayKind { priceLine, valueMarker, event }

enum ChartTradeOverlayInteractionType {
  tap,
  dragStart,
  dragUpdate,
  dragEnd,
  action,
}

final class ChartTradeOverlayHit {
  factory ChartTradeOverlayHit({
    required String id,
    required ChartTradeOverlayKind kind,
    required ChartOverlaySide side,
    required double price,
    required double distance,
    int? epochMilliseconds,
  }) {
    if (id.trim().isEmpty ||
        !price.isFinite ||
        !distance.isFinite ||
        distance < 0 ||
        (epochMilliseconds != null && epochMilliseconds < 0)) {
      throw ArgumentError('Invalid trade overlay hit.');
    }
    if ((kind == ChartTradeOverlayKind.event) != (epochMilliseconds != null)) {
      throw ArgumentError('Only event hits require an event timestamp.');
    }
    return ChartTradeOverlayHit._(
      id: id,
      kind: kind,
      side: side,
      price: price,
      distance: distance,
      epochMilliseconds: epochMilliseconds,
    );
  }

  const ChartTradeOverlayHit._({
    required this.id,
    required this.kind,
    required this.side,
    required this.price,
    required this.distance,
    required this.epochMilliseconds,
  });

  final String id;
  final ChartTradeOverlayKind kind;
  final ChartOverlaySide side;
  final double price;
  final double distance;
  final int? epochMilliseconds;
}

final class ChartTradeOverlayInteraction {
  factory ChartTradeOverlayInteraction({
    required ChartTradeOverlayHit hit,
    required ChartTradeOverlayInteractionType type,
    double? price,
    String? actionId,
  }) {
    final resolvedPrice = price ?? hit.price;
    if (!resolvedPrice.isFinite) {
      throw ArgumentError.value(price, 'price', 'Must be finite.');
    }
    final hasAction = actionId != null && actionId.trim().isNotEmpty;
    if ((type == ChartTradeOverlayInteractionType.action) != hasAction) {
      throw ArgumentError('Action interactions require one non-empty action.');
    }
    return ChartTradeOverlayInteraction._(
      hit: hit,
      type: type,
      price: resolvedPrice,
      actionId: actionId,
    );
  }

  const ChartTradeOverlayInteraction._({
    required this.hit,
    required this.type,
    required this.price,
    required this.actionId,
  });

  final ChartTradeOverlayHit hit;
  final ChartTradeOverlayInteractionType type;
  final double price;
  final String? actionId;
}

abstract final class ChartTradeOverlayHitTester {
  static ChartTradeOverlayHit? hitTest<TTheme extends Object>({
    required RenderSnapshot<TTheme> snapshot,
    required Offset localPosition,
    double tolerance = 10,
    double markerHitWidth = 80,
  }) {
    if (!localPosition.dx.isFinite || !localPosition.dy.isFinite) {
      throw ArgumentError.value(localPosition, 'localPosition');
    }
    _requireNonNegativeFinite(tolerance, 'tolerance');
    _requireNonNegativeFinite(markerHitWidth, 'markerHitWidth');
    if (snapshot.data.data.isEmpty) return null;
    final panel = snapshot.layout.mainPanel.bounds;
    if (!panel.contains(x: localPosition.dx, y: localPosition.dy)) return null;
    final priceTransform = ChartLayerGeometry.rangeFor(snapshot, 'main')
        .transform(snapshot.layout.mainPanel.bounds);
    final xTransform = ChartXTransform(
      viewport: snapshot.viewport,
      data: snapshot.data,
    );
    ChartTradeOverlayHit? nearest;

    void consider(ChartTradeOverlayHit hit) {
      if (hit.distance <= tolerance &&
          (nearest == null || hit.distance <= nearest!.distance)) {
        nearest = hit;
      }
    }

    for (final line in snapshot.priceLines) {
      if (!line.visible) continue;
      consider(
        ChartTradeOverlayHit(
          id: line.id,
          kind: ChartTradeOverlayKind.priceLine,
          side: line.side,
          price: line.price,
          distance:
              (localPosition.dy - priceTransform.priceToLocalY(line.price))
                  .abs(),
        ),
      );
    }
    if (localPosition.dx >= panel.right - markerHitWidth) {
      for (final marker in snapshot.valueMarkers) {
        consider(
          ChartTradeOverlayHit(
            id: marker.id,
            kind: ChartTradeOverlayKind.valueMarker,
            side: marker.side,
            price: marker.price,
            distance:
                (localPosition.dy - priceTransform.priceToLocalY(marker.price))
                    .abs(),
          ),
        );
      }
    }
    final visible = snapshot.viewport.visibleRange;
    if (visible.isNotEmpty) {
      final firstTime = snapshot.data.data[visible.start].openTime;
      final lastTime = snapshot.data.data[visible.end - 1].openTime;
      for (final event in snapshot.eventOverlays) {
        if (event.epochMilliseconds < firstTime ||
            event.epochMilliseconds > lastTime) {
          continue;
        }
        final eventPosition = Offset(
          xTransform.timeToLocalX(event.epochMilliseconds) +
              snapshot.layout.drawingBounds.left,
          priceTransform.priceToLocalY(event.price),
        );
        consider(
          ChartTradeOverlayHit(
            id: event.id,
            kind: ChartTradeOverlayKind.event,
            side: event.side,
            price: event.price,
            distance: math.sqrt(
              math.pow(localPosition.dx - eventPosition.dx, 2) +
                  math.pow(localPosition.dy - eventPosition.dy, 2),
            ),
            epochMilliseconds: event.epochMilliseconds,
          ),
        );
      }
    }
    return nearest;
  }
}

void _requireNonNegativeFinite(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and non-negative.');
  }
}
