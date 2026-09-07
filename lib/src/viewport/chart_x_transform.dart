import '../model/model.dart';
import 'chart_viewport.dart';

/// 数据槽位、图表局部 X 坐标与时间之间的不可变横向转换器。
///
/// 槽位 `i` 占据 `[i, i + 1]`，其 K 线中心为 `i + 0.5`。局部 X 始终相对于图表自身
/// 绘图区域；时间映射插值实际开盘时间，而非假设数据周期恒定。
final class ChartXTransform {
  factory ChartXTransform({
    required ChartViewport viewport,
    required VersionedKlineData data,
  }) {
    if (viewport.itemCount != data.data.length) {
      throw ArgumentError(
        'Viewport itemCount (${viewport.itemCount}) must match data length '
        '(${data.data.length}).',
      );
    }
    _validateOrdered(data.data);
    return ChartXTransform._(viewport: viewport, data: data);
  }

  const ChartXTransform._({
    required this.viewport,
    required this.data,
  });

  final ChartViewport viewport;
  final VersionedKlineData data;

  bool get isEmpty => data.data.isEmpty;

  double dataPositionToLocalX(double dataPosition) {
    _requireFinite(dataPosition, 'dataPosition');
    return (dataPosition - viewport.visibleLeftDataPosition) *
        viewport.itemExtent;
  }

  double localXToDataPosition(double localX) {
    _requireFinite(localX, 'localX');
    return viewport.visibleLeftDataPosition + localX / viewport.itemExtent;
  }

  double indexToLocalX(int index) {
    if (index < 0 || index >= data.data.length) {
      throw RangeError.index(index, data.data, 'index');
    }
    return dataPositionToLocalX(index + 0.5);
  }

  /// 返回 [localX] 下的槽位，并夹取到已有数据范围。
  ///
  /// 恰好落在槽位边界的坐标选择较新（右侧）的数据。
  int localXToNearestIndex(double localX) {
    if (isEmpty) {
      throw StateError('Cannot select an index from empty Kline data.');
    }
    final index = localXToDataPosition(localX).floor();
    return index.clamp(0, data.data.length - 1);
  }

  /// 将 UTC epoch 毫秒映射为连续的 K 线中心坐标。
  ///
  /// 数据时间线之外的值会夹取到首根或末根中心。
  double timeToDataPosition(int epochMilliseconds) {
    final values = data.data;
    if (values.isEmpty) {
      throw StateError('Cannot map time with empty Kline data.');
    }
    if (epochMilliseconds <= values.first.openTime) {
      return 0.5;
    }
    if (epochMilliseconds >= values.last.openTime) {
      return values.length - 0.5;
    }

    final upper = _lowerBoundTime(values, epochMilliseconds);
    final lower = upper - 1;
    final lowerTime = values[lower].openTime;
    final upperTime = values[upper].openTime;
    final fraction = (epochMilliseconds - lowerTime) / (upperTime - lowerTime);
    return lower + 0.5 + fraction;
  }

  /// 将连续中心坐标映射回 UTC epoch 毫秒。
  ///
  /// 首尾 K 线中心之外的位置会夹取到数据时间线。
  int dataPositionToTime(double dataPosition) {
    _requireFinite(dataPosition, 'dataPosition');
    final values = data.data;
    if (values.isEmpty) {
      throw StateError('Cannot map time with empty Kline data.');
    }

    final centered = (dataPosition - 0.5).clamp(0, values.length - 1);
    final lower = centered.floor();
    if (lower == values.length - 1) {
      return values.last.openTime;
    }
    final fraction = centered - lower;
    final lowerTime = values[lower].openTime;
    final upperTime = values[lower + 1].openTime;
    return (lowerTime + (upperTime - lowerTime) * fraction).round();
  }

  double timeToLocalX(int epochMilliseconds) =>
      dataPositionToLocalX(timeToDataPosition(epochMilliseconds));

  int localXToTime(double localX) =>
      dataPositionToTime(localXToDataPosition(localX));
}

void _validateOrdered(List<Kline> values) {
  for (var index = 1; index < values.length; index++) {
    if (values[index].openTime <= values[index - 1].openTime) {
      throw ArgumentError('Kline data must be strictly ordered by openTime.');
    }
  }
}

int _lowerBoundTime(List<Kline> values, int epochMilliseconds) {
  var low = 0;
  var high = values.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (values[middle].openTime < epochMilliseconds) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}
