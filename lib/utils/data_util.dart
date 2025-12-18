import 'dart:math';

import '../entity/k_line_entity.dart';
import '../chart_style.dart';
import 'date_format_util.dart';
class DataUtil {
    static String getDate(int date, [String Function(int date)? dateFormatter]) {
    if (dateFormatter != null) {
      return dateFormatter(date);
    }
    return dateFormat(
        DateTime.fromMillisecondsSinceEpoch(date * 1000, isUtc: false),
        [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn]);
  }
  static void calculate(List<KLineEntity> dataList, {int obvPeriod = 30, List<EMAConfig>? emaConfigs, ChartStyle? chartStyle}) {
    if (dataList.isEmpty) return;
    _calcMA(dataList);
    _calcBOLL(dataList);
    _calcVolumeMA(dataList);
    _calcKDJ(dataList);
    _calcMACD(dataList);
    _calcRSI(dataList);
    _calcWR(dataList);
    _calcOBV(dataList);
    _calcOBVMA(dataList, obvPeriod); // 计算 OBV 移动平均线
    if (emaConfigs != null && emaConfigs.isNotEmpty) {
      _calcEMA(dataList, emaConfigs); // 计算 EMA 指数移动平均线
    }
    if (chartStyle != null) {
      _calcSAR(dataList, chartStyle); // 计算 SAR 抛物线转向指标
    }
  }

  static void _calcMA(List<KLineEntity> dataList, [bool isLast = false]) {
    double ma5 = 0;
    double ma10 = 0;
    double ma20 = 0;
    double ma30 = 0;
//    double ma60 = 0;

    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      var data = dataList[dataList.length - 2];
      ma5 = data.MA5Price * 5;
      ma10 = data.MA10Price * 10;
      ma20 = data.MA20Price * 20;
      ma30 = data.MA30Price * 30;
//      ma60 = data.MA60Price * 60;
    }
    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      final closePrice = entity.close;
      ma5 += closePrice;
      ma10 += closePrice;
      ma20 += closePrice;
      ma30 += closePrice;
//      ma60 += closePrice;

      if (i == 4) {
        entity.MA5Price = ma5 / 5;
      } else if (i >= 5) {
        ma5 -= dataList[i - 5].close;
        entity.MA5Price = ma5 / 5;
      } else {
        entity.MA5Price = 0;
      }
      if (i == 9) {
        entity.MA10Price = ma10 / 10;
      } else if (i >= 10) {
        ma10 -= dataList[i - 10].close;
        entity.MA10Price = ma10 / 10;
      } else {
        entity.MA10Price = 0;
      }
      if (i == 19) {
        entity.MA20Price = ma20 / 20;
      } else if (i >= 20) {
        ma20 -= dataList[i - 20].close;
        entity.MA20Price = ma20 / 20;
      } else {
        entity.MA20Price = 0;
      }
      if (i == 29) {
        entity.MA30Price = ma30 / 30;
      } else if (i >= 30) {
        ma30 -= dataList[i - 30].close;
        entity.MA30Price = ma30 / 30;
      } else {
        entity.MA30Price = 0;
      }
//      if (i == 59) {
//        entity.MA60Price = ma60 / 60;
//      } else if (i >= 60) {
//        ma60 -= dataList[i - 60].close;
//        entity.MA60Price = ma60 / 60;
//      } else {
//        entity.MA60Price = 0;
//      }
    }
  }

  static void _calcBOLL(List<KLineEntity> dataList, [bool isLast = false]) {
    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
    }
    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      if (i < 19) {
        entity.mb = 0;
        entity.up = 0;
        entity.dn = 0;
      } else {
        // 时间周期（通常为20）
        int n = 20;
        double md = 0;
        for (int j = i - n + 1; j <= i; j++) {
          double c = dataList[j].close;
          double m = entity.MA20Price;
          double value = c - m;
          md += value * value;
        }
        // md = md / (n - 1);
        md = md / n;
        md = sqrt(md);
        entity.mb = entity.MA20Price;
        entity.up = entity.mb + 2.0 * md;
        entity.dn = entity.mb - 2.0 * md;
      }
    }
  }

  // EMA (Exponential Moving Average) 指数移动平均线计算
  // EMA公式：EMA(period) = (当前收盘价 * 2 / (period + 1)) + (前一日EMA * (period - 1) / (period + 1))
  static void _calcEMA(List<KLineEntity> dataList, List<EMAConfig> emaConfigs, [bool isLast = false]) {
    // 为每个周期初始化EMA值存储
    Map<int, double> emaValues = {};
    
    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      // 从上一个数据点恢复EMA值
      var prevEntity = dataList[dataList.length - 2];
      // 确保prevEntity的emaValues已初始化
      try {
        prevEntity.emaValues;
      } catch (e) {
        prevEntity.emaValues = <int, double>{};
      }
      if (prevEntity.emaValues.isNotEmpty) {
        for (var config in emaConfigs) {
          emaValues[config.period] = prevEntity.emaValues[config.period] ?? 0;
        }
      }
    }
    
    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      
      // 初始化emaValues Map（如果还没有初始化）
      try {
        entity.emaValues;
      } catch (e) {
        entity.emaValues = <int, double>{};
      }
      
      final closePrice = entity.close;
      
      for (var config in emaConfigs) {
        int period = config.period;
        
        if (i == 0) {
          // 第一个EMA值等于第一个收盘价
          emaValues[period] = closePrice;
        } else {
          // EMA(period) = 当前收盘价 * 2/(period+1) + 前一日EMA * (period-1)/(period+1)
          double multiplier = 2.0 / (period + 1);
          double prevEMA = emaValues[period] ?? closePrice;
          emaValues[period] = closePrice * multiplier + prevEMA * (1 - multiplier);
        }
        
        // 存储到实体中
        entity.emaValues[period] = emaValues[period]!;
      }
    }
  }

  static void _calcMACD(List<KLineEntity> dataList, [bool isLast = false]) {
    double ema12 = 0;
    double ema26 = 0;
    double dif = 0;
    double dea = 0;
    double macd = 0;

    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      var data = dataList[dataList.length - 2];
      dif = data.dif;
      dea = data.dea;
      macd = data.macd;
      ema12 = data.ema12;
      ema26 = data.ema26;
    }

    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      final closePrice = entity.close;
      if (i == 0) {
        ema12 = closePrice;
        ema26 = closePrice;
      } else {
        // EMA（12） = 前一日EMA（12） X 11/13 + 今日收盘价 X 2/13
        ema12 = ema12 * 11 / 13 + closePrice * 2 / 13;
        // EMA（26） = 前一日EMA（26） X 25/27 + 今日收盘价 X 2/27
        ema26 = ema26 * 25 / 27 + closePrice * 2 / 27;
      }
      // DIF = EMA（12） - EMA（26） 。
      // 今日DEA = （前一日DEA X 8/10 + 今日DIF X 2/10）
      // 用（DIF-DEA）*2即为MACD柱状图。
      dif = ema12 - ema26;
      dea = dea * 8 / 10 + dif * 2 / 10;
      macd = (dif - dea) * 2;
      entity.dif = dif;
      entity.dea = dea;
      entity.macd = macd;
      entity.ema12 = ema12;
      entity.ema26 = ema26;
    }
  }

  static void _calcVolumeMA(List<KLineEntity> dataList, [bool isLast = false]) {
    double volumeMa5 = 0;
    double volumeMa10 = 0;

    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      var data = dataList[dataList.length - 2];
      volumeMa5 = data.MA5Volume * 5;
      volumeMa10 = data.MA10Volume * 10;
    }

    for (; i < dataList.length; i++) {
      KLineEntity entry = dataList[i];

      volumeMa5 += entry.vol;
      volumeMa10 += entry.vol;

      if (i == 4) {
        entry.MA5Volume = (volumeMa5 / 5);
      } else if (i > 4) {
        volumeMa5 -= dataList[i - 5].vol;
        entry.MA5Volume = volumeMa5 / 5;
      } else {
        entry.MA5Volume = 0;
      }

      if (i == 9) {
        entry.MA10Volume = volumeMa10 / 10;
      } else if (i > 9) {
        volumeMa10 -= dataList[i - 10].vol;
        entry.MA10Volume = volumeMa10 / 10;
      } else {
        entry.MA10Volume = 0;
      }
    }
  }

  static void _calcRSI(List<KLineEntity> dataList, [bool isLast = false]) {
    double rsi;
    double rsiABSEma = 0;
    double rsiMaxEma = 0;

    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      var data = dataList[dataList.length - 2];
      rsi = data.rsi;
      rsiABSEma = data.rsiABSEma;
      rsiMaxEma = data.rsiMaxEma;
    }

    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      final double closePrice = entity.close;
      if (i == 0) {
        rsi = 0;
        rsiABSEma = 0;
        rsiMaxEma = 0;
      } else {
        double Rmax = max(0, closePrice - dataList[i - 1].close);
        double RAbs = (closePrice - dataList[i - 1].close).abs();

        rsiMaxEma = (Rmax + (14 - 1) * rsiMaxEma) / 14;
        rsiABSEma = (RAbs + (14 - 1) * rsiABSEma) / 14;
        rsi = (rsiMaxEma / rsiABSEma) * 100;
      }
      if (i < 13) rsi = 0;
      if (rsi.isNaN) rsi = 0;
      entity.rsi = rsi;
      entity.rsiABSEma = rsiABSEma;
      entity.rsiMaxEma = rsiMaxEma;
    }
  }

  static void _calcKDJ(List<KLineEntity> dataList, [bool isLast = false]) {
    double k = 0;
    double d = 0;

    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      var data = dataList[dataList.length - 2];
      k = data.k;
      d = data.d;
    }

    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      final double closePrice = entity.close;
      int startIndex = i - 13;
      if (startIndex < 0) {
        startIndex = 0;
      }
      double max14 = -double.maxFinite;
      double min14 = double.maxFinite;
      for (int index = startIndex; index <= i; index++) {
        max14 = max(max14, dataList[index].high);
        min14 = min(min14, dataList[index].low);
      }
      double rsv = 100 * (closePrice - min14) / (max14 - min14);
      if (rsv.isNaN) {
        rsv = 0;
      }
      if (i == 0) {
        k = 50;
        d = 50;
      } else {
        k = (rsv + 2 * k) / 3;
        d = (k + 2 * d) / 3;
      }
      if (i < 13) {
        entity.k = 0;
        entity.d = 0;
        entity.j = 0;
      } else if (i == 13 || i == 14) {
        entity.k = k;
        entity.d = 0;
        entity.j = 0;
      } else {
        entity.k = k;
        entity.d = d;
        entity.j = 3 * k - 2 * d;
      }
    }
  }

  //WR(N) = 100 * [ HIGH(N)-C ] / [ HIGH(N)-LOW(N) ]
  static void _calcWR(List<KLineEntity> dataList, [bool isLast = false]) {
    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
    }
    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      int startIndex = i - 14;
      if (startIndex < 0) {
        startIndex = 0;
      }
      double max14 = -double.maxFinite;
      double min14 = double.maxFinite;
      for (int index = startIndex; index <= i; index++) {
        max14 = max(max14, dataList[index].high);
        min14 = min(min14, dataList[index].low);
      }
      if (i < 13) {
        entity.r = 0;
      } else {
        if ((max14 - min14) == 0) {
          entity.r = 0;
        } else {
          entity.r = 100 * (max14 - dataList[i].close) / (max14 - min14);
        }
      }
    }
  }

  // SAR (Parabolic SAR) 抛物线转向指标计算
  // 根据OKX算法实现：
  // 上升式：SAR(n) = SAR(n-1) + AF × [H(n-1) - SAR(n-1)]
  // 下降式：SAR(n) = SAR(n-1) + AF × [L(n-1) - SAR(n-1)]
  // 其中：
  // - H(n-1)：前一个周期的最高价
  // - L(n-1)：前一个周期的最低价
  // - AF：加速因子，基值为0.02，当价格每创新高(上升式)或新低(下降式)时，按倍数增加到0.2为止
  // - 初始值：上升式以近期最低价为准，下降式以近期最高价为准
  static void _calcSAR(List<KLineEntity> dataList, ChartStyle chartStyle, [bool isLast = false]) {
    if (dataList.length < 2) {
      // 如果数据不足，将所有SAR值设为0
      for (var entity in dataList) {
        entity.sar = 0;
        entity.sarTrend = true;
        entity.sarAF = chartStyle.sarAFStart;
        entity.sarEP = 0;
      }
      return;
    }
    
    double sarAFStart = chartStyle.sarAFStart;
    double sarAFIncrement = chartStyle.sarAFIncrement;
    double sarAFMax = chartStyle.sarAFMax;
    
    int i = 0;
    double sar = 0;
    bool trend = true; // true=上升趋势, false=下降趋势
    double af = sarAFStart;
    double ep = 0; // EP用于跟踪极值点，用于AF更新
    
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      var prevEntity = dataList[dataList.length - 2];
      // 确保前一个实体有有效的SAR值
      if (prevEntity.sar != 0) {
        sar = prevEntity.sar;
        trend = prevEntity.sarTrend;
        af = prevEntity.sarAF;
        ep = prevEntity.sarEP;
      } else {
        // 如果前一个SAR无效，重新初始化
        i = 0;
      }
    }
    
    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      
      if (i == 0) {
        // 第一个数据点：初始化SAR
        // 根据第二个数据点的收盘价与第一个数据点的收盘价比较来确定趋势
        if (dataList.length > 1) {
          trend = dataList[1].close > entity.close;
        } else {
          trend = true; // 默认上升趋势
        }
        
        if (trend) {
          // 上升趋势：初始值以近期最低价为准
          sar = entity.low;
          ep = entity.high; // EP用于跟踪最高价
        } else {
          // 下降趋势：初始值以近期最高价为准
          sar = entity.high;
          ep = entity.low; // EP用于跟踪最低价
        }
        af = sarAFStart;
      } else {
        // 第二个及以后的数据点：使用SAR算法
        KLineEntity prevEntity = dataList[i - 1];
        double prevSAR = prevEntity.sar;
        bool prevTrend = prevEntity.sarTrend;
        double prevAF = prevEntity.sarAF;
        double prevEP = prevEntity.sarEP;
        
        // 根据趋势方向计算SAR值
        if (prevTrend) {
          // 上升式：SAR(n) = SAR(n-1) + AF × [H(n-1) - SAR(n-1)]
          // H(n-1)是前一个周期的最高价
          sar = prevSAR + prevAF * (prevEntity.high - prevSAR);
          
          // 如果SAR >= 当前最低价，则反转趋势
          if (sar >= entity.low) {
            trend = false;
            // 反转时：SAR = 前一个EP（最高价），EP = 当前最低价
            sar = prevEP;
            ep = entity.low;
            af = sarAFStart; // 重置AF
          } else {
            trend = true;
            // SAR限制：上升趋势中，SAR不能高于前两个周期的最低价
            // 这确保SAR保持在K线下方，形成向上的抛物线
            if (i >= 2) {
              double minLow = min(dataList[i - 1].low, dataList[i - 2].low);
              if (sar > minLow) {
                sar = minLow;
              }
            } else if (i >= 1) {
              if (sar > dataList[i - 1].low) {
                sar = dataList[i - 1].low;
              }
            }
            
            // 更新EP（最高价）和AF
            if (entity.high > prevEP) {
              ep = entity.high;
              // EP创新高，AF增加（按倍数增加）
              af = min(prevAF + sarAFIncrement, sarAFMax);
            } else {
              ep = prevEP;
              af = prevAF;
            }
          }
        } else {
          // 下降式：SAR(n) = SAR(n-1) + AF × [L(n-1) - SAR(n-1)]
          // L(n-1)是前一个周期的最低价
          sar = prevSAR + prevAF * (prevEntity.low - prevSAR);
          
          // 如果SAR <= 当前最高价，则反转趋势
          if (sar <= entity.high) {
            trend = true;
            // 反转时：SAR = 前一个EP（最低价），EP = 当前最高价
            sar = prevEP;
            ep = entity.high;
            af = sarAFStart; // 重置AF
          } else {
            trend = false;
            // SAR限制：下降趋势中，SAR不能低于前两个周期的最高价
            // 这确保SAR保持在K线上方，形成向下的抛物线
            if (i >= 2) {
              double maxHigh = max(dataList[i - 1].high, dataList[i - 2].high);
              if (sar < maxHigh) {
                sar = maxHigh;
              }
            } else if (i >= 1) {
              if (sar < dataList[i - 1].high) {
                sar = dataList[i - 1].high;
              }
            }
            
            // 更新EP（最低价）和AF
            if (entity.low < prevEP) {
              ep = entity.low;
              // EP创新低，AF增加（按倍数增加）
              af = min(prevAF + sarAFIncrement, sarAFMax);
            } else {
              ep = prevEP;
              af = prevAF;
            }
          }
        }
      }
      
      // 确保SAR值有效（不为NaN或无穷大）
      if (sar.isNaN || sar.isInfinite) {
        sar = 0;
      }
      
      // 存储SAR值
      entity.sar = sar;
      entity.sarTrend = trend;
      entity.sarAF = af;
      entity.sarEP = ep;
    }
  }

  // OBV 能量潮指标
  // 标准计算方法：
  // 1. 初始值：第一个交易日的OBV值设为0
  // 2. 如果当日收盘价 > 前一日收盘价，则当日OBV = 前一日OBV + 当日成交量
  // 3. 如果当日收盘价 < 前一日收盘价，则当日OBV = 前一日OBV - 当日成交量
  // 4. 如果当日收盘价 = 前一日收盘价，则当日OBV = 前一日OBV（保持不变）
  static void _calcOBV(List<KLineEntity> dataList, [bool isLast = false]) {
    double obv = 0;
    
    int i = 0;
    if (isLast && dataList.length > 1) {
      i = dataList.length - 1;
      obv = dataList[dataList.length - 2].obv;
    }
    
    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      
      if (i == 0) {
        // 第一个OBV值设为0（标准做法）
        obv = 0;
      } else {
        double prevClose = dataList[i - 1].close;
        double currentClose = entity.close;
        
        if (currentClose > prevClose) {
          // 上涨：OBV = 前一日OBV + 今日成交量
          obv = obv + entity.vol;
        } else if (currentClose < prevClose) {
          // 下跌：OBV = 前一日OBV - 今日成交量
          obv = obv - entity.vol;
        } else {
          // 持平：OBV = 前一日OBV（保持不变）
          // obv保持不变
        }
      }
      
      entity.obv = obv;
    }
  }

  // OBV 移动平均线计算
  static void _calcOBVMA(List<KLineEntity> dataList, int period, [bool isLast = false]) {
    double maOBVSum = 0;
    
    int i = 0;
    if (isLast && dataList.length > period) {
      i = dataList.length - 1;
      // 从倒数第 period 个开始重新计算
      maOBVSum = 0;
      for (int j = dataList.length - period - 1; j < dataList.length - 1; j++) {
        maOBVSum += dataList[j].obv;
      }
    }
    
    for (; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      
      if (i < period - 1) {
        // 数据不足，无法计算移动平均
        entity.maOBV = 0;
      } else {
        // 计算 period 周期的移动平均
        if (i == period - 1 || (isLast && i == dataList.length - 1)) {
          // 重新计算总和
          maOBVSum = 0;
          for (int j = i - period + 1; j <= i; j++) {
            maOBVSum += dataList[j].obv;
          }
        } else {
          // 增量更新：减去最旧的值，加上最新的值
          maOBVSum = maOBVSum - dataList[i - period].obv + entity.obv;
        }
        entity.maOBV = maOBVSum / period;
      }
    }
  }

  //增量更新时计算最后一个数据
  static void addLastData(List<KLineEntity> dataList, KLineEntity data, {int obvPeriod = 30, List<EMAConfig>? emaConfigs, ChartStyle? chartStyle}) {
    if (dataList.isEmpty) return;
    dataList.add(data);
    _calcMA(dataList, true);
    _calcBOLL(dataList, true);
    _calcVolumeMA(dataList, true);
    _calcKDJ(dataList, true);
    _calcMACD(dataList, true);
    _calcRSI(dataList, true);
    _calcWR(dataList, true);
    _calcOBV(dataList, true);
    _calcOBVMA(dataList, obvPeriod, true);
    if (emaConfigs != null && emaConfigs.isNotEmpty) {
      _calcEMA(dataList, emaConfigs, true);
    }
    if (chartStyle != null) {
      _calcSAR(dataList, chartStyle, true);
    }
  }

  //更新最后一条数据
  static void updateLastData(List<KLineEntity> dataList, {int obvPeriod = 30, List<EMAConfig>? emaConfigs, ChartStyle? chartStyle}) {
    if (dataList.isEmpty) return;
    _calcMA(dataList, true);
    _calcBOLL(dataList, true);
    _calcVolumeMA(dataList, true);
    _calcKDJ(dataList, true);
    _calcMACD(dataList, true);
    _calcRSI(dataList, true);
    _calcWR(dataList, true);
    _calcOBV(dataList, true);
    _calcOBVMA(dataList, obvPeriod, true);
    if (emaConfigs != null && emaConfigs.isNotEmpty) {
      _calcEMA(dataList, emaConfigs, true);
    }
    if (chartStyle != null) {
      _calcSAR(dataList, chartStyle, true);
    }
  }
}
