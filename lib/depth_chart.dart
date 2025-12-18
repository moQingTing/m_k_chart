import 'dart:math';

import 'package:flutter/material.dart';
import 'chart_style.dart';
import 'entity/depth_entity.dart';

class DepthChart extends StatefulWidget {
  final List<DepthEntity> bids, asks;
  final int decimal;
  final ChartColors chartColors;
  final ChartStyle? chartStyle;

  const DepthChart(this.bids, this.asks, this.decimal, this.chartColors,
      {super.key, this.chartStyle});

  @override
  _DepthChartState createState() => _DepthChartState();
}

class _DepthChartState extends State<DepthChart> {
  Offset? pressOffset;
  bool isLongPress = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        pressOffset = details.globalPosition;
        isLongPress = true;
        setState(() {});
      },
      onLongPressMoveUpdate: (details) {
        pressOffset = details.globalPosition;
        isLongPress = true;
        setState(() {});
      },
      onTap: () {
        if (isLongPress) {
          isLongPress = false;
          setState(() {});
        }
      },
      child: CustomPaint(
        size: const Size(double.infinity, double.infinity),
            painter: DepthChartPainter(
            mBuyData: widget.bids,
            mSellData: widget.asks,
            pressOffset: pressOffset ?? Offset.zero,
            isLongPress: isLongPress,
            chartColors: widget.chartColors,
            chartStyle: widget.chartStyle),
      ),
    );
  }
}

class DepthChartPainter extends CustomPainter {
  //买入//卖出
  List<DepthEntity> mBuyData, mSellData;

  /// 颜色
  final ChartColors chartColors;
  
  /// 样式配置（可选）
  final ChartStyle? chartStyle;

  Offset pressOffset = Offset.zero;
  bool isLongPress = false;

  double mPaddingBottom = 18.0;
  double mWidth = 0.0,
      mDrawHeight = 0.0,
      mDrawWidth = 0.0,
      mBuyPointWidth = 0.0,
      mSellPointWidth = 0.0;

  //最大的委托量
  double? mMaxVolume, mMultiple;

  //右侧绘制个数
  int mLineCount = 4;

  Path? mBuyPath, mSellPath;

  // 小数位
  int decimal = 2;

  //买卖出区域边线绘制画笔  //买卖出取悦绘制画笔
  Paint? mBuyLinePaint, mSellLinePaint, mBuyPathPaint, mSellPathPaint;

  Paint selectPaint = Paint()..isAntiAlias = true;

  Paint selectBorderPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  DepthChartPainter(
      {required this.mBuyData,
      required this.mSellData,
      required this.pressOffset,
      required this.isLongPress,
      required this.chartColors,
      this.chartStyle}) {
    mBuyLinePaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.depthBuyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    mSellLinePaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.depthSellColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    mBuyPathPaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.depthBuyColor.withOpacity(0.5);
    mSellPathPaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.depthSellColor.withOpacity(0.5);
    mBuyPath ??= Path();
    mSellPath ??= Path();

    selectPaint.color = chartColors.markerBgColor;
    selectBorderPaint.color = chartColors.markerBorderColor;

    init();
  }

  void init() {
    if (mBuyData.isEmpty || mSellData.isEmpty) return;
    mMaxVolume = mBuyData[0].amount;
    mMaxVolume = max(mMaxVolume!, mSellData.last.amount);
    mMaxVolume = mMaxVolume! * 1.05;
    mMultiple = mMaxVolume! / mLineCount;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (mBuyData.isEmpty || mSellData.isEmpty) return;
    mWidth = size.width;
    mDrawWidth = mWidth / 2;
    mDrawHeight = size.height - mPaddingBottom;
//    canvas.drawColor(Colors.black, BlendMode.color);
    canvas.save();
    //绘制买入区域
    drawBuy(canvas);
    //绘制卖出区域
    drawSell(canvas);

    //绘制界面相关文案
    drawText(canvas);
    canvas.restore();
  }

  void drawBuy(Canvas canvas) {
    mBuyPointWidth =
        (mDrawWidth / (mBuyData.length - 1 == 0 ? 1 : mBuyData.length - 1));
    mBuyPath?.reset();
    double y;
    for (int i = 0; i < mBuyData.length; i++) {
      if (i == 0) {
        mBuyPath?.moveTo(0, getY(mBuyData[0].amount));
      }
      y = getY(mBuyData[i].amount);
      if (i >= 1) {
        canvas.drawLine(
            Offset(mBuyPointWidth * (i - 1), getY(mBuyData[i - 1].amount)),
            Offset(mBuyPointWidth * i, y),
            mBuyLinePaint!);
      }
      if (i != mBuyData.length - 1) {
        mBuyPath?.quadraticBezierTo(mBuyPointWidth * i, y,
            mBuyPointWidth * (i + 1), getY(mBuyData[i + 1].amount));
      }

      if (i == mBuyData.length - 1) {
        mBuyPath?.quadraticBezierTo(
            mBuyPointWidth * i, y, mBuyPointWidth * i, mDrawHeight);
        mBuyPath?.quadraticBezierTo(
            mBuyPointWidth * i, mDrawHeight, 0, mDrawHeight);
        mBuyPath?.close();
      }
    }
    final mLineFillShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      tileMode: TileMode.clamp,
      colors: chartColors.depthBuyColors,
    ).createShader(Rect.fromLTRB(0, 0, mDrawWidth, mDrawHeight));
    mBuyPathPaint!.shader = mLineFillShader;
    canvas.drawPath(mBuyPath!, mBuyPathPaint!);
  }

  void drawSell(Canvas canvas) {
    mSellPointWidth =
        (mDrawWidth / (mSellData.length - 1 == 0 ? 1 : mSellData.length - 1));
    mSellPath?.reset();
    double y;
    for (int i = 0; i < mSellData.length; i++) {
      if (i == 0) {
        mSellPath?.moveTo(mDrawWidth, getY(mSellData[0].amount));
      }
      y = getY(mSellData[i].amount);
      if (i >= 1) {
        canvas.drawLine(
            Offset((mSellPointWidth * (i - 1)) + mDrawWidth,
                getY(mSellData[i - 1].amount)),
            Offset((mSellPointWidth * i) + mDrawWidth, y),
            mSellLinePaint!);
      }
      if (i != mSellData.length - 1) {
        mSellPath?.quadraticBezierTo(
            (mSellPointWidth * i) + mDrawWidth,
            y,
            (mSellPointWidth * (i + 1)) + mDrawWidth,
            getY(mSellData[i + 1].amount));
      }
      if (i == mSellData.length - 1) {
        mSellPath?.quadraticBezierTo(
            mWidth, y, (mSellPointWidth * i) + mDrawWidth, mDrawHeight);
        mSellPath?.quadraticBezierTo((mSellPointWidth * i) + mDrawWidth,
            mDrawHeight, mDrawWidth, mDrawHeight);
        mSellPath?.close();
      }
    }
    final mLineFillShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      tileMode: TileMode.clamp,
      colors: chartColors.depthSellColors,
    ).createShader(Rect.fromLTRB(0, 0, mDrawWidth, mDrawHeight));
    mSellPathPaint!.shader = mLineFillShader;

    canvas.drawPath(mSellPath!, mSellPathPaint!);
  }

  int mLastPosition = 0;

  void drawText(Canvas canvas) {
    TextStyle defaultStyle = TextStyle(
        color: chartColors.depthTextColor, fontSize: 10);
    
    // 绘制右侧数量
    for (int j = 0; j < mLineCount; j++) {
      double value = (mMaxVolume ?? 0) - (mMultiple ?? 0) * j;
      TextSpan volumeSpan = formatVolume(value, defaultStyle);
      TextPainter tp = TextPainter(
          text: volumeSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(
          canvas,
          Offset(
              mWidth - tp.width, mDrawHeight / mLineCount * j + tp.height / 2));
    }
    
    // 绘制底部价格
    TextSpan startSpan = formatPrice(mBuyData.first.price, defaultStyle);
    TextPainter startTP = TextPainter(
        text: startSpan, textDirection: TextDirection.ltr);
    startTP.layout();
    startTP.paint(canvas, Offset(0, getBottomTextY(startTP.height)));

    double centerPrice = (mBuyData.last.price + mSellData.first.price) / 2;
    TextSpan centerSpan = formatPrice(centerPrice, defaultStyle);
    TextPainter centerTP = TextPainter(
        text: centerSpan, textDirection: TextDirection.ltr);
    centerTP.layout();
    centerTP.paint(
        canvas,
        Offset(
            mDrawWidth - centerTP.width / 2, getBottomTextY(centerTP.height)));

    TextSpan endSpan = formatPrice(mSellData.last.price, defaultStyle);
    TextPainter endTP = TextPainter(
        text: endSpan, textDirection: TextDirection.ltr);
    endTP.layout();
    endTP.paint(
        canvas, Offset(mWidth - endTP.width, getBottomTextY(endTP.height)));

    if (isLongPress == true) {
      if (pressOffset.dx <= mDrawWidth) {
        int index =
            _indexOfTranslateX(pressOffset.dx, 0, mBuyData.length, getBuyX);
        drawSelectView(canvas, index, true);
      } else {
        int index =
            _indexOfTranslateX(pressOffset.dx, 0, mSellData.length, getSellX);
        drawSelectView(canvas, index, false);
      }
    }
  }

  void drawSelectView(Canvas canvas, int index, bool isLeft) {
    DepthEntity entity = isLeft ? mBuyData[index] : mSellData[index];
    double dx = isLeft ? getBuyX(index) : getSellX(index);

    double radius = 8.0;
    if (dx < mDrawWidth) {
      canvas.drawCircle(Offset(dx, getY(entity.amount)), radius / 3,
          mBuyLinePaint!..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(dx, getY(entity.amount)), radius,
          mBuyLinePaint!..style = PaintingStyle.stroke);
    } else {
      canvas.drawCircle(Offset(dx, getY(entity.amount)), radius / 3,
          mSellLinePaint!..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(dx, getY(entity.amount)), radius,
          mSellLinePaint!..style = PaintingStyle.stroke);
    }

    //画底部
    TextStyle defaultStyle = TextStyle(
        color: chartColors.depthTextColor, fontSize: 10);
    TextSpan priceSpan = formatPrice(entity.price, defaultStyle);
    TextPainter priceTP = TextPainter(
        text: priceSpan, textDirection: TextDirection.ltr);
    priceTP.layout();
    double left;
    if (dx <= priceTP.width / 2) {
      left = 0;
    } else if (dx >= mWidth - priceTP.width / 2) {
      left = mWidth - priceTP.width;
    } else {
      left = dx - priceTP.width / 2;
    }
    Rect bottomRect = Rect.fromLTRB(left - 3, mDrawHeight + 3,
        left + priceTP.width + 3, mDrawHeight + mPaddingBottom);
    canvas.drawRect(bottomRect, selectPaint);
    canvas.drawRect(bottomRect, selectBorderPaint);
    priceTP.paint(
        canvas,
        Offset(bottomRect.left + (bottomRect.width - priceTP.width) / 2,
            bottomRect.top + (bottomRect.height - priceTP.height) / 2));
    //画左边
    TextSpan amountSpan = formatVolume(entity.amount, defaultStyle);
    TextPainter amountTP = TextPainter(
        text: amountSpan, textDirection: TextDirection.ltr);
    amountTP.layout();
    double y = getY(entity.amount);
    double rightRectTop;
    if (y <= amountTP.height / 2) {
      rightRectTop = 0;
    } else if (y >= mDrawHeight - amountTP.height / 2) {
      rightRectTop = mDrawHeight - amountTP.height;
    } else {
      rightRectTop = y - amountTP.height / 2;
    }
    Rect rightRect = Rect.fromLTRB(mWidth - amountTP.width - 6,
        rightRectTop - 3, mWidth, rightRectTop + amountTP.height + 3);
    canvas.drawRect(rightRect, selectPaint);
    canvas.drawRect(rightRect, selectBorderPaint);
    amountTP.paint(
        canvas,
        Offset(rightRect.left + (rightRect.width - amountTP.width) / 2,
            rightRect.top + (rightRect.height - amountTP.height) / 2));
  }

  ///二分查找当前值的index
  int _indexOfTranslateX(double translateX, int start, int end, Function getX) {
    if (end == start || end == -1) {
      return start;
    }
    if (end - start == 1) {
      double startValue = getX(start);
      double endValue = getX(end);
      return (translateX - startValue).abs() < (translateX - endValue).abs()
          ? start
          : end;
    }
    int mid = start + (end - start) ~/ 2;
    double midValue = getX(mid);
    if (translateX < midValue) {
      return _indexOfTranslateX(translateX, start, mid, getX);
    } else if (translateX > midValue) {
      return _indexOfTranslateX(translateX, mid, end, getX);
    } else {
      return mid;
    }
  }

  double getBuyX(int position) => position * mBuyPointWidth;

  double getSellX(int position) => position * mSellPointWidth + mDrawWidth;

  getTextPainter(String text, [Color color = Colors.grey]) => TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.ltr);

  /// 格式化价格，使用回调或默认格式化
  TextSpan formatPrice(double price, TextStyle defaultStyle) {
    if (chartStyle?.priceFormatter != null) {
      return chartStyle!.priceFormatter!(price, defaultStyle);
    }
    // 如果没有提供回调，使用默认格式化（保留小数位）
    return TextSpan(
        text: price.toStringAsFixed(decimal), style: defaultStyle);
  }

  /// 格式化数量，使用回调或默认格式化
  TextSpan formatVolume(double volume, TextStyle defaultStyle) {
    if (chartStyle?.volumeFormatter != null) {
      return chartStyle!.volumeFormatter!(volume, defaultStyle);
    }
    // 如果没有提供回调，使用默认格式化（保留小数位）
    return TextSpan(
        text: volume.toStringAsFixed(decimal), style: defaultStyle);
  }

  double getBottomTextY(double textHeight) =>
      (mPaddingBottom - textHeight) / 2 + mDrawHeight;

  double getY(double volume) =>
      mDrawHeight - (mDrawHeight) * volume / (mMaxVolume ?? 0);

  @override
  bool shouldRepaint(DepthChartPainter oldDelegate) {
//    return oldDelegate.mBuyData != mBuyData ||
//        oldDelegate.mSellData != mSellData ||
//        oldDelegate.isLongPress != isLongPress ||
//        oldDelegate.pressOffset != pressOffset;
    return true;
  }
}
