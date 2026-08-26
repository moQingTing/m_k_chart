enum IndicatorPlacement { mainChart, separatePanel }

enum IndicatorDrawingKind { line, histogram, points }

enum IndicatorColorStrategy {
  series,
  candleDirection,
  valueSign,
  pricePosition,
}

enum IndicatorHistogramStyle {
  solid,
  valueTrend,
}

/// Renderer-neutral description of one calculated series.
final class IndicatorSeriesDescriptor {
  IndicatorSeriesDescriptor({
    required this.id,
    required this.label,
    required this.drawingKind,
    this.includeInRange = true,
    this.colorStrategy = IndicatorColorStrategy.series,
    this.histogramStyle = IndicatorHistogramStyle.solid,
  }) {
    _requireDescriptorText(id, 'id');
    _requireDescriptorText(label, 'label');
    if (drawingKind == IndicatorDrawingKind.line &&
        colorStrategy != IndicatorColorStrategy.series) {
      throw ArgumentError('Line Series must use the series color strategy.');
    }
    if (drawingKind != IndicatorDrawingKind.histogram &&
        histogramStyle != IndicatorHistogramStyle.solid) {
      throw ArgumentError(
        'Only histogram Series can use a non-solid histogram style.',
      );
    }
  }

  final String id;
  final String label;
  final IndicatorDrawingKind drawingKind;
  final bool includeInRange;
  final IndicatorColorStrategy colorStrategy;
  final IndicatorHistogramStyle histogramStyle;
}

/// Declarative drawing contract. It deliberately contains no Canvas or Color.
final class IndicatorRendererDescriptor {
  factory IndicatorRendererDescriptor({
    required IndicatorPlacement placement,
    required Iterable<IndicatorSeriesDescriptor> series,
    bool includeZeroInRange = false,
  }) {
    final immutableSeries =
        List<IndicatorSeriesDescriptor>.unmodifiable(series);
    if (immutableSeries.isEmpty) {
      throw ArgumentError('At least one series descriptor is required.');
    }
    final ids = <String>{};
    for (final item in immutableSeries) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'series', 'Duplicate series id.');
      }
    }
    return IndicatorRendererDescriptor._(
      placement: placement,
      series: immutableSeries,
      includeZeroInRange: includeZeroInRange,
    );
  }

  const IndicatorRendererDescriptor._({
    required this.placement,
    required this.series,
    required this.includeZeroInRange,
  });

  final IndicatorPlacement placement;
  final List<IndicatorSeriesDescriptor> series;
  final bool includeZeroInRange;
}

void _requireDescriptorText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}
