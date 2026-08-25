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

abstract final class ChartLayerGeometry {
  static ChartPanelValueRange rangeFor<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
    String panelId,
  ) {
    final panel = snapshot.layout.panel(panelId);
    final range = snapshot.viewport.visibleRange;
    double? minimum;
    double? maximum;

    void include(double value) {
      minimum = minimum == null ? value : math.min(minimum!, value);
      maximum = maximum == null ? value : math.max(maximum!, value);
    }

    if (panel.spec.kind == ChartPanelKind.main) {
      for (var index = range.start; index < range.end; index++) {
        final candle = snapshot.data.data[index];
        include(candle.low);
        include(candle.high);
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
}
