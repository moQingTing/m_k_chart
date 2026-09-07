import '../model/model.dart';
import 'chart_viewport.dart';

/// Immutable horizontal transform between data slots, chart-local X, and time.
///
/// Data slot `i` occupies `[i, i + 1]` and its Kline center is `i + 0.5`.
/// Local X is always relative to the chart's own drawable area. Time mapping
/// interpolates actual Kline open times instead of assuming a fixed interval.
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

  /// Returns the slot under [localX], clamped to the available data.
  ///
  /// A coordinate exactly on a slot boundary selects the newer/right slot.
  int localXToNearestIndex(double localX) {
    if (isEmpty) {
      throw StateError('Cannot select an index from empty Kline data.');
    }
    final index = localXToDataPosition(localX).floor();
    return index.clamp(0, data.data.length - 1);
  }

  /// Maps UTC epoch milliseconds to the continuous center coordinate.
  ///
  /// Values outside the data timeline clamp to the first or last center.
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

  /// Maps a continuous center coordinate back to UTC epoch milliseconds.
  ///
  /// Positions outside the first/last centers clamp to the data timeline.
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
