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

/// The geometry used to connect adjacent values in a line series.
enum IndicatorLineStyle {
  straight,
  stepped,
}

/// Optional lower/upper boundary used to create an area behind a line series.
///
/// [candleClose] is intended for price overlays such as Supertrend.  Each
/// contiguous run is closed against the corresponding K-line close values.
enum IndicatorAreaBaseline {
  none,
  candleClose,
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
    this.lineStyle = IndicatorLineStyle.straight,
    this.lineStrokeWidthMultiplier = 1,
    this.areaBaseline = IndicatorAreaBaseline.none,
    this.areaFillOpacity = 0.14,
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
    if (drawingKind != IndicatorDrawingKind.line &&
        lineStyle != IndicatorLineStyle.straight) {
      throw ArgumentError(
        'Only line Series can use a non-straight line style.',
      );
    }
    if (drawingKind != IndicatorDrawingKind.line &&
        areaBaseline != IndicatorAreaBaseline.none) {
      throw ArgumentError('Only line Series can use an area baseline.');
    }
    if (!lineStrokeWidthMultiplier.isFinite || lineStrokeWidthMultiplier <= 0) {
      throw ArgumentError.value(
        lineStrokeWidthMultiplier,
        'lineStrokeWidthMultiplier',
        'Must be finite and positive.',
      );
    }
    if (!areaFillOpacity.isFinite ||
        areaFillOpacity < 0 ||
        areaFillOpacity > 1) {
      throw ArgumentError.value(
        areaFillOpacity,
        'areaFillOpacity',
        'Must be a finite value between 0 and 1.',
      );
    }
  }

  final String id;
  final String label;
  final IndicatorDrawingKind drawingKind;
  final bool includeInRange;
  final IndicatorColorStrategy colorStrategy;
  final IndicatorHistogramStyle histogramStyle;
  final IndicatorLineStyle lineStyle;

  /// Multiplies the theme default line width unless the theme overrides this
  /// particular `instanceId:seriesId` with an absolute width.
  final double lineStrokeWidthMultiplier;
  final IndicatorAreaBaseline areaBaseline;
  final double areaFillOpacity;
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
