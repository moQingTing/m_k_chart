import 'dart:ui';

/// Internal rendering contract implemented by the public immutable KChartTheme.
///
/// It remains internal so standard renderer capabilities are not part of the
/// package API surface.
abstract interface class ChartRenderStyle {
  Color get backgroundColor;
  Color get gridColor;
  Color get axisTextColor;
  Color get upColor;
  Color get downColor;
  Color get markerColor;
  Color get crosshairColor;
  Color get crosshairLabelBackgroundColor;
  Color get crosshairLabelTextColor;
  Color get crosshairDetailBackgroundColor;
  Color get crosshairDetailTextColor;
  Color get crosshairDetailBorderColor;
  Color get drawingColor;
  Color get mainLineColor;
  List<Color> get areaFillColors;
  double get gridStrokeWidth;
  double get dataStrokeWidth;
  double get mainLineStrokeWidth;
  double get indicatorStrokeWidth;
  double get overlayStrokeWidth;
  double get crosshairDashLength;
  double get crosshairDashGap;
  double get crosshairPointRadius;
  double get crosshairLabelHorizontalPadding;
  double get crosshairLabelVerticalPadding;
  double get axisFontSize;
  double get candleWidthRatio;
  double get histogramWidthRatio;
  double get indicatorPointRadius;

  Color indicatorColor(String instanceId, String seriesId);
  String formatMainValue(double value);
  String formatSecondaryValue(double value);
}

/// Deterministic internal fixture style retained for V2 renderer tests.
final class DefaultChartRenderStyle implements ChartRenderStyle {
  factory DefaultChartRenderStyle({
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
      'crosshairDashLength': crosshairDashLength,
      'crosshairDashGap': crosshairDashGap,
      'crosshairPointRadius': crosshairPointRadius,
      'crosshairLabelHorizontalPadding': crosshairLabelHorizontalPadding,
      'crosshairLabelVerticalPadding': crosshairLabelVerticalPadding,
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
    _validateDecimalPlaces(
      mainValueDecimalPlaces,
      'mainValueDecimalPlaces',
    );
    _validateDecimalPlaces(
      secondaryValueDecimalPlaces,
      'secondaryValueDecimalPlaces',
    );
    return DefaultChartRenderStyle._(
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

  const DefaultChartRenderStyle._({
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
  final int mainValueDecimalPlaces;
  final int secondaryValueDecimalPlaces;
  final bool mainValueUseThousandsSeparator;
  final bool secondaryValueUseThousandsSeparator;
  final String Function(double value, int decimalPlaces)? mainValueFormatter;
  final String Function(double value, int decimalPlaces)?
      secondaryValueFormatter;

  @override
  Color indicatorColor(String instanceId, String seriesId) {
    var hash = 17;
    for (final codeUnit in '$instanceId:$seriesId'.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return indicatorPalette[hash % indicatorPalette.length];
  }

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
}

String formatChartValue(
  double value, {
  required int decimalPlaces,
  required bool useThousandsSeparator,
}) {
  if (!value.isFinite) {
    return value.toString();
  }
  final fixed = value.toStringAsFixed(decimalPlaces);
  if (!useThousandsSeparator || fixed.contains('e') || fixed.contains('E')) {
    return fixed;
  }
  final isNegative = fixed.startsWith('-');
  final unsigned = isNegative ? fixed.substring(1) : fixed;
  final decimalIndex = unsigned.indexOf('.');
  final integerPart =
      decimalIndex < 0 ? unsigned : unsigned.substring(0, decimalIndex);
  final fractionPart = decimalIndex < 0 ? '' : unsigned.substring(decimalIndex);
  final buffer = StringBuffer();
  for (var index = 0; index < integerPart.length; index++) {
    if (index > 0 && (integerPart.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(integerPart[index]);
  }
  return '${isNegative ? '-' : ''}$buffer$fractionPart';
}

void _validateDecimalPlaces(int value, String name) {
  if (value < 0 || value > 20) {
    throw ArgumentError.value(value, name, 'Must be between 0 and 20.');
  }
}
