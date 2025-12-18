import 'package:flutter/material.dart';
import '../entity/candle_entity.dart';
import '../k_chart_widget.dart' show MainState;
import '../chart_style.dart';
import 'base_chart_renderer.dart';

class MainRenderer extends BaseChartRenderer<CandleEntity> {
  double mCandleWidth = 0.0;
  double mCandleLineWidth = 0.0;
  MainState state;
  bool isLine;
  final ChartColors chartColors;
  final ChartStyle chartStyle;
  

  final double _contentPadding = 12.0;

  MainRenderer(Rect mainRect, double maxValue, double minValue,
      double topPadding, this.state, this.isLine,this.chartStyle,this.chartColors)
      : super(
            chartRect: mainRect,
            maxValue: maxValue,
            minValue: minValue,
            topPadding: topPadding,
            chartStyle: chartStyle) {
    mCandleWidth = chartStyle.candleWidth;
    mCandleLineWidth = chartStyle.candleLineWidth;
    
    var diff = maxValue - minValue; //计算差
    var newScaleY = (chartRect.height - _contentPadding) / diff; //内容区域高度/差=新的比例
    var newDiff = chartRect.height / newScaleY; //高/新比例=新的差
    var value = (newDiff - diff) / 2; //新差-差/2=y轴需要扩大的值
    if (newDiff > diff) {
      scaleY = newScaleY;
      this.maxValue += value;
      this.minValue -= value;
    }
  }

  @override
  void drawText(Canvas canvas, CandleEntity data, double x) {
    if (isLine == true) return;
    TextSpan? span;
    if (state == MainState.ma) {
      span = TextSpan(
        children: [
          if (data.MA5Price != 0)
            TextSpan(children: [
              TextSpan(text: "MA5:", style: getTextStyle(chartColors.ma5Color, chartStyle.defaultTextSize)),
              formatPrice(data.MA5Price, getTextStyle(chartColors.ma5Color, chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.ma5Color, chartStyle.defaultTextSize)),
            ]),
          if (data.MA10Price != 0)
            TextSpan(children: [
              TextSpan(text: "MA10:", style: getTextStyle(chartColors.ma10Color, chartStyle.defaultTextSize)),
              formatPrice(data.MA10Price, getTextStyle(chartColors.ma10Color, chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.ma10Color, chartStyle.defaultTextSize)),
            ]),
          if (data.MA30Price != 0)
            TextSpan(children: [
              TextSpan(text: "MA30:", style: getTextStyle(chartColors.ma30Color, chartStyle.defaultTextSize)),
              formatPrice(data.MA30Price, getTextStyle(chartColors.ma30Color, chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.ma30Color, chartStyle.defaultTextSize)),
            ]),
        ],
      );
    } else if (state == MainState.boll) {
      span = TextSpan(
        children: [
          if (data.mb != 0)
            TextSpan(children: [
              TextSpan(text: "BOLL:", style: getTextStyle(chartColors.ma5Color, chartStyle.defaultTextSize)),
              formatPrice(data.mb, getTextStyle(chartColors.ma5Color, chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.ma5Color, chartStyle.defaultTextSize)),
            ]),
          if (data.up != 0)
            TextSpan(children: [
              TextSpan(text: "UP:", style: getTextStyle(chartColors.ma10Color, chartStyle.defaultTextSize)),
              formatPrice(data.up, getTextStyle(chartColors.ma10Color, chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.ma10Color, chartStyle.defaultTextSize)),
            ]),
          if (data.dn != 0)
            TextSpan(children: [
              TextSpan(text: "LB:", style: getTextStyle(chartColors.ma30Color, chartStyle.defaultTextSize)),
              formatPrice(data.dn, getTextStyle(chartColors.ma30Color, chartStyle.defaultTextSize)),
              TextSpan(text: "  ", style: getTextStyle(chartColors.ma30Color, chartStyle.defaultTextSize)),
            ]),
        ],
      );
    } else if (state == MainState.ema) {
      span = TextSpan(
        children: [
          for (var config in chartStyle.emaConfigs)
            if (data.emaValues[config.period] != null && data.emaValues[config.period] != 0)
              TextSpan(children: [
                TextSpan(text: "EMA${config.period}:", style: getTextStyle(config.color, chartStyle.defaultTextSize)),
                formatPrice(data.emaValues[config.period]!, getTextStyle(config.color, chartStyle.defaultTextSize)),
                TextSpan(text: "  ", style: getTextStyle(config.color, chartStyle.defaultTextSize)),
              ]),
        ],
      );
    } else if (state == MainState.sar) {
      span = TextSpan(
        children: [
          if (data.sar != 0)
            TextSpan(children: [
              TextSpan(
                text: "SAR:",
                style: getTextStyle(
                  data.sarTrend ? chartColors.sarUpColor : chartColors.sarDownColor,
                  chartStyle.defaultTextSize,
                ),
              ),
              formatPrice(
                data.sar,
                getTextStyle(
                  data.sarTrend ? chartColors.sarUpColor : chartColors.sarDownColor,
                  chartStyle.defaultTextSize,
                ),
              ),
              TextSpan(
                text: "  ",
                style: getTextStyle(
                  data.sarTrend ? chartColors.sarUpColor : chartColors.sarDownColor,
                  chartStyle.defaultTextSize,
                ),
              ),
            ]),
        ],
      );
    }
    if (span == null) return;
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    final size = tp.size;
    // 在 topPadding 区域居中显示：topPadding / 2 是中心，减去 size.height/2 让文本垂直居中
    tp.paint(canvas, Offset(x, topPadding / 2 - size.height / 2));
  }

  @override
  void drawChart(
      CandleEntity lastPoint, CandleEntity curPoint, double lastX, double curX, Size size, Canvas canvas) {
    if (isLine != true) drawCandle(curPoint, canvas, curX);
    if (isLine == true) {
      draLine(lastPoint.close, curPoint.close, canvas, lastX, curX);
    } else if (state == MainState.ma) {
      drawMaLine(lastPoint, curPoint, canvas, lastX, curX);
    } else if (state == MainState.boll) {
      drawBollLine(lastPoint, curPoint, canvas, lastX, curX);
    } else if (state == MainState.ema) {
      drawEmaLine(lastPoint, curPoint, canvas, lastX, curX);
    } else if (state == MainState.sar) {
      drawSarPoints(lastPoint, curPoint, canvas, lastX, curX);
    }
  }

  Shader? mLineFillShader;
  Path mLinePath=Path();
  Path mLineFillPath=Path();

  Paint mLinePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  Paint mLineFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  //画折线图
  draLine(double lastPrice, double curPrice, Canvas canvas, double lastX, double curX) {
//    drawLine(lastPrice + 100, curPrice + 100, canvas, lastX, curX, chartColors.kLineColor);
//     mLinePath ??= Path();

//    if (lastX == curX) {
//      mLinePath.moveTo(lastX, getY(lastPrice));
//    } else {
////      mLinePath.lineTo(curX, getY(curPrice));
//      mLinePath.cubicTo(
//          (lastX + curX) / 2, getY(lastPrice), (lastX + curX) / 2, getY(curPrice), curX, getY(curPrice));
//    }
    if (lastX == curX) lastX = 0;//起点位置填充
    mLinePath.moveTo(lastX, getY(lastPrice));
    mLinePath.cubicTo(
        (lastX + curX) / 2, getY(lastPrice), (lastX + curX) / 2, getY(curPrice), curX, getY(curPrice));

//    //画阴影
    mLineFillShader ??= LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      tileMode: TileMode.clamp,
      colors: chartColors.kLineShadowColor,
    ).createShader(Rect.fromLTRB(chartRect.left, chartRect.top, chartRect.right, chartRect.bottom));
    mLineFillPaint.shader = mLineFillShader;

    // mLineFillPath ??= Path();

    mLineFillPath.moveTo(lastX, chartRect.height + chartRect.top);
    mLineFillPath.lineTo(lastX, getY(lastPrice));
    mLineFillPath.cubicTo(
        (lastX + curX) / 2, getY(lastPrice), (lastX + curX) / 2, getY(curPrice), curX, getY(curPrice));
    mLineFillPath.lineTo(curX, chartRect.height + chartRect.top);
    mLineFillPath.close();

    canvas.drawPath(mLineFillPath, mLineFillPaint);
    mLineFillPath.reset();

    mLinePaint.color = chartColors.kLineColor;
    mLinePaint.strokeWidth = chartStyle.lineStrokeWidth;

    canvas.drawPath(mLinePath, mLinePaint);
    mLinePath.reset();
  }

  void drawMaLine(CandleEntity lastPoint, CandleEntity curPoint, Canvas canvas, double lastX, double curX) {
    if (lastPoint.MA5Price != 0) {
      drawLine(lastPoint.MA5Price, curPoint.MA5Price, canvas, lastX, curX, chartColors.ma5Color);
    }
    if (lastPoint.MA10Price != 0) {
      drawLine(lastPoint.MA10Price, curPoint.MA10Price, canvas, lastX, curX, chartColors.ma10Color);
    }
    if (lastPoint.MA30Price != 0) {
      drawLine(lastPoint.MA30Price, curPoint.MA30Price, canvas, lastX, curX, chartColors.ma30Color);
    }
  }

  void drawBollLine(CandleEntity lastPoint, CandleEntity curPoint, Canvas canvas, double lastX, double curX) {
    if (lastPoint.up != 0) {
      drawLine(lastPoint.up, curPoint.up, canvas, lastX, curX, chartColors.ma10Color);
    }
    if (lastPoint.mb != 0) {
      drawLine(lastPoint.mb, curPoint.mb, canvas, lastX, curX, chartColors.ma5Color);
    }
    if (lastPoint.dn != 0) {
      drawLine(lastPoint.dn, curPoint.dn, canvas, lastX, curX, chartColors.ma30Color);
    }
  }

  void drawEmaLine(CandleEntity lastPoint, CandleEntity curPoint, Canvas canvas, double lastX, double curX) {
    // 根据配置绘制每条EMA线
    for (var config in chartStyle.emaConfigs) {
      int period = config.period;
      double? lastEMA = lastPoint.emaValues[period];
      double? curEMA = curPoint.emaValues[period];
      
      if (lastEMA != null && lastEMA != 0 && curEMA != null && curEMA != 0) {
        drawLine(lastEMA, curEMA, canvas, lastX, curX, config.color);
      }
    }
  }

  void drawSarPoints(CandleEntity lastPoint, CandleEntity curPoint, Canvas canvas, double lastX, double curX) {
    // SAR以独立圆环的形式绘制，围绕K线柱
    // 上升趋势：圆环在K线下方（绿色）
    // 下降趋势：圆环在K线上方（红色）
    // SAR不连接，每个都是独立的圆环，不干扰K线柱的显示
    
    if (curPoint.sar == 0) return;
    
    // 保存chartPaint的原始状态，避免影响后续绘制
    Color originalColor = chartPaint.color;
    PaintingStyle originalStyle = chartPaint.style;
    double originalStrokeWidth = chartPaint.strokeWidth;
    bool originalIsAntiAlias = chartPaint.isAntiAlias;
    
    // 直接使用SAR值对应的Y坐标位置
    double sarY = getY(curPoint.sar);
    Color sarColor = curPoint.sarTrend ? chartColors.sarUpColor : chartColors.sarDownColor;
    
    // 绘制SAR圆环（空心圆，不填充）- 调整尺寸使其更小
    double ringRadius = 2.0; // 圆环半径（从2.5减小到2.0）
    double ringStrokeWidth = 0.8; // 圆环线宽（从1.0减小到0.8）
    
    // 设置SAR绘制属性
    chartPaint.color = sarColor;
    chartPaint.style = PaintingStyle.stroke; // 只绘制边框，不填充
    chartPaint.strokeWidth = ringStrokeWidth;
    chartPaint.isAntiAlias = true;
    
    // 绘制独立的圆环（不连接）
    canvas.drawCircle(Offset(curX, sarY), ringRadius, chartPaint);
    
    // 恢复chartPaint的原始状态，确保不影响后续绘制
    chartPaint.color = originalColor;
    chartPaint.style = originalStyle;
    chartPaint.strokeWidth = originalStrokeWidth;
    chartPaint.isAntiAlias = originalIsAntiAlias;
  }

  void drawCandle(CandleEntity curPoint, Canvas canvas, double curX) {
    var high = getY(curPoint.high);
    var low = getY(curPoint.low);
    var open = getY(curPoint.open);
    var close = getY(curPoint.close);
    double r = mCandleWidth / 2;
    double lineR = mCandleLineWidth / 2;

    if (open > close) {
      chartPaint.color = chartColors.upColor;
      canvas.drawRect(Rect.fromLTRB(curX - r, close, curX + r, open), chartPaint);
      canvas.drawRect(Rect.fromLTRB(curX - lineR, high, curX + lineR, low), chartPaint);
    } else {
      chartPaint.color = chartColors.dnColor;
      canvas.drawRect(Rect.fromLTRB(curX - r, open, curX + r, close), chartPaint);
      canvas.drawRect(Rect.fromLTRB(curX - lineR, high, curX + lineR, low), chartPaint);
    }
  }

  @override
  void drawRightText(canvas, textStyle, int gridRows) {
    double rowSpace = chartRect.height / gridRows;
    for (var i = 0; i <= gridRows; ++i) {
      double position = 0;
      if (i == 0) {
        position = (gridRows - i) * rowSpace - _contentPadding / 2;
      } else if (i == gridRows) {
        position = (gridRows - i) * rowSpace + _contentPadding / 2;
      } else {
        position = (gridRows - i) * rowSpace;
      }
      var value = position / scaleY + minValue;
      TextSpan span = formatPrice(value, textStyle);
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      double y;
      if (i == 0||i == gridRows) {
        y = getY(value) - tp.height / 2;
      } else {
        y = getY(value) - tp.height;
      }
      tp.paint(canvas, Offset(chartRect.width - tp.width, y));
    }
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
//    final int gridRows = 4, gridColumns = 4;
    double rowSpace = chartRect.height / gridRows;
    canvas.drawLine(Offset.zero,
        Offset(chartRect.width, 0), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
    for (int i = 0; i <= gridRows; i++) {
      canvas.drawLine(Offset(0, rowSpace * i + topPadding),
          Offset(chartRect.width, rowSpace * i + topPadding), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
    }
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= columnSpace; i++) {
      // canvas.drawLine(
      //     Offset(columnSpace * i, topPadding / 3), Offset(columnSpace * i, chartRect.bottom), gridPaint);
      canvas.drawLine(
          Offset(columnSpace * i, topPadding), Offset(columnSpace * i, chartRect.bottom), gridPaint..color = chartColors.gridColor..strokeWidth = chartStyle.gridStrokeWidth);
    }
  }
}
