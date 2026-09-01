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
    Color crosshairLabelBackgroundColor = const Color(0xff000000),
    Color crosshairLabelTextColor = const Color(0xffffffff),
    Color crosshairDetailBackgroundColor = const Color(0xf2ffffff),
    Color crosshairDetailTextColor = const Color(0xff0f172a),
    Color crosshairDetailBorderColor = const Color(0xff94a3b8),
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
    double crosshairDashLength = 5,
    double crosshairDashGap = 4,
    double crosshairPointRadius = 3,
    double crosshairLabelHorizontalPadding = 6,
    double crosshairLabelVerticalPadding = 3,
    int mainValueDecimalPlaces = 2,
    int secondaryValueDecimalPlaces = 2,
    bool mainValueUseThousandsSeparator = true,
    bool secondaryValueUseThousandsSeparator = true,
    String Function(double value, int decimalPlaces)? mainValueFormatter,
    String Function(double value, int decimalPlaces)? secondaryValueFormatter,
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
      'crosshairDashLength': crosshairDashLength,
      'crosshairDashGap': crosshairDashGap,
      'crosshairPointRadius': crosshairPointRadius,
      'crosshairLabelHorizontalPadding': crosshairLabelHorizontalPadding,
      'crosshairLabelVerticalPadding': crosshairLabelVerticalPadding,
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
    _validateDecimalPlaces(
      mainValueDecimalPlaces,
      'mainValueDecimalPlaces',
    );
    _validateDecimalPlaces(
      secondaryValueDecimalPlaces,
      'secondaryValueDecimalPlaces',
    );
    return KChartTheme._(
      backgroundColor: backgroundColor,
      gridColor: gridColor,
      axisTextColor: axisTextColor,
      upColor: upColor,
      downColor: downColor,
      markerColor: markerColor,
      crosshairColor: crosshairColor,
      crosshairLabelBackgroundColor: crosshairLabelBackgroundColor,
      crosshairLabelTextColor: crosshairLabelTextColor,
      crosshairDetailBackgroundColor: crosshairDetailBackgroundColor,
      crosshairDetailTextColor: crosshairDetailTextColor,
      crosshairDetailBorderColor: crosshairDetailBorderColor,
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
      crosshairDashLength: crosshairDashLength,
      crosshairDashGap: crosshairDashGap,
      crosshairPointRadius: crosshairPointRadius,
      crosshairLabelHorizontalPadding: crosshairLabelHorizontalPadding,
      crosshairLabelVerticalPadding: crosshairLabelVerticalPadding,
      axisFontSize: axisFontSize,
      candleWidthRatio: candleWidthRatio,
      histogramWidthRatio: histogramWidthRatio,
      indicatorPointRadius: indicatorPointRadius,
      mainValueDecimalPlaces: mainValueDecimalPlaces,
      secondaryValueDecimalPlaces: secondaryValueDecimalPlaces,
      mainValueUseThousandsSeparator: mainValueUseThousandsSeparator,
      secondaryValueUseThousandsSeparator: secondaryValueUseThousandsSeparator,
      mainValueFormatter: mainValueFormatter,
      secondaryValueFormatter: secondaryValueFormatter,
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
    required this.crosshairLabelBackgroundColor,
    required this.crosshairLabelTextColor,
    required this.crosshairDetailBackgroundColor,
    required this.crosshairDetailTextColor,
    required this.crosshairDetailBorderColor,
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
    required this.crosshairDashLength,
    required this.crosshairDashGap,
    required this.crosshairPointRadius,
    required this.crosshairLabelHorizontalPadding,
    required this.crosshairLabelVerticalPadding,
    required this.axisFontSize,
    required this.candleWidthRatio,
    required this.histogramWidthRatio,
    required this.indicatorPointRadius,
    required this.mainValueDecimalPlaces,
    required this.secondaryValueDecimalPlaces,
    required this.mainValueUseThousandsSeparator,
    required this.secondaryValueUseThousandsSeparator,
    required this.mainValueFormatter,
    required this.secondaryValueFormatter,
  });

  /// A light baseline suitable for applications that do not supply a theme.
  factory KChartTheme.light({
    Color upColor = const Color(0xff0ecb81),
    Color downColor = const Color(0xfff6465d),
    Color crosshairColor = const Color(0xff111111),
    Color crosshairLabelBackgroundColor = const Color(0xff000000),
    Color crosshairLabelTextColor = const Color(0xffffffff),
    Color crosshairDetailBackgroundColor = const Color(0xf2ffffff),
    Color crosshairDetailTextColor = const Color(0xff0f172a),
    Color crosshairDetailBorderColor = const Color(0xff94a3b8),
    double crosshairDashLength = 5,
    double crosshairDashGap = 4,
    double crosshairPointRadius = 3,
    double crosshairLabelHorizontalPadding = 6,
    double crosshairLabelVerticalPadding = 3,
    int mainValueDecimalPlaces = 2,
    int secondaryValueDecimalPlaces = 2,
    bool mainValueUseThousandsSeparator = true,
    bool secondaryValueUseThousandsSeparator = true,
    String Function(double value, int decimalPlaces)? mainValueFormatter,
    String Function(double value, int decimalPlaces)? secondaryValueFormatter,
  }) =>
      KChartTheme(
        backgroundColor: const Color(0xffffffff),
        gridColor: const Color(0xffe6e8ea),
        axisTextColor: const Color(0xff60738e),
        upColor: upColor,
        downColor: downColor,
        markerColor: const Color(0xff6c7a86),
        crosshairColor: crosshairColor,
        crosshairLabelBackgroundColor: crosshairLabelBackgroundColor,
        crosshairLabelTextColor: crosshairLabelTextColor,
        crosshairDetailBackgroundColor: crosshairDetailBackgroundColor,
        crosshairDetailTextColor: crosshairDetailTextColor,
        crosshairDetailBorderColor: crosshairDetailBorderColor,
        drawingColor: const Color(0xff8a70d6),
        mainValueDecimalPlaces: mainValueDecimalPlaces,
        secondaryValueDecimalPlaces: secondaryValueDecimalPlaces,
        mainValueUseThousandsSeparator: mainValueUseThousandsSeparator,
        secondaryValueUseThousandsSeparator:
            secondaryValueUseThousandsSeparator,
        mainValueFormatter: mainValueFormatter,
        secondaryValueFormatter: secondaryValueFormatter,
        crosshairDashLength: crosshairDashLength,
        crosshairDashGap: crosshairDashGap,
        crosshairPointRadius: crosshairPointRadius,
        crosshairLabelHorizontalPadding: crosshairLabelHorizontalPadding,
        crosshairLabelVerticalPadding: crosshairLabelVerticalPadding,
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
  final Color crosshairLabelBackgroundColor;
  @override
  final Color crosshairLabelTextColor;
  @override
  final Color crosshairDetailBackgroundColor;
  @override
  final Color crosshairDetailTextColor;
  @override
  final Color crosshairDetailBorderColor;
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
  final double crosshairDashLength;
  @override
  final double crosshairDashGap;
  @override
  final double crosshairPointRadius;
  @override
  final double crosshairLabelHorizontalPadding;
  @override
  final double crosshairLabelVerticalPadding;
  @override
  final double axisFontSize;
  @override
  final double candleWidthRatio;
  @override
  final double histogramWidthRatio;
  @override
  final double indicatorPointRadius;

  /// Number of decimal places used for main-chart values by default.
  final int mainValueDecimalPlaces;

  /// Number of decimal places used for secondary-chart values by default.
  final int secondaryValueDecimalPlaces;

  /// Whether default main-chart formatting inserts thousands separators.
  final bool mainValueUseThousandsSeparator;

  /// Whether default secondary-chart formatting inserts thousands separators.
  final bool secondaryValueUseThousandsSeparator;

  /// Optional formatter for all main-chart numeric values.
  ///
  /// The second argument is [mainValueDecimalPlaces]. When supplied, this
  /// callback takes precedence over [mainValueUseThousandsSeparator].
  final String Function(double value, int decimalPlaces)? mainValueFormatter;

  /// Optional formatter for all secondary-chart numeric values.
  ///
  /// The second argument is [secondaryValueDecimalPlaces]. When supplied,
  /// this callback takes precedence over
  /// [secondaryValueUseThousandsSeparator].
  final String Function(double value, int decimalPlaces)?
      secondaryValueFormatter;

  KChartTheme copyWith({
    Color? backgroundColor,
    Color? gridColor,
    Color? axisTextColor,
    Color? upColor,
    Color? downColor,
    Color? markerColor,
    Color? crosshairColor,
    Color? crosshairLabelBackgroundColor,
    Color? crosshairLabelTextColor,
    Color? crosshairDetailBackgroundColor,
    Color? crosshairDetailTextColor,
    Color? crosshairDetailBorderColor,
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
    double? crosshairDashLength,
    double? crosshairDashGap,
    double? crosshairPointRadius,
    double? crosshairLabelHorizontalPadding,
    double? crosshairLabelVerticalPadding,
    double? axisFontSize,
    double? candleWidthRatio,
    double? histogramWidthRatio,
    double? indicatorPointRadius,
    int? mainValueDecimalPlaces,
    int? secondaryValueDecimalPlaces,
    bool? mainValueUseThousandsSeparator,
    bool? secondaryValueUseThousandsSeparator,
    String Function(double value, int decimalPlaces)? mainValueFormatter,
    String Function(double value, int decimalPlaces)? secondaryValueFormatter,
    bool clearMainValueFormatter = false,
    bool clearSecondaryValueFormatter = false,
  }) =>
      KChartTheme(
        backgroundColor: backgroundColor ?? this.backgroundColor,
        gridColor: gridColor ?? this.gridColor,
        axisTextColor: axisTextColor ?? this.axisTextColor,
        upColor: upColor ?? this.upColor,
        downColor: downColor ?? this.downColor,
        markerColor: markerColor ?? this.markerColor,
        crosshairColor: crosshairColor ?? this.crosshairColor,
        crosshairLabelBackgroundColor:
            crosshairLabelBackgroundColor ?? this.crosshairLabelBackgroundColor,
        crosshairLabelTextColor:
            crosshairLabelTextColor ?? this.crosshairLabelTextColor,
        crosshairDetailBackgroundColor: crosshairDetailBackgroundColor ??
            this.crosshairDetailBackgroundColor,
        crosshairDetailTextColor:
            crosshairDetailTextColor ?? this.crosshairDetailTextColor,
        crosshairDetailBorderColor:
            crosshairDetailBorderColor ?? this.crosshairDetailBorderColor,
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
        crosshairDashLength: crosshairDashLength ?? this.crosshairDashLength,
        crosshairDashGap: crosshairDashGap ?? this.crosshairDashGap,
        crosshairPointRadius: crosshairPointRadius ?? this.crosshairPointRadius,
        crosshairLabelHorizontalPadding: crosshairLabelHorizontalPadding ??
            this.crosshairLabelHorizontalPadding,
        crosshairLabelVerticalPadding:
            crosshairLabelVerticalPadding ?? this.crosshairLabelVerticalPadding,
        axisFontSize: axisFontSize ?? this.axisFontSize,
        candleWidthRatio: candleWidthRatio ?? this.candleWidthRatio,
        histogramWidthRatio: histogramWidthRatio ?? this.histogramWidthRatio,
        indicatorPointRadius: indicatorPointRadius ?? this.indicatorPointRadius,
        mainValueDecimalPlaces:
            mainValueDecimalPlaces ?? this.mainValueDecimalPlaces,
        secondaryValueDecimalPlaces:
            secondaryValueDecimalPlaces ?? this.secondaryValueDecimalPlaces,
        mainValueUseThousandsSeparator: mainValueUseThousandsSeparator ??
            this.mainValueUseThousandsSeparator,
        secondaryValueUseThousandsSeparator:
            secondaryValueUseThousandsSeparator ??
                this.secondaryValueUseThousandsSeparator,
        mainValueFormatter: clearMainValueFormatter
            ? null
            : mainValueFormatter ?? this.mainValueFormatter,
        secondaryValueFormatter: clearSecondaryValueFormatter
            ? null
            : secondaryValueFormatter ?? this.secondaryValueFormatter,
      );

  @override
  Color indicatorColor(String instanceId, String seriesId) =>
      indicatorColors['$instanceId:$seriesId'] ??
      indicatorPalette[
          _stableIndex(instanceId, seriesId, indicatorPalette.length)];

  @override
  String formatMainValue(double value) =>
      mainValueFormatter?.call(value, mainValueDecimalPlaces) ??
      formatChartValue(
        value,
        decimalPlaces: mainValueDecimalPlaces,
        useThousandsSeparator: mainValueUseThousandsSeparator,
      );

  @override
  String formatSecondaryValue(double value) =>
      secondaryValueFormatter?.call(value, secondaryValueDecimalPlaces) ??
      formatChartValue(
        value,
        decimalPlaces: secondaryValueDecimalPlaces,
        useThousandsSeparator: secondaryValueUseThousandsSeparator,
      );

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
      crosshairLabelBackgroundColor == other.crosshairLabelBackgroundColor &&
      crosshairLabelTextColor == other.crosshairLabelTextColor &&
      crosshairDetailBackgroundColor == other.crosshairDetailBackgroundColor &&
      crosshairDetailTextColor == other.crosshairDetailTextColor &&
      crosshairDetailBorderColor == other.crosshairDetailBorderColor &&
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
      crosshairDashLength == other.crosshairDashLength &&
      crosshairDashGap == other.crosshairDashGap &&
      crosshairPointRadius == other.crosshairPointRadius &&
      crosshairLabelHorizontalPadding ==
          other.crosshairLabelHorizontalPadding &&
      crosshairLabelVerticalPadding == other.crosshairLabelVerticalPadding &&
      axisFontSize == other.axisFontSize &&
      candleWidthRatio == other.candleWidthRatio &&
      histogramWidthRatio == other.histogramWidthRatio &&
      indicatorPointRadius == other.indicatorPointRadius &&
      mainValueDecimalPlaces == other.mainValueDecimalPlaces &&
      secondaryValueDecimalPlaces == other.secondaryValueDecimalPlaces &&
      mainValueUseThousandsSeparator == other.mainValueUseThousandsSeparator &&
      secondaryValueUseThousandsSeparator ==
          other.secondaryValueUseThousandsSeparator &&
      identical(mainValueFormatter, other.mainValueFormatter) &&
      identical(secondaryValueFormatter, other.secondaryValueFormatter);

  @override
  int get hashCode => Object.hashAll([
        backgroundColor,
        gridColor,
        axisTextColor,
        upColor,
        downColor,
        markerColor,
        crosshairColor,
        crosshairLabelBackgroundColor,
        crosshairLabelTextColor,
        crosshairDetailBackgroundColor,
        crosshairDetailTextColor,
        crosshairDetailBorderColor,
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
        crosshairDashLength,
        crosshairDashGap,
        crosshairPointRadius,
        crosshairLabelHorizontalPadding,
        crosshairLabelVerticalPadding,
        axisFontSize,
        candleWidthRatio,
        histogramWidthRatio,
        indicatorPointRadius,
        mainValueDecimalPlaces,
        secondaryValueDecimalPlaces,
        mainValueUseThousandsSeparator,
        secondaryValueUseThousandsSeparator,
        mainValueFormatter,
        secondaryValueFormatter,
      ]);
}

void _validateDecimalPlaces(int value, String name) {
  if (value < 0 || value > 20) {
    throw ArgumentError.value(value, name, 'Must be between 0 and 20.');
  }
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
