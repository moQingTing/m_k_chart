import 'dart:ui';

import 'package:flutter/material.dart';
import '../entity/volume_entity.dart';
import '../chart_style.dart';
import '../renderer/base_chart_renderer.dart';

class VolRenderer extends BaseChartRenderer<VolumeEntity> {
  double mVolWidth = 0.0;

  final ChartColors chartColors;
  final ChartStyle chartStyle;

  VolRenderer(Rect mainRect, double maxValue, double minValue,
      double topPadding, this.chartStyle, this.chartColors)
      : super(
            chartRect: mainRect,
            maxValue: maxValue,
            minValue: minValue,
            topPadding: topPadding,
            chartStyle: chartStyle) {
    mVolWidth = chartStyle.volWidth;
  }

  @override
  void drawChart(
      VolumeEntity lastPoint, VolumeEntity curPoint, double lastX, double curX, Size size, Canvas canvas) {
    double r = mVolWidth / 2;
    double top = getY(curPoint.vol);
    double bottom = chartRect.bottom;
    canvas.drawRect(Rect.fromLTRB(curX - r, top, curX + r, bottom),
        chartPaint..color = curPoint.close >= curPoint.open ? chartColors.upColor : chartColors.dnColor);

    if (lastPoint.MA5Volume != 0) {
      drawLine(lastPoint.MA5Volume, curPoint.MA5Volume, canvas, lastX, curX, chartColors.ma5Color);
    }

    if (lastPoint.MA10Volume != 0) {
      drawLine(lastPoint.MA10Volume, curPoint.MA10Volume, canvas, lastX, curX, chartColors.ma10Color);
    }
  }

  @override
  double getY(double y){
    if (maxValue == 0) return chartRect.bottom;
    return (maxValue - y) * (chartRect.height / maxValue) + chartRect.top;
  }

  @override
  void drawText(Canvas canvas, VolumeEntity data, double x) {
    TextSpan span = TextSpan(
      children: [
        TextSpan(children: [
          TextSpan(text: "VOL:", style: getTextStyle(chartColors.volColor, this.chartStyle.defaultTextSize)),
          formatVolume(data.vol, getTextStyle(chartColors.volColor, this.chartStyle.defaultTextSize)),
          TextSpan(text: "  ", style: getTextStyle(chartColors.volColor, this.chartStyle.defaultTextSize)),
        ]),
        TextSpan(children: [
          TextSpan(text: "MA5:", style: getTextStyle(chartColors.ma5Color, this.chartStyle.defaultTextSize)),
          formatVolume(data.MA5Volume, getTextStyle(chartColors.ma5Color, this.chartStyle.defaultTextSize)),
          TextSpan(text: "  ", style: getTextStyle(chartColors.ma5Color, this.chartStyle.defaultTextSize)),
        ]),
        TextSpan(children: [
          TextSpan(text: "MA10:", style: getTextStyle(chartColors.ma10Color, this.chartStyle.defaultTextSize)),
          formatVolume(data.MA10Volume, getTextStyle(chartColors.ma10Color, this.chartStyle.defaultTextSize)),
          TextSpan(text: "  ", style: getTextStyle(chartColors.ma10Color, this.chartStyle.defaultTextSize)),
        ]),
      ],
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top));
  }

  @override
  void drawRightText(canvas, textStyle, int gridRows) {
    TextSpan span = formatVolume(maxValue, textStyle);
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(chartRect.width - tp.width, chartRect.top));
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    canvas.drawLine(Offset(0, chartRect.bottom), Offset(chartRect.width, chartRect.bottom), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= columnSpace; i++) {
      //vol垂直线
      canvas.drawLine(Offset(columnSpace * i, chartRect.top),
          Offset(columnSpace * i, chartRect.bottom), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
    }
  }
}
