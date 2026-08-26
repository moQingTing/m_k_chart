import 'dart:collection';
import 'dart:math' as math;

import '../model/model.dart';
import 'chart_main_mode.dart';

/// Immutable OHLC values consumed by a main-chart candle renderer.
final class ChartRenderCandle {
  const ChartRenderCandle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double open;
  final double high;
  final double low;
  final double close;
}

/// Immutable candle projection for one source Kline snapshot and main mode.
final class ChartCandleProjection {
  factory ChartCandleProjection.fromKlines({
    required List<Kline> source,
    required ChartMainMode mode,
  }) {
    final candles = mode.usesHeikinAshi
        ? _heikinAshi(source)
        : source
            .map(
              (item) => ChartRenderCandle(
                open: item.open,
                high: item.high,
                low: item.low,
                close: item.close,
              ),
            )
            .toList(growable: false);
    return ChartCandleProjection._(mode, UnmodifiableListView(candles));
  }

  const ChartCandleProjection._(this.mode, this.candles);

  final ChartMainMode mode;
  final List<ChartRenderCandle> candles;

  static List<ChartRenderCandle> _heikinAshi(List<Kline> source) {
    final projected = <ChartRenderCandle>[];
    for (final sourceCandle in source) {
      final close = (sourceCandle.open +
              sourceCandle.high +
              sourceCandle.low +
              sourceCandle.close) /
          4;
      final open = projected.isEmpty
          ? (sourceCandle.open + sourceCandle.close) / 2
          : (projected.last.open + projected.last.close) / 2;
      projected.add(
        ChartRenderCandle(
          open: open,
          high: math.max(sourceCandle.high, math.max(open, close)),
          low: math.min(sourceCandle.low, math.min(open, close)),
          close: close,
        ),
      );
    }
    return projected;
  }
}
