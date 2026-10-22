import '../model/model.dart';
import '../viewport/viewport.dart';

enum ChartOhlcField {
  open,
  high,
  low,
  close,
}

final class ChartOhlcSnapResult {
  const ChartOhlcSnapResult({
    required this.dataIndex,
    required this.field,
    required this.price,
    required this.localX,
    required this.localY,
  });

  final int dataIndex;
  final ChartOhlcField field;
  final double price;
  final double localX;
  final double localY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartOhlcSnapResult &&
          dataIndex == other.dataIndex &&
          field == other.field &&
          price == other.price &&
          localX == other.localX &&
          localY == other.localY;

  @override
  int get hashCode => Object.hash(dataIndex, field, price, localX, localY);
}

/// Snaps a chart-local point to one candle center and its nearest OHLC price.
abstract final class ChartOhlcSnapper {
  static ChartOhlcSnapResult snap({
    required VersionedKlineData data,
    required ChartViewport viewport,
    required ChartPriceTransform priceTransform,
    required double localX,
    required double localY,
  }) {
    if (!localX.isFinite || !localY.isFinite) {
      throw ArgumentError('localX and localY must be finite.');
    }
    final xTransform = ChartXTransform(viewport: viewport, data: data);
    final index = xTransform.localXToNearestIndex(localX);
    final candle = data.data[index];
    final candidates = <(ChartOhlcField, double)>[
      (ChartOhlcField.open, candle.open),
      (ChartOhlcField.high, candle.high),
      (ChartOhlcField.low, candle.low),
      (ChartOhlcField.close, candle.close),
    ];
    var nearest = candidates.first;
    var nearestY = priceTransform.priceToLocalY(nearest.$2);
    var nearestDistance = (nearestY - localY).abs();
    for (final candidate in candidates.skip(1)) {
      final candidateY = priceTransform.priceToLocalY(candidate.$2);
      final distance = (candidateY - localY).abs();
      if (distance < nearestDistance) {
        nearest = candidate;
        nearestY = candidateY;
        nearestDistance = distance;
      }
    }
    return ChartOhlcSnapResult(
      dataIndex: index,
      field: nearest.$1,
      price: nearest.$2,
      localX: xTransform.indexToLocalX(index),
      localY: nearestY,
    );
  }
}
