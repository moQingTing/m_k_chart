import 'package:flutter/material.dart' show Color, Colors, TextSpan, TextStyle;
import 'utils/number_util.dart';

/// EMA配置类，包含周期和颜色
class EMAConfig {
  /// EMA周期（天数）
  final int period;
  
  /// EMA线条颜色
  final Color color;
  
  EMAConfig({
    required this.period,
    required this.color,
  });
}

class ChartColors {
  /// 暗模式
  final bool isDarkMode;
  
  /// 上涨颜色
  final Color upColor;
  
  /// 下跌颜色
  final Color downColor;

  ChartColors({
    required this.isDarkMode,
    required this.upColor,
    required this.downColor,
  });

  /// 下跌颜色（缩写形式，向后兼容）
  Color get dnColor => downColor;

  //背景颜色
  Color get bgColor =>
      isDarkMode ? const Color(0xff131723) : const Color(0xffffffff);

  /// 曲线颜色
  Color get kLineColor => const Color(0xff38E5CC);

  /// yx轴交叉线颜色
  Color get xyLineColor => Colors.grey.withOpacity(0.5);

  // 网格线颜色
  Color get gridColor => Colors.grey.withOpacity(0.2);

  //曲线阴影渐变颜色
  List<Color> get kLineShadowColor => [
    kLineColor.withOpacity(0.6),
    kLineColor.withOpacity(0.1)
      ];

  /// ma5 颜色
  Color get ma5Color => Colors.yellow.withOpacity(0.6);

  Color get ma10Color => Colors.pink.withOpacity(0.6);

  Color get ma30Color => Colors.deepPurple.withOpacity(0.6);

  Color get volColor => const Color(0xff4729AE);

  Color get macdColor => const Color(0xff4729AE);

  Color get difColor => const Color(0xffC9B885);

  Color get deaColor => const Color(0xff6CB0A6);

  Color get kColor => const Color(0xffC9B885);

  Color get dColor => const Color(0xff6CB0A6);

  Color get jColor => const Color(0xff9979C6);

  Color get rsiColor => const Color(0xffC9B885);

  // OBV 移动平均线颜色
  Color get maOBVColor => Colors.orange.withOpacity(0.8);

  // SAR 抛物线转向指标颜色（上升趋势）
  Color get sarUpColor => Colors.green.withOpacity(0.8);

  // SAR 抛物线转向指标颜色（下降趋势）
  Color get sarDownColor => Colors.red.withOpacity(0.8);

  //右边y轴刻度
  Color get yAxisTextColor => const Color(0xff60738E);

  //下方时间刻度
  Color get xAxisTextColor => const Color(0xff60738E);

  //最大最小值的颜色
  Color get maxMinTextColor => const Color(0xff60738E);

  //深度颜色
  Color get depthBuyColor => upColor;

  Color get depthSellColor => downColor;

  /// 深度渐变颜色
  List<Color> get depthSellColors => [
        downColor.withOpacity(0.2),
        downColor.withOpacity(0.01)
      ];
  List<Color> get depthBuyColors =>
      [upColor.withOpacity(0.4), upColor.withOpacity(0.05)];

  /// 深度字体颜色
  Color get depthTextColor => Colors.black;

  //选中后显示值边框颜色
  Color get markerBorderColor => const Color(0xff6C7A86);

  //选中后显示值背景的填充颜色
  Color get markerBgColor => const Color(0xff0D1722);

  //实时线颜色等
  Color get realTimeBgColor =>kLineColor;

  Color get rightRealTimeTextColor => const Color(0xffffffff);

  Color get realTimeTextBorderColor => const Color(0xff6C7A86);

  Color get realTimeTextColor => const Color(0xffffffff);

  //实时线
  Color get realTimeLineColor => kLineColor;

  Color get realTimeLongLineColor => kLineColor;

  /// 闪点颜色
  Color get pointColor => Colors.white;
}

class ChartStyle {
  /// 价格格式化回调，返回 TextSpan 富文本
  /// 如果为 null，则使用默认格式化
  final TextSpan Function(double price, TextStyle defaultStyle)? priceFormatter;
  
  /// 数量格式化回调，返回 TextSpan 富文本
  /// 如果为 null，则使用默认格式化
  final TextSpan Function(double volume, TextStyle defaultStyle)? volumeFormatter;

  /// 时间格式化回调，返回 String 字符串
  /// 参数：int date - 时间戳（秒）
  /// 如果为 null，则使用默认格式化
  final String Function(int date)? dateFormatter;

  ChartStyle({
    this.priceFormatter,
    this.volumeFormatter,
    this.dateFormatter,
  });

  /// 默认价格格式化
  TextSpan defaultFormatPrice(double price, TextStyle style) {
    return TextSpan(text: NumberUtil.format(price), style: style);
  }
  
  /// 默认数量格式化
  TextSpan defaultFormatVolume(double volume, TextStyle style) {
    return TextSpan(text: NumberUtil.volFormat(volume), style: style);
  }

  //点与点的距离
  double pointWidth = 8.0;

  //蜡烛宽度
  double candleWidth = 6.0;

  //蜡烛中间线的宽度
  double candleLineWidth = .8;

  //vol柱子宽度
  double volWidth = 6.5;

  //macd柱子宽度
  double macdWidth = 6.5;

  //垂直交叉线宽度
  double vCrossWidth = 0.5;

  //水平交叉线宽度
  double hCrossWidth = 0.5;

  //网格
  int gridRows = 2, gridColumns = 3;

  //网格线宽
  double gridStrokeWidth = 0.5;

  double topPadding = 15.0, bottomDateHigh = 15.0, childPadding = 15.0;

  double defaultTextSize = 10.0;

  /// 实时价格字体大小，如果为 null 则使用 defaultTextSize
  double? realTimeTextSize = 12.0;

  /// 曲线宽度
  double lineStrokeWidth = 1.0;

  /// 虚线宽度
  double dashWidth = 4.0;

  /// 虚线之间间距
  double dashSpace = 4.0;

  /// 是否显示虚线
  bool isShowDashLine = true;

  /// OBV 移动平均线周期，默认30
  int obvPeriod = 30;

  /// EMA配置数组，默认3条：EMA5(黄色)、EMA10(粉色)、EMA30(深紫色)
  List<EMAConfig> emaConfigs = [
    EMAConfig(period: 5, color: Colors.yellow.withOpacity(0.6)),
    EMAConfig(period: 10, color: Colors.pink.withOpacity(0.6)),
    EMAConfig(period: 30, color: Colors.deepPurple.withOpacity(0.6)),
  ];

  /// SAR加速因子初始值，默认0.02
  double sarAFStart = 0.02;

  /// SAR加速因子增量，默认0.02
  double sarAFIncrement = 0.02;

  /// SAR加速因子最大值，默认0.2
  double sarAFMax = 0.2;
}

class TradeKlineChartStyle extends ChartStyle {
  @override
  double get lineStrokeWidth => 2.0;

  @override
  bool get isShowDashLine => false;
}
