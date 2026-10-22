import 'kline.dart';
import 'kline_interval.dart';

/// 一条行情序列的身份，即使数据窗口为空也能确定目标交易对和周期。
///
/// symbol 由宿主定义，不擅自转换大小写或按交易所规则改写。显示时区不属于序列身份；
/// 数据源如果有不同的开盘边界，应由宿主使用不同的序列/周期描述。
final class KlineSeries {
  factory KlineSeries({
    required String symbol,
    required KlineInterval interval,
    KlinePriceSource priceSource = KlinePriceSource.trade,
  }) {
    if (symbol.trim().isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', 'Must not be empty.');
    }
    return KlineSeries._(symbol, interval, priceSource);
  }

  const KlineSeries._(this.symbol, this.interval, this.priceSource);

  factory KlineSeries.fromKline(Kline candle) => KlineSeries(
        symbol: candle.symbol,
        interval: candle.interval,
        priceSource: candle.priceSource,
      );

  final String symbol;
  final KlineInterval interval;
  final KlinePriceSource priceSource;

  bool contains(Kline candle) =>
      candle.symbol == symbol &&
      candle.interval == interval &&
      candle.priceSource == priceSource;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KlineSeries &&
          symbol == other.symbol &&
          interval == other.interval &&
          priceSource == other.priceSource;

  @override
  int get hashCode => Object.hash(symbol, interval, priceSource);
}
