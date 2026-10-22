import '../model/model.dart';
import 'chart_drawing.dart';

enum ChartDrawingOutOfRangePolicy { preserve, clampToTimeline }

/// Restores time/price anchors after a period or dataset switch.
abstract final class ChartDrawingTimelineRestorer {
  static ChartDrawing restore({
    required ChartDrawing drawing,
    required List<Kline> data,
    ChartDrawingOutOfRangePolicy policy = ChartDrawingOutOfRangePolicy.preserve,
  }) {
    if (policy == ChartDrawingOutOfRangePolicy.preserve || data.isEmpty) {
      return drawing;
    }
    final first = data.first.openTime;
    final last = data.last.openTime;
    return drawing.copyWith(
      anchors: [
        for (final anchor in drawing.anchors)
          ChartDrawingAnchor(
            epochMilliseconds:
                anchor.epochMilliseconds.clamp(first, last).toInt(),
            price: anchor.price,
          ),
      ],
    );
  }
}
