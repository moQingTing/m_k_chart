import 'dart:ui';

/// Minimal immutable visual contract consumed by Phase 5 Layers.
///
/// P6 will provide the complete public KChartTheme on top of this interface.
abstract interface class ChartRenderStyle {
  Color get backgroundColor;
  Color get gridColor;
  Color get axisTextColor;
  Color get upColor;
  Color get downColor;
  Color get markerColor;
  Color get crosshairColor;
  Color get drawingColor;
  Color get mainLineColor;
  List<Color> get areaFillColors;
  double get gridStrokeWidth;
  double get dataStrokeWidth;
  double get mainLineStrokeWidth;
  double get indicatorStrokeWidth;
  double get overlayStrokeWidth;
  double get axisFontSize;
  double get candleWidthRatio;
  double get histogramWidthRatio;
  double get indicatorPointRadius;

  Color indicatorColor(String instanceId, String seriesId);
}

/// Deterministic internal style used until P6 freezes KChartTheme.
final class DefaultChartRenderStyle implements ChartRenderStyle {
  factory DefaultChartRenderStyle({
    Color backgroundColor = const Color(0xff0b0e11),
    Color gridColor = const Color(0xff2b3139),
    Color axisTextColor = const Color(0xff848e9c),
    Color upColor = const Color(0xff0ecb81),
    Color downColor = const Color(0xfff6465d),
    Color markerColor = const Color(0xfff0b90b),
    Color crosshairColor = const Color(0xffb7bdc6),
    Color drawingColor = const Color(0xff8a70d6),
    Color mainLineColor = const Color(0xff38e5cc),
    Iterable<Color> areaFillColors = const [
      Color(0x9938e5cc),
      Color(0x1a38e5cc),
    ],
    Iterable<Color> indicatorPalette = const [
      Color(0xfff0b90b),
      Color(0xff8a70d6),
      Color(0xff2ebd85),
      Color(0xff1e80ff),
      Color(0xffe377c2),
      Color(0xffff8f00),
    ],
    double gridStrokeWidth = 1,
    double dataStrokeWidth = 1,
    double mainLineStrokeWidth = 1.5,
    double indicatorStrokeWidth = 1.5,
    double overlayStrokeWidth = 1,
    double axisFontSize = 10,
    double candleWidthRatio = 0.75,
    double histogramWidthRatio = 0.8,
    double indicatorPointRadius = 2,
  }) {
    final palette = List<Color>.unmodifiable(indicatorPalette);
    final fillColors = List<Color>.unmodifiable(areaFillColors);
    if (palette.isEmpty) {
      throw ArgumentError('indicatorPalette must not be empty.');
    }
    if (fillColors.length < 2) {
      throw ArgumentError('areaFillColors must contain at least two colors.');
    }
    final widths = <String, double>{
      'gridStrokeWidth': gridStrokeWidth,
      'dataStrokeWidth': dataStrokeWidth,
      'mainLineStrokeWidth': mainLineStrokeWidth,
      'indicatorStrokeWidth': indicatorStrokeWidth,
      'overlayStrokeWidth': overlayStrokeWidth,
      'axisFontSize': axisFontSize,
      'indicatorPointRadius': indicatorPointRadius,
    };
    for (final entry in widths.entries) {
      if (!entry.value.isFinite || entry.value <= 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must be finite and positive.',
        );
      }
    }
    for (final entry in <String, double>{
      'candleWidthRatio': candleWidthRatio,
      'histogramWidthRatio': histogramWidthRatio,
    }.entries) {
      if (!entry.value.isFinite || entry.value <= 0 || entry.value > 1) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must be finite, positive, and at most one.',
        );
      }
    }
    return DefaultChartRenderStyle._(
      backgroundColor: backgroundColor,
      gridColor: gridColor,
      axisTextColor: axisTextColor,
      upColor: upColor,
      downColor: downColor,
      markerColor: markerColor,
      crosshairColor: crosshairColor,
      drawingColor: drawingColor,
      mainLineColor: mainLineColor,
      areaFillColors: fillColors,
      indicatorPalette: palette,
      gridStrokeWidth: gridStrokeWidth,
      dataStrokeWidth: dataStrokeWidth,
      mainLineStrokeWidth: mainLineStrokeWidth,
      indicatorStrokeWidth: indicatorStrokeWidth,
      overlayStrokeWidth: overlayStrokeWidth,
      axisFontSize: axisFontSize,
      candleWidthRatio: candleWidthRatio,
      histogramWidthRatio: histogramWidthRatio,
      indicatorPointRadius: indicatorPointRadius,
    );
  }

  const DefaultChartRenderStyle._({
    required this.backgroundColor,
    required this.gridColor,
    required this.axisTextColor,
    required this.upColor,
    required this.downColor,
    required this.markerColor,
    required this.crosshairColor,
    required this.drawingColor,
    required this.mainLineColor,
    required this.areaFillColors,
    required this.indicatorPalette,
    required this.gridStrokeWidth,
    required this.dataStrokeWidth,
    required this.mainLineStrokeWidth,
    required this.indicatorStrokeWidth,
    required this.overlayStrokeWidth,
    required this.axisFontSize,
    required this.candleWidthRatio,
    required this.histogramWidthRatio,
    required this.indicatorPointRadius,
  });

  @override
  final Color backgroundColor;
  @override
  final Color gridColor;
  @override
  final Color axisTextColor;
  @override
  final Color upColor;
  @override
  final Color downColor;
  @override
  final Color markerColor;
  @override
  final Color crosshairColor;
  @override
  final Color drawingColor;
  @override
  final Color mainLineColor;
  @override
  final List<Color> areaFillColors;
  final List<Color> indicatorPalette;
  @override
  final double gridStrokeWidth;
  @override
  final double dataStrokeWidth;
  @override
  final double mainLineStrokeWidth;
  @override
  final double indicatorStrokeWidth;
  @override
  final double overlayStrokeWidth;
  @override
  final double axisFontSize;
  @override
  final double candleWidthRatio;
  @override
  final double histogramWidthRatio;
  @override
  final double indicatorPointRadius;

  @override
  Color indicatorColor(String instanceId, String seriesId) {
    var hash = 17;
    for (final codeUnit in '$instanceId:$seriesId'.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return indicatorPalette[hash % indicatorPalette.length];
  }
}
