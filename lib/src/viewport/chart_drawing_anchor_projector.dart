import '../drawing/drawing.dart';
import 'chart_price_transform.dart';
import 'chart_x_transform.dart';

/// Projects time/price drawing anchors to one panel's chart-local coordinates.
///
/// [localXOffset] lets a host account for a panel's left plot inset while the
/// [ChartXTransform] continues to describe the drawable plot itself.
final class ChartDrawingAnchorProjector {
  const ChartDrawingAnchorProjector._();

  static List<ChartDrawingControlPoint> project({
    required ChartDrawing drawing,
    required ChartXTransform xTransform,
    required ChartPriceTransform priceTransform,
    double localXOffset = 0,
  }) {
    if (!localXOffset.isFinite) {
      throw ArgumentError.value(
        localXOffset,
        'localXOffset',
        'Must be finite.',
      );
    }
    if (xTransform.isEmpty) return const [];
    return List<ChartDrawingControlPoint>.unmodifiable([
      for (var index = 0; index < drawing.anchors.length; index++)
        ChartDrawingControlPoint(
          drawingId: drawing.id,
          anchorIndex: index,
          localX: xTransform.timeToLocalX(
                drawing.anchors[index].epochMilliseconds,
              ) +
              localXOffset,
          localY: priceTransform.priceToLocalY(drawing.anchors[index].price),
        ),
    ]);
  }
}
