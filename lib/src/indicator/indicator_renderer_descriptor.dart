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

/// 参数栏展示策略。趋势指标可只显示当前非空的一条序列。
enum IndicatorLegendDisplay { allSeries, firstAvailable }

/// 指标定义提供的参数栏元数据，不依赖 Widget 或具体颜色。
///
/// 模板中的 `{参数键}` 从同一定义的参数配置或默认值读取；未声明模板时沿用序列标签。
final class IndicatorLegendDescriptor {
  IndicatorLegendDescriptor({
    this.display = IndicatorLegendDisplay.allSeries,
    Map<String, String> labelTemplates = const {},
    this.separator = ': ',
    this.neutralLabel = false,
  }) : labelTemplates = Map.unmodifiable(labelTemplates) {
    for (final entry in labelTemplates.entries) {
      _requireDescriptorText(entry.key, 'labelTemplates key');
      _requireDescriptorText(entry.value, 'labelTemplates value');
    }
    if (separator.isEmpty) {
      throw ArgumentError.value(separator, 'separator', 'Must not be empty.');
    }
  }

  final IndicatorLegendDisplay display;
  final Map<String, String> labelTemplates;
  final String separator;
  final bool neutralLabel;
}

/// Renderer-neutral description of one calculated series.
final class IndicatorSeriesDescriptor {
  IndicatorSeriesDescriptor({
    required this.id,
    required this.label,
    required this.drawingKind,
    this.includeInRange = true,
    this.showInChart = true,
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

  /// 算法可保留兼容输出，但候选图表和设置页不提供这条序列。
  final bool showInChart;
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
    IndicatorLegendDescriptor? legend,
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
    if (!immutableSeries.any((item) => item.showInChart)) {
      throw ArgumentError('At least one chart-visible series is required.');
    }
    for (final seriesId in legend?.labelTemplates.keys ?? const <String>[]) {
      if (!ids.contains(seriesId)) {
        throw ArgumentError.value(seriesId, 'legend', 'Unknown series id.');
      }
    }
    return IndicatorRendererDescriptor._(
      placement: placement,
      series: immutableSeries,
      includeZeroInRange: includeZeroInRange,
      legend: legend ?? IndicatorLegendDescriptor(),
    );
  }

  const IndicatorRendererDescriptor._({
    required this.placement,
    required this.series,
    required this.includeZeroInRange,
    required this.legend,
  });

  final IndicatorPlacement placement;
  final List<IndicatorSeriesDescriptor> series;
  final bool includeZeroInRange;
  final IndicatorLegendDescriptor legend;
}

void _requireDescriptorText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}
