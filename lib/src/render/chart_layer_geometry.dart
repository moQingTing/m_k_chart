import 'dart:math' as math;

import '../viewport/viewport.dart';
import 'chart_candle_projection.dart';
import 'chart_main_mode.dart';
import 'render_snapshot.dart';

final class ChartPanelValueRange {
  const ChartPanelValueRange(this.min, this.max);

  final double min;
  final double max;

  ChartPriceTransform transform(ChartLayoutRect bounds) => ChartPriceTransform(
        minPrice: min,
        maxPrice: max,
        top: bounds.top,
        bottom: bounds.bottom,
      );
}

final class ChartVisibleMainExtrema {
  const ChartVisibleMainExtrema({
    required this.maxIndex,
    required this.minIndex,
    required this.max,
    required this.min,
  });

  final int maxIndex;
  final int minIndex;
  final double max;
  final double min;
}

abstract final class ChartLayerGeometry {
  static ChartPanelValueRange rangeFor<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
    String panelId, {
    ChartVisibleMainExtrema? mainExtrema,
  }) {
    final panel = snapshot.layout.panel(panelId);
    final range = snapshot.viewport.visibleRange;
    double? minimum;
    double? maximum;

    void include(double value) {
      minimum = minimum == null ? value : math.min(minimum!, value);
      maximum = maximum == null ? value : math.max(maximum!, value);
    }

    if (panel.spec.kind == ChartPanelKind.main) {
      final extrema = mainExtrema ?? visibleMainExtrema(snapshot);
      if (extrema != null) {
        include(extrema.min);
        include(extrema.max);
      }
    }

    for (final indicator in snapshot.indicators) {
      if (indicator.panelId != panelId) {
        continue;
      }
      if (panel.spec.kind == ChartPanelKind.main &&
          !snapshot.mainMode.showsMainIndicators) {
        continue;
      }
      if (indicator.descriptor.includeZeroInRange) {
        include(0);
      }
      for (final descriptor in indicator.descriptor.series) {
        if (!descriptor.includeInRange) {
          continue;
        }
        final series = indicator.seriesById(descriptor.id)!;
        for (var index = range.start; index < range.end; index++) {
          final value = series.values[index];
          if (value != null) {
            include(value);
          }
        }
      }
    }

    if (minimum == null || maximum == null) {
      return const ChartPanelValueRange(0, 1);
    }
    if (minimum == maximum) {
      final padding = minimum!.abs() * 0.01;
      final resolvedPadding = padding > 0 ? padding : 1.0;
      return ChartPanelValueRange(
        minimum! - resolvedPadding,
        maximum! + resolvedPadding,
      );
    }
    final padding = (maximum! - minimum!) * 0.05;
    return ChartPanelValueRange(minimum! - padding, maximum! + padding);
  }

  static ChartVisibleMainExtrema? visibleMainExtrema<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot, {
    ChartCandleProjection? candles,
  }) {
    final range = snapshot.viewport.visibleRange;
    if (range.isEmpty) {
      return null;
    }
    var maxIndex = range.start;
    var minIndex = range.start;
    final values = candles ??
        ChartCandleProjection.fromKlines(
          source: snapshot.data.data,
          mode: snapshot.mainMode,
        );
    double maximumAt(int index) => snapshot.mainMode.isCandleMode
        ? values.candles[index].high
        : values.candles[index].close;
    double minimumAt(int index) => snapshot.mainMode.isCandleMode
        ? values.candles[index].low
        : values.candles[index].close;
    for (var index = range.start + 1; index < range.end; index++) {
      if (maximumAt(index) > maximumAt(maxIndex)) {
        maxIndex = index;
      }
      if (minimumAt(index) < minimumAt(minIndex)) {
        minIndex = index;
      }
    }
    return ChartVisibleMainExtrema(
      maxIndex: maxIndex,
      minIndex: minIndex,
      max: maximumAt(maxIndex),
      min: minimumAt(minIndex),
    );
  }
}
