import 'dart:math' as math;

import '../viewport/viewport.dart';
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

final class ChartVisibleOhlcExtrema {
  const ChartVisibleOhlcExtrema({
    required this.highIndex,
    required this.lowIndex,
    required this.high,
    required this.low,
  });

  final int highIndex;
  final int lowIndex;
  final double high;
  final double low;
}

abstract final class ChartLayerGeometry {
  static ChartPanelValueRange rangeFor<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
    String panelId, {
    ChartVisibleOhlcExtrema? ohlcExtrema,
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
      final extrema = ohlcExtrema ?? visibleOhlcExtrema(snapshot);
      if (extrema != null) {
        include(extrema.low);
        include(extrema.high);
      }
    }

    for (final indicator in snapshot.indicators) {
      if (indicator.panelId != panelId) {
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

  static ChartVisibleOhlcExtrema? visibleOhlcExtrema<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
  ) {
    final range = snapshot.viewport.visibleRange;
    if (range.isEmpty) {
      return null;
    }
    var highIndex = range.start;
    var lowIndex = range.start;
    for (var index = range.start + 1; index < range.end; index++) {
      if (snapshot.data.data[index].high > snapshot.data.data[highIndex].high) {
        highIndex = index;
      }
      if (snapshot.data.data[index].low < snapshot.data.data[lowIndex].low) {
        lowIndex = index;
      }
    }
    return ChartVisibleOhlcExtrema(
      highIndex: highIndex,
      lowIndex: lowIndex,
      high: snapshot.data.data[highIndex].high,
      low: snapshot.data.data[lowIndex].low,
    );
  }
}
