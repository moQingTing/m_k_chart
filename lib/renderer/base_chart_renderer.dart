import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/number_util.dart';
export '../chart_style.dart';
import '../chart_style.dart';

abstract class BaseChartRenderer<T> {
  double maxValue, minValue;
  double scaleY = 1;
  double topPadding;
  Rect chartRect;
  final ChartStyle chartStyle;
  final Paint chartPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeCap = StrokeCap.butt
    // ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 1.0
    ..color = Colors.red;
  final Paint gridPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 0.1
    ..color = Colors.grey;

  BaseChartRenderer({
    required this.chartRect,
    required this.maxValue,
    required this.minValue,
    required this.topPadding,
    required this.chartStyle,
  }) {
    if (maxValue == minValue) {
      maxValue += 0.5;
      minValue -= 0.5;
    }
    scaleY = (chartRect.height) / (maxValue - minValue);
    if (kDebugMode) {
      // print('scaleY = $scaleY');
    }
  }

  double getY(double y) {
    return (maxValue - y) * scaleY + chartRect.top;
  }

  String format(double n) {
    return NumberUtil.format(n);
  }

  /// 格式化价格，使用回调或默认格式化
  TextSpan formatPrice(double price, TextStyle defaultStyle) {
    if (chartStyle.priceFormatter != null) {
      return chartStyle.priceFormatter!(price, defaultStyle);
    }
    return chartStyle.defaultFormatPrice(price, defaultStyle);
  }

  /// 格式化数量，使用回调或默认格式化
  TextSpan formatVolume(double volume, TextStyle defaultStyle) {
    if (chartStyle.volumeFormatter != null) {
      return chartStyle.volumeFormatter!(volume, defaultStyle);
    }
    return chartStyle.defaultFormatVolume(volume, defaultStyle);
  }

  void drawGrid(Canvas canvas, int gridRows, int gridColumns);

  void drawText(Canvas canvas, T data, double x);

  void drawRightText(canvas, textStyle, int gridRows);

  void drawChart(T lastPoint, T curPoint, double lastX, double curX, Size size,
      Canvas canvas);

  void drawLine(double lastPrice, double curPrice, Canvas canvas, double lastX,
      double curX, Color color) {
    double lastY = getY(lastPrice);
    double curY = getY(curPrice);
    if (kDebugMode) {
      // print('drawLine lastX = $lastX');
      // print('drawLine curX = $curX');
    }
    canvas.drawLine(
        Offset(lastX, lastY), Offset(curX, curY), chartPaint..color = color);
  }

  TextStyle getTextStyle(Color color, double fontSize) {
    return TextStyle(fontSize: fontSize, color: color);
  }
}
