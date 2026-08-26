import 'dart:ui';

import 'src/theme/chart_render_style.dart';

/// Immutable visual configuration for the V2 chart renderer.
///
/// A theme is a value object: its collection properties are unmodifiable,
/// [copyWith] creates a new value, and structurally equal values compare equal.
/// This lets a chart host advance its `theme` version only when the visible
/// configuration actually changed.
final class KChartTheme implements ChartRenderStyle {
  factory KChartTheme({
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
    Map<String, Color> indicatorColors = const {},
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
    final colors = Map<String, Color>.unmodifiable(indicatorColors);
    if (palette.isEmpty) {
      throw ArgumentError('indicatorPalette must not be empty.');
    }
    if (fillColors.length < 2) {
      throw ArgumentError('areaFillColors must contain at least two colors.');
    }
    for (final entry in <String, double>{
      'gridStrokeWidth': gridStrokeWidth,
      'dataStrokeWidth': dataStrokeWidth,
      'mainLineStrokeWidth': mainLineStrokeWidth,
      'indicatorStrokeWidth': indicatorStrokeWidth,
      'overlayStrokeWidth': overlayStrokeWidth,
      'axisFontSize': axisFontSize,
      'indicatorPointRadius': indicatorPointRadius,
    }.entries) {
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
    for (final key in colors.keys) {
      if (key.trim().isEmpty) {
        throw ArgumentError.value(
          key,
          'indicatorColors',
          'Keys must not be empty.',
        );
      }
    }
    return KChartTheme._(
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
      indicatorColors: colors,
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

  const KChartTheme._({
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
    required this.indicatorColors,
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

  /// A light baseline suitable for applications that do not supply a theme.
  factory KChartTheme.light({
    Color upColor = const Color(0xff0ecb81),
    Color downColor = const Color(0xfff6465d),
  }) =>
      KChartTheme(
        backgroundColor: const Color(0xffffffff),
        gridColor: const Color(0xffe6e8ea),
        axisTextColor: const Color(0xff60738e),
        upColor: upColor,
        downColor: downColor,
        markerColor: const Color(0xff6c7a86),
        crosshairColor: const Color(0xff6c7a86),
        drawingColor: const Color(0xff8a70d6),
      );

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

  /// Explicit colors keyed as `instanceId:seriesId`.
  ///
  /// Entries take precedence over [indicatorPalette]; unspecified series use
  /// the stable palette hash so adding another series does not recolor peers.
  final Map<String, Color> indicatorColors;
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

  KChartTheme copyWith({
    Color? backgroundColor,
    Color? gridColor,
    Color? axisTextColor,
    Color? upColor,
    Color? downColor,
    Color? markerColor,
    Color? crosshairColor,
    Color? drawingColor,
    Color? mainLineColor,
    Iterable<Color>? areaFillColors,
    Iterable<Color>? indicatorPalette,
    Map<String, Color>? indicatorColors,
    double? gridStrokeWidth,
    double? dataStrokeWidth,
    double? mainLineStrokeWidth,
    double? indicatorStrokeWidth,
    double? overlayStrokeWidth,
    double? axisFontSize,
    double? candleWidthRatio,
    double? histogramWidthRatio,
    double? indicatorPointRadius,
  }) =>
      KChartTheme(
        backgroundColor: backgroundColor ?? this.backgroundColor,
        gridColor: gridColor ?? this.gridColor,
        axisTextColor: axisTextColor ?? this.axisTextColor,
        upColor: upColor ?? this.upColor,
        downColor: downColor ?? this.downColor,
        markerColor: markerColor ?? this.markerColor,
        crosshairColor: crosshairColor ?? this.crosshairColor,
        drawingColor: drawingColor ?? this.drawingColor,
        mainLineColor: mainLineColor ?? this.mainLineColor,
        areaFillColors: areaFillColors ?? this.areaFillColors,
        indicatorPalette: indicatorPalette ?? this.indicatorPalette,
        indicatorColors: indicatorColors ?? this.indicatorColors,
        gridStrokeWidth: gridStrokeWidth ?? this.gridStrokeWidth,
        dataStrokeWidth: dataStrokeWidth ?? this.dataStrokeWidth,
        mainLineStrokeWidth: mainLineStrokeWidth ?? this.mainLineStrokeWidth,
        indicatorStrokeWidth: indicatorStrokeWidth ?? this.indicatorStrokeWidth,
        overlayStrokeWidth: overlayStrokeWidth ?? this.overlayStrokeWidth,
        axisFontSize: axisFontSize ?? this.axisFontSize,
        candleWidthRatio: candleWidthRatio ?? this.candleWidthRatio,
        histogramWidthRatio: histogramWidthRatio ?? this.histogramWidthRatio,
        indicatorPointRadius: indicatorPointRadius ?? this.indicatorPointRadius,
      );

  @override
  Color indicatorColor(String instanceId, String seriesId) =>
      indicatorColors['$instanceId:$seriesId'] ??
      indicatorPalette[
          _stableIndex(instanceId, seriesId, indicatorPalette.length)];

  @override
  bool operator ==(Object other) =>
      other is KChartTheme &&
      backgroundColor == other.backgroundColor &&
      gridColor == other.gridColor &&
      axisTextColor == other.axisTextColor &&
      upColor == other.upColor &&
      downColor == other.downColor &&
      markerColor == other.markerColor &&
      crosshairColor == other.crosshairColor &&
      drawingColor == other.drawingColor &&
      mainLineColor == other.mainLineColor &&
      _sameList(areaFillColors, other.areaFillColors) &&
      _sameList(indicatorPalette, other.indicatorPalette) &&
      _sameMap(indicatorColors, other.indicatorColors) &&
      gridStrokeWidth == other.gridStrokeWidth &&
      dataStrokeWidth == other.dataStrokeWidth &&
      mainLineStrokeWidth == other.mainLineStrokeWidth &&
      indicatorStrokeWidth == other.indicatorStrokeWidth &&
      overlayStrokeWidth == other.overlayStrokeWidth &&
      axisFontSize == other.axisFontSize &&
      candleWidthRatio == other.candleWidthRatio &&
      histogramWidthRatio == other.histogramWidthRatio &&
      indicatorPointRadius == other.indicatorPointRadius;

  @override
  int get hashCode => Object.hashAll([
        backgroundColor,
        gridColor,
        axisTextColor,
        upColor,
        downColor,
        markerColor,
        crosshairColor,
        drawingColor,
        mainLineColor,
        Object.hashAll(areaFillColors),
        Object.hashAll(indicatorPalette),
        Object.hashAllUnordered(
          indicatorColors.entries.map(
            (entry) => Object.hash(entry.key, entry.value),
          ),
        ),
        gridStrokeWidth,
        dataStrokeWidth,
        mainLineStrokeWidth,
        indicatorStrokeWidth,
        overlayStrokeWidth,
        axisFontSize,
        candleWidthRatio,
        histogramWidthRatio,
        indicatorPointRadius,
      ]);
}

int _stableIndex(String instanceId, String seriesId, int length) {
  var hash = 17;
  for (final codeUnit in '$instanceId:$seriesId'.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash % length;
}

bool _sameList<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

bool _sameMap<K, V>(Map<K, V> first, Map<K, V> second) {
  if (first.length != second.length) {
    return false;
  }
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
