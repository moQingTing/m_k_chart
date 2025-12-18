import 'dart:async' show StreamSink;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../entity/k_line_entity.dart';
import '../entity/k_max_min_entity.dart';
import '../k_chart_widget.dart';
import '../utils/data_util.dart';
import '../entity/info_window_entity.dart';

import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

class ChartPainter extends BaseChartPainter {
  // static get maxScrollX => BaseChartPainter.maxScrollX;
  static double maxScrollX = 0.0;
  BaseChartRenderer? mMainRenderer, mVolRenderer, mSecondaryRenderer;
  // BaseChartRenderer? mMainRenderer;
  // 副图
  Map<SecondaryState, BaseChartRenderer> secondaryChartRendererMap = {};
  Map<SecondaryState, Rect> secondaryRectMap = {};
  Map<SecondaryState, KMaxMinEntity> secondaryMaxMinMap = {};
  final List<SecondaryState> secondaryStates;

  StreamSink<InfoWindowEntity?> sink;
  AnimationController? controller;
  double opacity;
  ChartColors chartColors;
  // final ChartStyle chartStyle;

  ChartPainter(
      {@required datas,
      @required scaleX,
      @required scrollX,
      @required isLongPass,
      @required selectX,
      required this.chartColors,
      required ChartStyle chartStyle,
      required this.secondaryStates,
      mainState,
      // volState,
      // secondaryState,
      required this.sink,
      bool isLine = false,
      this.controller,
      this.opacity = 0.0})
      : super(
            datas: datas,
            scaleX: scaleX,
            scrollX: scrollX,
            isLongPress: isLongPass,
            chartStyle: chartStyle,
            selectX: selectX,
            mainState: mainState,
            // volState: volState,
            // secondaryState: secondaryState,
            isLine: isLine);

  @override
  void initRect(Size size) {
    super.initRect(size);

    double mainHeight = (mDisplayHeight) * (1 - secondaryStates.length * 0.2);
    if (mainHeight < mMainDisplayMinHeight) {
      mainHeight = mMainDisplayMinHeight;
    }

    double secondaryHeight =
        (mDisplayHeight - mainHeight) / secondaryStates.length;

    // 主图rect
    mMainRect = Rect.fromLTRB(
        0, chartStyle.topPadding, mWidth, chartStyle.topPadding + mainHeight);

    // 副图
    var secondaryTop = mMainRect.bottom;
    for (var secondaryState in secondaryStates) {
      final secondaryRect = Rect.fromLTRB(
          0, secondaryTop, mWidth, secondaryTop + secondaryHeight);
      secondaryRectMap[secondaryState] = secondaryRect;
      secondaryTop = secondaryTop + secondaryHeight;
    }
  }

  @override
  calculateValue() {
    super.calculateValue();
    if (datas == null || (datas?.length ?? 0) == 0) return;
    maxScrollX = getMinTranslateX().abs();
    setTranslateXFromScrollX(scrollX);
    mStartIndex = indexOfTranslateX(xToTranslateX(0));
    mStopIndex = indexOfTranslateX(xToTranslateX(mWidth));
    for (int i = mStartIndex; i <= mStopIndex; i++) {
      var item = datas![i];
      getMainMaxMinValue(item, i);
      // getVolMaxMinValue(item);
      // getSecondaryMaxMinValue(item,secondaryState);
    }

    // 计算副图最大最小
    for (var secondaryState in secondaryStates) {
      final maxMinEntity = secondaryMaxMinMap[secondaryState] ??
          KMaxMinEntity(-double.maxFinite, double.maxFinite);
      for (int i = mStartIndex; i <= mStopIndex; i++) {
        var item = datas![i];
        getSecondaryMaxMinValue(item, secondaryState, maxMinEntity);
      }
      secondaryMaxMinMap[secondaryState] = maxMinEntity;
    }
  }

  @override
  void initChartRenderer() {
    mMainRenderer ??= MainRenderer(mMainRect, mMainMaxValue, mMainMinValue,
        chartStyle.topPadding, mainState, isLine, chartStyle, chartColors);

    // 副图
    for (var entity in secondaryRectMap.entries) {
      final secondaryState = entity.key;
      final rect = entity.value;
      final maxMinEntity = secondaryMaxMinMap[secondaryState] ??
          KMaxMinEntity(double.maxFinite, -double.maxFinite);

      if (secondaryState == SecondaryState.vol) {
        secondaryChartRendererMap[secondaryState] = VolRenderer(
            rect,
            maxMinEntity.max,
            maxMinEntity.min,
            chartStyle.childPadding,
            chartStyle,
            chartColors);
      } else {
        secondaryChartRendererMap[secondaryState] = SecondaryRenderer(
            rect,
            maxMinEntity.max,
            maxMinEntity.min,
            chartStyle.childPadding,
            secondaryState,
            chartStyle,
            chartColors);
      }
    }

    // if(volState != VolState.none)mVolRenderer ??= VolRenderer(mVolRect, mVolMaxValue, mVolMinValue, chartStyle.childPadding,chartStyle,chartColors);
    // if (secondaryState != SecondaryState.none){
    //   mSecondaryRenderer ??= SecondaryRenderer(
    //       mSecondaryRect,
    //       mSecondaryMaxValue,
    //       mSecondaryMinValue,
    //       chartStyle.childPadding,
    //       secondaryState,
    //       chartStyle,
    //       chartColors);
  }

  final Paint mBgPaint = Paint();

  @override
  void drawBg(Canvas canvas, Size size) {
    mBgPaint.color = chartColors.bgColor;

    Rect mainRect = Rect.fromLTRB(
        0, 0, mMainRect.width, mMainRect.height + chartStyle.topPadding);
    canvas.drawRect(mainRect, mBgPaint);

    // Rect volRect = Rect.fromLTRB(0, mVolRect.top - chartStyle.childPadding, mVolRect.width, mVolRect.bottom);
    // canvas.drawRect(volRect, mBgPaint);
    //
    // Rect secondaryRect =
    // Rect.fromLTRB(0, mSecondaryRect.top - chartStyle.childPadding, mSecondaryRect.width, mSecondaryRect.bottom);
    // canvas.drawRect(secondaryRect, mBgPaint);

    Rect dateRect = Rect.fromLTRB(
        0, size.height - chartStyle.bottomDateHigh, size.width, size.height);
    canvas.drawRect(dateRect, mBgPaint);
  }

  @override
  void drawGrid(canvas) {
    mMainRenderer?.drawGrid(
        canvas, chartStyle.gridRows, chartStyle.gridColumns);
    // mVolRenderer?.drawGrid(canvas, chartStyle.gridRows, chartStyle.gridColumns);
    // mSecondaryRenderer?.drawGrid(canvas, chartStyle.gridRows, chartStyle.gridColumns);
    // 副图
    for (var entity in secondaryChartRendererMap.entries) {
      entity.value
          .drawGrid(canvas, chartStyle.gridRows, chartStyle.gridColumns);
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity curPoint = datas![i];
      // if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);

      mMainRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      // mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      // mSecondaryRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      // 副图
      for (var entity in secondaryChartRendererMap.entries) {
        entity.value.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      }
    }

    if (isLongPress == true) drawCrossLine(canvas, size);
    canvas.restore();
  }

  @override
  void drawRightText(canvas) {
    var textStyle = getTextStyle(chartColors.yAxisTextColor, chartStyle.defaultTextSize);
    mMainRenderer?.drawRightText(canvas, textStyle, chartStyle.gridRows);
    // mVolRenderer?.drawRightText(canvas, textStyle, chartStyle.gridRows);
    // mSecondaryRenderer?.drawRightText(canvas, textStyle, chartStyle.gridRows);
    // 副图
    for (var entity in secondaryChartRendererMap.entries) {
      entity.value.drawRightText(canvas, textStyle, chartStyle.gridRows);
    }
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    double columnSpace = size.width / chartStyle.gridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double y = 0.0;
    for (var i = 0; i <= chartStyle.gridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);
      if (translateX >= startX && translateX <= stopX) {
        int index = indexOfTranslateX(translateX);
        if (datas?[index] == null) continue;
        TextPainter tp = getTextPainter(DataUtil.getDate(datas![index].id, chartStyle.dateFormatter),
            color: chartColors.xAxisTextColor);
        y = size.height -
            (chartStyle.bottomDateHigh - tp.height) / 2 -
            tp.height;
        tp.paint(canvas, Offset(columnSpace * i - tp.width / 2, y));
      }
    }
  }

  Paint selectPointPaint = Paint()
    ..isAntiAlias = true
    ..strokeWidth = 0.2;

  Paint selectorBorderPaint = Paint()
    ..isAntiAlias = true
    ..strokeWidth = 0.2
    ..style = PaintingStyle.stroke;

  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    selectPointPaint.color = chartColors.markerBgColor;
    selectorBorderPaint.color = chartColors.markerBorderColor;

    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index) as KLineEntity;

    TextSpan priceSpan = formatPrice(point.close, getTextStyle(Colors.white, chartStyle.defaultTextSize));
    TextPainter tp = TextPainter(text: priceSpan, textDirection: TextDirection.ltr);
    tp.layout();
    double textHeight = tp.height;
    double textWidth = tp.width;

    double w1 = 5;
    double w2 = 3;
    double r = textHeight / 2 + w2;
    double y = getMainY(point.close);
    double x;
    bool isLeft = false;
    if (translateXtoX(getX(index)) < mWidth / 2) {
      isLeft = false;
      x = 1;
      Path path = Path();
      path.moveTo(x, y - r);
      path.lineTo(x, y + r);
      path.lineTo(textWidth + 2 * w1, y + r);
      path.lineTo(textWidth + 2 * w1 + w2, y);
      path.lineTo(textWidth + 2 * w1, y - r);
      path.close();
      canvas.drawPath(path, selectPointPaint);
      canvas.drawPath(path, selectorBorderPaint);
      tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    } else {
      isLeft = true;
      x = mWidth - textWidth - 1 - 2 * w1 - w2;
      Path path = Path();
      path.moveTo(x, y);
      path.lineTo(x + w2, y + r);
      path.lineTo(mWidth - 2, y + r);
      path.lineTo(mWidth - 2, y - r);
      path.lineTo(x + w2, y - r);
      path.close();
      canvas.drawPath(path, selectPointPaint);
      canvas.drawPath(path, selectorBorderPaint);
      tp.paint(canvas, Offset(x + w1 + w2, y - textHeight / 2));
    }

    TextPainter dateTp = getTextPainter(DataUtil.getDate(point.id, chartStyle.dateFormatter), color: Colors.white);
    textWidth = dateTp.size.width;
    r = textHeight / 2;
    x = translateXtoX(getX(index));
    y = size.height - chartStyle.bottomDateHigh;

    if (x < textWidth + 2 * w1) {
      x = 1 + textWidth / 2 + w1;
    } else if (mWidth - x < textWidth + 2 * w1) {
      x = mWidth - 1 - textWidth / 2 - w1;
    }
    double baseLine = textHeight / 2;
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectPointPaint);
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectorBorderPaint);

    dateTp.paint(canvas, Offset(x - textWidth / 2, y));
    //长按显示这条数据详情
    sink.add(InfoWindowEntity(point, isLeft));
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    //长按显示按中的数据
    if (isLongPress) {
      var index = calculateSelectedX(selectX);
      data = getItem(index) as KLineEntity;
    }
    //松开显示最后一条数据
    mMainRenderer?.drawText(canvas, data, x);
    // mVolRenderer?.drawText(canvas, data, x);
    // mSecondaryRenderer?.drawText(canvas, data, x);
    // 副图
    for (var entity in secondaryChartRendererMap.entries) {
      entity.value.drawText(canvas, data, x);
    }
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine == true) return;
    //绘制最大值和最小值
    double x = translateXtoX(getX(mMainMinIndex));
    double y = getMainY(mMainLowMinValue);
    TextStyle minMaxStyle = getTextStyle(chartColors.maxMinTextColor, chartStyle.defaultTextSize);
    if (x < mWidth / 2) {
      //画右边
      TextSpan span = TextSpan(children: [
        TextSpan(text: "── ", style: minMaxStyle),
        formatPrice(mMainLowMinValue, minMaxStyle),
      ]);
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextSpan span = TextSpan(children: [
        formatPrice(mMainLowMinValue, minMaxStyle),
        TextSpan(text: " ──", style: minMaxStyle),
      ]);
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
    x = translateXtoX(getX(mMainMaxIndex));
    y = getMainY(mMainHighMaxValue);
    if (x < mWidth / 2) {
      //画右边
      TextSpan span = TextSpan(children: [
        TextSpan(text: "── ", style: minMaxStyle),
        formatPrice(mMainHighMaxValue, minMaxStyle),
      ]);
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextSpan span = TextSpan(children: [
        formatPrice(mMainHighMaxValue, minMaxStyle),
        TextSpan(text: " ──", style: minMaxStyle),
      ]);
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
  }

  ///画交叉线
  void drawCrossLine(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index) as KLineEntity;
    Paint paintY = Paint()
      ..color = chartColors.xyLineColor
      ..strokeWidth = chartStyle.vCrossWidth
      ..isAntiAlias = true;
    double x = getX(index);
    double y = getMainY(point.close);
    // k线图竖线
    canvas.drawLine(Offset(x, chartStyle.topPadding),
        Offset(x, size.height - chartStyle.bottomDateHigh), paintY);

    Paint paintX = Paint()
      ..color = chartColors.xyLineColor
      ..strokeWidth = chartStyle.hCrossWidth
      ..isAntiAlias = true;
    // k线图横线
    canvas.drawLine(Offset(-mTranslateX, y),
        Offset(-mTranslateX + mWidth / scaleX, y), paintX);
    canvas.drawCircle(Offset(x, y), 2.0, paintX);
  }

  final Paint realTimePaint = Paint()
        ..strokeWidth = 0.2
        ..isAntiAlias = true,
      pointPaint = Paint();

  ///画实时价格线
  @override
  void drawRealTimePrice(Canvas canvas, Size size) {
    if (mMarginRight == 0 || datas?.isEmpty == true) return;
    KLineEntity point = datas!.last;
    TextSpan priceSpan = formatPrice(point.close, getTextStyle(chartColors.rightRealTimeTextColor, chartStyle.realTimeTextSize ?? chartStyle.defaultTextSize));
    TextPainter tp = TextPainter(text: priceSpan, textDirection: TextDirection.ltr);
    tp.layout();
    // 价格内间距
    double tpPadding = 5;
    double y = getMainY(point.close);

    //max越往右边滑值越小
    var max = (mTranslateX.abs() +
            mMarginRight -
            getMinTranslateX().abs() +
            mPointWidth) *
        scaleX;

    double x = mWidth - max;
    if (!isLine) x += mPointWidth / 2;
    var dashWidth = chartStyle.dashWidth;
    var dashSpace = chartStyle.dashSpace;
    double startX = 0;
    final space = (dashSpace + dashWidth);
    if (tp.width < max) {
      if (chartStyle.isShowDashLine) {
        // 最新价格显示在y轴上时的虚线,
        while (startX < (max - tp.size.width - tpPadding - tpPadding)) {
          canvas.drawLine(
              Offset(x + startX, y),
              Offset(x + startX + dashWidth, y),
              realTimePaint..color = chartColors.realTimeLineColor);
          startX += space;
        }
      }

      //画一闪一闪
      if (isLine) {
        startAnimation();
        Gradient pointGradient = RadialGradient(colors: [
          chartColors.pointColor.withOpacity(opacity),
          Colors.transparent
        ]);
        pointPaint.shader = pointGradient
            .createShader(Rect.fromCircle(center: Offset(x, y), radius: 12.0));
        canvas.drawCircle(Offset(x, y), 14.0, pointPaint);
        canvas.drawCircle(
            Offset(x, y), 2.0, realTimePaint..color = chartColors.pointColor);
      } else {
        stopAnimation(); //停止一闪闪
      }
      double left = mWidth - tp.width;
      double top = y - tp.height / 2;
      double radius = 2;
      // 画实时价格背景
      RRect rectBg1 = RRect.fromLTRBR(
          left - tpPadding,
          top,
          left + tp.width + tpPadding,
          top + tp.height,
          Radius.circular(radius));
      canvas.drawRRect(
          rectBg1, realTimePaint..color = chartColors.realTimeBgColor);
      tp.paint(canvas, Offset(left, top));
    } else {
      stopAnimation(); //停止一闪闪
      startX = 0;
      if (point.close > mMainMaxValue) {
        y = getMainY(mMainMaxValue);
      } else if (point.close < mMainMinValue) {
        y = getMainY(mMainMinValue);
      }

      // 实时价格显示在图表上的虚线
      if (chartStyle.isShowDashLine) {
        while (startX < mWidth) {
          canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y),
              realTimePaint..color = chartColors.realTimeLongLineColor);
          startX += space;
        }
      }

      const padding = 3.0;
      const triangleHeight = 8.0; //三角高度
      const triangleWidth = 5.0; //三角宽度

      double left = mWidth - tp.width * 2.5;
      double top = y - tp.height / 2 - padding;
      //加上三角形的宽以及padding
      double right = left + tp.width + padding * 2 + triangleWidth + padding;
      double bottom = top + tp.height + padding * 2;
      double radius = (bottom - top) / 2;
      //画椭圆背景
      RRect rectBg1 =
          RRect.fromLTRBR(left, top, right, bottom, Radius.circular(radius));
      RRect rectBg2 = RRect.fromLTRBR(left - 1, top - 1, right + 1, bottom + 1,
          Radius.circular(radius + 2));
      canvas.drawRRect(
          rectBg2, realTimePaint..color = chartColors.realTimeTextBorderColor);

      // 画实时价格背景
      canvas.drawRRect(
          rectBg1, realTimePaint..color = chartColors.realTimeBgColor);
      TextSpan priceSpan = formatPrice(point.close, getTextStyle(chartColors.realTimeTextColor, chartStyle.realTimeTextSize ?? chartStyle.defaultTextSize));
      tp = TextPainter(text: priceSpan, textDirection: TextDirection.ltr);
      tp.layout();
      Offset textOffset = Offset(left + padding, y - tp.height / 2);
      tp.paint(canvas, textOffset);
      //画三角
      Path path = Path();
      double dx = tp.width + textOffset.dx + padding;
      double dy = top + (bottom - top - triangleHeight) / 2;
      path.moveTo(dx, dy);
      path.lineTo(dx + triangleWidth, dy + triangleHeight / 2);
      path.lineTo(dx, dy + triangleHeight);
      path.close();
      canvas.drawPath(
          path,
          realTimePaint
            ..color = chartColors.realTimeTextColor
            ..shader = null);
    }
  }

  TextPainter getTextPainter(text, {color = Colors.white}) {
    // if (kDebugMode) {
    //   print('getTextPainter $text');
    // }
    TextSpan span = TextSpan(text: "$text", style: getTextStyle(color, chartStyle.defaultTextSize));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }


  double getMainY(double y) => mMainRenderer?.getY(y) ?? 0.0;

  startAnimation() {
    if (controller?.isAnimating != true) controller?.repeat(reverse: true);
  }

  stopAnimation() {
    if (controller?.isAnimating == true) controller?.stop();
  }
}
