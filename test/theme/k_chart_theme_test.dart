import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';

void main() {
  test('KChartTheme owns collections and compares structural values', () {
    final palette = <Color>[const Color(0xff112233)];
    final colors = <String, Color>{'custom:line': const Color(0xff445566)};
    final first = KChartTheme(
      indicatorPalette: palette,
      indicatorColors: colors,
    );
    palette.add(const Color(0xff778899));
    colors['other:line'] = const Color(0xffaabbcc);

    final second = KChartTheme(
      indicatorPalette: const [Color(0xff112233)],
      indicatorColors: const {'custom:line': Color(0xff445566)},
    );

    expect(first.indicatorPalette, [const Color(0xff112233)]);
    expect(first.indicatorColors, const {'custom:line': Color(0xff445566)});
    expect(() => first.indicatorPalette.clear(), throwsUnsupportedError);
    expect(() => first.indicatorColors.clear(), throwsUnsupportedError);
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(
      first.copyWith(mainLineColor: const Color(0xffabcdef)),
      isNot(equals(first)),
    );
  });

  test('KChartTheme prioritizes explicit indicator colors', () {
    final theme = KChartTheme(
      indicatorPalette: const [Color(0xff112233)],
      indicatorColors: const {'legacy.macd:dif': Color(0xff445566)},
    );

    expect(
      theme.indicatorColor('legacy.macd', 'dif'),
      const Color(0xff445566),
    );
    expect(
      theme.indicatorColor('unconfigured', 'series'),
      const Color(0xff112233),
    );
  });

  test('KChartTheme formats main and secondary values independently', () {
    final defaults = KChartTheme.light();
    expect(defaults.formatMainValue(1234567.891), '1,234,567.89');
    expect(defaults.formatSecondaryValue(-9876.5), '-9,876.50');

    final configured = defaults.copyWith(
      mainValueDecimalPlaces: 4,
      mainValueUseThousandsSeparator: false,
      secondaryValueDecimalPlaces: 0,
      secondaryValueUseThousandsSeparator: true,
    );
    expect(configured.formatMainValue(1234.5), '1234.5000');
    expect(configured.formatSecondaryValue(1234.5), '1,235');
    expect(configured, isNot(defaults));
  });

  test('KChartTheme accepts separate custom value formatters', () {
    String mainFormatter(double value, int decimalPlaces) =>
        'main:$decimalPlaces:${value.toStringAsFixed(decimalPlaces)}';
    String secondaryFormatter(double value, int decimalPlaces) =>
        'secondary:$decimalPlaces:${value.toStringAsFixed(decimalPlaces)}';
    final theme = KChartTheme(
      mainValueDecimalPlaces: 3,
      secondaryValueDecimalPlaces: 1,
      mainValueFormatter: mainFormatter,
      secondaryValueFormatter: secondaryFormatter,
    );

    expect(theme.formatMainValue(12.3456), 'main:3:12.346');
    expect(theme.formatSecondaryValue(12.3456), 'secondary:1:12.3');
    expect(theme.copyWith(), theme);

    final defaults = theme.copyWith(
      clearMainValueFormatter: true,
      clearSecondaryValueFormatter: true,
    );
    expect(defaults.mainValueFormatter, isNull);
    expect(defaults.secondaryValueFormatter, isNull);
    expect(defaults.formatMainValue(1234.5), '1,234.500');
    expect(defaults.formatSecondaryValue(1234.5), '1,234.5');
  });

  test('KChartTheme rejects unsupported decimal places', () {
    expect(
      () => KChartTheme(mainValueDecimalPlaces: -1),
      throwsArgumentError,
    );
    expect(
      () => KChartTheme(secondaryValueDecimalPlaces: 21),
      throwsArgumentError,
    );
  });

  test('KChartTheme exposes configurable crosshair labels and details', () {
    final theme = KChartTheme.light(
      crosshairLabelBackgroundColor: const Color(0xff112233),
      crosshairLabelTextColor: const Color(0xffddeeff),
      crosshairDashLength: 7,
      crosshairDashGap: 2,
      crosshairPointRadius: 4,
    );

    expect(theme.crosshairLabelBackgroundColor, const Color(0xff112233));
    expect(theme.crosshairLabelTextColor, const Color(0xffddeeff));
    expect(theme.crosshairDashLength, 7);
    expect(theme.crosshairDashGap, 2);
    expect(theme.crosshairPointRadius, 4);
    expect(
      theme.copyWith(crosshairDetailTextColor: const Color(0xff123456)),
      isNot(theme),
    );
  });

  test('ChartColors adapter preserves legacy render colors and widths', () {
    final colors = ChartColors(
      isDarkMode: false,
      upColor: const Color(0xff00aa00),
      downColor: const Color(0xffdd0000),
    );
    final style = ChartStyle()
      ..gridStrokeWidth = 2
      ..candleLineWidth = 0.5
      ..lineStrokeWidth = 3
      ..vCrossWidth = 0.25
      ..defaultTextSize = 12
      ..pointWidth = 10
      ..candleWidth = 5
      ..volWidth = 8;

    final theme = colors.toKChartTheme(chartStyle: style);

    expect(theme.backgroundColor, colors.bgColor);
    expect(theme.gridColor, colors.gridColor);
    expect(theme.mainLineColor, colors.kLineColor);
    expect(theme.areaFillColors, colors.kLineShadowColor);
    expect(theme.upColor, colors.upColor);
    expect(theme.downColor, colors.downColor);
    expect(theme.gridStrokeWidth, 2);
    expect(theme.dataStrokeWidth, 0.5);
    expect(theme.mainLineStrokeWidth, 3);
    expect(theme.overlayStrokeWidth, 0.25);
    expect(theme.axisFontSize, 12);
    expect(theme.candleWidthRatio, 0.5);
    expect(theme.histogramWidthRatio, 0.8);
    expect(theme.indicatorColor('legacy.macd', 'dif'), colors.difColor);
    expect(theme.indicatorColor('legacy.kdj', 'j'), colors.jColor);
  });

  test('ChartColors adapter sanitizes mutable legacy dimensions', () {
    final theme = ChartColors(
      isDarkMode: true,
      upColor: const Color(0xff00aa00),
      downColor: const Color(0xffdd0000),
    ).toKChartTheme(
      chartStyle: ChartStyle()
        ..gridStrokeWidth = 0
        ..candleLineWidth = double.nan
        ..lineStrokeWidth = -1
        ..vCrossWidth = 0
        ..defaultTextSize = 0
        ..pointWidth = 0
        ..candleWidth = 0
        ..volWidth = double.infinity,
    );

    expect(theme.gridStrokeWidth, 1);
    expect(theme.dataStrokeWidth, 1);
    expect(theme.mainLineStrokeWidth, 1.5);
    expect(theme.overlayStrokeWidth, 1);
    expect(theme.axisFontSize, 10);
    expect(theme.candleWidthRatio, 1);
    expect(theme.histogramWidthRatio, 1);
  });
}
