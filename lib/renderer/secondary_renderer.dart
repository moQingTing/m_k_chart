import 'dart:ui';

import 'package:flutter/material.dart';
import '../entity/macd_entity.dart';
import '../k_chart_widget.dart' show SecondaryState;
import '../chart_style.dart';

import 'base_chart_renderer.dart';

class SecondaryRenderer extends BaseChartRenderer<MACDEntity> {
  double mMACDWidth =0.0;
  SecondaryState state;
  final ChartColors chartColors;
  final ChartStyle chartStyle;
  
  SecondaryRenderer(Rect mainRect, double maxValue, double minValue, double topPadding, this.state,this.chartStyle,this.chartColors)
      : super(chartRect: mainRect, maxValue: maxValue, minValue: minValue, topPadding: topPadding, chartStyle: chartStyle){
    mMACDWidth = chartStyle.macdWidth;
  }

  @override
  void drawChart(
      MACDEntity lastPoint, MACDEntity curPoint, double lastX, double curX, Size size, Canvas canvas) {
    switch (state) {
      case SecondaryState.macd:
        drawMACD(curPoint, canvas, curX, lastPoint, lastX);
        break;
      case SecondaryState.kdj:
        if (lastPoint.k != 0) drawLine(lastPoint.k, curPoint.k, canvas, lastX, curX, chartColors.kColor);
        if (lastPoint.d != 0) drawLine(lastPoint.d, curPoint.d, canvas, lastX, curX, chartColors.dColor);
        if (lastPoint.j != 0) drawLine(lastPoint.j, curPoint.j, canvas, lastX, curX, chartColors.jColor);
        break;
      case SecondaryState.rsi:
        if (lastPoint.rsi != 0) {
          drawLine(lastPoint.rsi, curPoint.rsi, canvas, lastX, curX, chartColors.rsiColor);
        }
        break;
      case SecondaryState.wr:
        if (lastPoint.r != 0) drawLine(lastPoint.r, curPoint.r, canvas, lastX, curX, chartColors.rsiColor);
        break;
      case SecondaryState.obv:
        // OBV 能量潮指标：使用累积计算的 obv 值绘制折线图
        if (lastPoint.obv != 0 && curPoint.obv != 0) {
          drawLine(lastPoint.obv, curPoint.obv, canvas, lastX, curX, chartColors.kLineColor);
        }
        // OBV 移动平均线
        if (lastPoint.maOBV != 0 && curPoint.maOBV != 0) {
          drawLine(lastPoint.maOBV, curPoint.maOBV, canvas, lastX, curX, chartColors.maOBVColor);
        }
        break;
      default:
        break;
    }
  }

  void drawMACD(MACDEntity curPoint, Canvas canvas, double curX, MACDEntity lastPoint, double lastX) {
    double r = mMACDWidth / 2;
    double zeroy = getY(0);
    
    // 计算MACD柱的位置
    double macdY = getY(curPoint.macd >= 0 ? curPoint.macd : 0);
    
    // 保存chartPaint的原始状态
    Color originalColor = chartPaint.color;
    PaintingStyle originalStyle = chartPaint.style;
    double originalStrokeWidth = chartPaint.strokeWidth;
    
    // 使用配置的颜色
    Color macdColor = curPoint.macd >= 0 ? chartColors.upColor : chartColors.dnColor;
    
    // 根据MACD值的正负和变化趋势来判断空心/实心
    bool isIncreasing = curPoint.macd > lastPoint.macd;
    bool isPositive = curPoint.macd >= 0;
    
    // 红色MACD（负值）：增加时空心，减少时实心
    // 绿色MACD（正值）：增加时实心，减少时空心（与红色相反）
    bool shouldBeHollow = isPositive ? !isIncreasing : isIncreasing;
    
    // 创建MACD柱的矩形
    Rect macdRect;
    if (curPoint.macd >= 0) {
      // 正值：从MACD值到0线
      macdRect = Rect.fromLTRB(curX - r, macdY, curX + r, zeroy);
    } else {
      // 负值：从0线到MACD值
      macdRect = Rect.fromLTRB(curX - r, zeroy, curX + r, getY(curPoint.macd));
    }
    
    chartPaint.color = macdColor;
    chartPaint.strokeWidth = 1.0;
    
    if (shouldBeHollow) {
      // 空心柱状图（只画边框）
      chartPaint.style = PaintingStyle.stroke;
      canvas.drawRect(macdRect, chartPaint);
    } else {
      // 实心柱状图
      chartPaint.style = PaintingStyle.fill;
      canvas.drawRect(macdRect, chartPaint);
    }
    
    // 恢复chartPaint的原始状态
    chartPaint.color = originalColor;
    chartPaint.style = originalStyle;
    chartPaint.strokeWidth = originalStrokeWidth;
    
    // 绘制DIF和DEA线
    if (lastPoint.dif != 0) {
      drawLine(lastPoint.dif, curPoint.dif, canvas, lastX, curX, chartColors.difColor);
    }
    if (lastPoint.dea != 0) {
      drawLine(lastPoint.dea, curPoint.dea, canvas, lastX, curX, chartColors.deaColor);
    }
  }

  @override
  void drawText(Canvas canvas, MACDEntity data, double x) {
    List<TextSpan>? children;
    switch (state) {
      case SecondaryState.macd:
        children = [
          TextSpan(text: "MACD(12,26,9)  ", style: getTextStyle(chartColors.yAxisTextColor,chartStyle.defaultTextSize)),
          if (data.macd != 0)
            TextSpan(children: [
              TextSpan(text: "MACD:", style: getTextStyle(chartColors.macdColor,chartStyle.defaultTextSize)),
              formatPrice(data.macd, getTextStyle(chartColors.macdColor,chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.macdColor,chartStyle.defaultTextSize)),
            ]),
          if (data.dif != 0)
            TextSpan(children: [
              TextSpan(text: "DIF:", style: getTextStyle(chartColors.difColor,chartStyle.defaultTextSize)),
              formatPrice(data.dif, getTextStyle(chartColors.difColor,chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.difColor,chartStyle.defaultTextSize)),
            ]),
          if (data.dea != 0)
            TextSpan(children: [
              TextSpan(text: "DEA:", style: getTextStyle(chartColors.deaColor,chartStyle.defaultTextSize)),
              formatPrice(data.dea, getTextStyle(chartColors.deaColor,chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.deaColor,chartStyle.defaultTextSize)),
            ]),
        ];
        break;
      case SecondaryState.kdj:
        children = [
          TextSpan(text: "KDJ(14,1,3)  ", style: getTextStyle(chartColors.yAxisTextColor,chartStyle.defaultTextSize)),
          if (data.k != 0)
            TextSpan(children: [
              TextSpan(text: "K:", style: getTextStyle(chartColors.kColor,chartStyle.defaultTextSize)),
              formatPrice(data.k, getTextStyle(chartColors.kColor,chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.kColor,chartStyle.defaultTextSize)),
            ]),
          if (data.d != 0)
            TextSpan(children: [
              TextSpan(text: "D:", style: getTextStyle(chartColors.dColor,chartStyle.defaultTextSize)),
              formatPrice(data.d, getTextStyle(chartColors.dColor,chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.dColor,chartStyle.defaultTextSize)),
            ]),
          if (data.j != 0)
            TextSpan(children: [
              TextSpan(text: "J:", style: getTextStyle(chartColors.jColor,chartStyle.defaultTextSize)),
              formatPrice(data.j, getTextStyle(chartColors.jColor,chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.jColor,chartStyle.defaultTextSize)),
            ]),
        ];
        break;
      case SecondaryState.rsi:
        children = [
          TextSpan(children: [
            TextSpan(text: "RSI(14):", style: getTextStyle(chartColors.rsiColor,chartStyle.defaultTextSize)),
            formatPrice(data.rsi, getTextStyle(chartColors.rsiColor,chartStyle.defaultTextSize)),
            TextSpan(text: "  ", style: getTextStyle(chartColors.rsiColor,chartStyle.defaultTextSize)),
          ]),
        ];
        break;
      case SecondaryState.wr:
        children = [
          TextSpan(children: [
            TextSpan(text: "WR(14):", style: getTextStyle(chartColors.rsiColor,chartStyle.defaultTextSize)),
            formatPrice(data.r, getTextStyle(chartColors.rsiColor,chartStyle.defaultTextSize)),
            TextSpan(text: "  ", style: getTextStyle(chartColors.rsiColor,chartStyle.defaultTextSize)),
          ]),
        ];
        break;
      case SecondaryState.obv:
        final obvPeriod = chartStyle.obvPeriod;
        children = [
          TextSpan(children: [
            TextSpan(text: "OBV($obvPeriod):", style: getTextStyle(chartColors.kLineColor,chartStyle.defaultTextSize)),
            formatPrice(data.obv, getTextStyle(chartColors.kLineColor,chartStyle.defaultTextSize)),
            TextSpan(text: "  ", style: getTextStyle(chartColors.kLineColor,chartStyle.defaultTextSize)),
            TextSpan(text: "MAOBV($obvPeriod):", style: getTextStyle(chartColors.maOBVColor,chartStyle.defaultTextSize)),
            formatPrice(data.maOBV, getTextStyle(chartColors.maOBVColor,chartStyle.defaultTextSize)),
            TextSpan(text: "  ", style: getTextStyle(chartColors.maOBVColor,chartStyle.defaultTextSize)),
          ]),
        ];
        break;
      default:
        break;
    }
    TextPainter tp = TextPainter(text: TextSpan(children: children ?? []), textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top));
  }

  @override
  void drawRightText(canvas, textStyle, int gridRows) {
    TextPainter maxTp = TextPainter(
        text: formatPrice(maxValue, textStyle), textDirection: TextDirection.ltr);
    maxTp.layout();
    TextPainter minTp = TextPainter(
        text: formatPrice(minValue, textStyle), textDirection: TextDirection.ltr);
    minTp.layout();

    maxTp.paint(canvas, Offset(chartRect.width - maxTp.width, chartRect.top + topPadding - maxTp.height));
    minTp.paint(canvas, Offset(chartRect.width - minTp.width, chartRect.bottom - minTp.height));
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    canvas.drawLine(Offset(0, chartRect.bottom), Offset(chartRect.width, chartRect.bottom), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= columnSpace; i++) {
      //mSecondaryRect垂直线
      canvas.drawLine(Offset(columnSpace * i, chartRect.top),
          Offset(columnSpace * i, chartRect.bottom), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
    }
    // canvas.drawLine(Offset(0, chartRect.bottom + topPadding), Offset(chartRect.width, chartRect.bottom + topPadding), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
  }
}
