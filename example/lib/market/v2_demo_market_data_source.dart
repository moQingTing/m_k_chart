import 'package:m_k_chart/v2_example_support.dart';

/// 示例宿主的行情输入契约，不属于图表 SDK 的公开 API。
///
/// 图表只消费 [Kline]；REST、缓存或 WebSocket 聚合源由宿主实现。调用方应保持
/// 源实例稳定，并保证返回的 K 线属于请求的交易对和周期。
abstract interface class V2DemoMarketDataSource {
  /// 用于示例页的来源标记和错误提示。
  String get displayName;

  /// [limit] 是期望的窗口根数；首次加载请求完整窗口，轮询只请求最近两根。
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  });

  /// 可不提供 24 小时摘要；返回 null 时示例从当前 K 线窗口估算。
  Future<V2MarketTicker?> ticker({required String symbol});
}

/// 可选的单请求取消能力。旧的 Future 行情源无需实现此接口。
abstract interface class V2DemoCancelableMarketDataSource
    implements V2DemoMarketDataSource {
  V2DemoMarketRequest<List<Kline>> requestCandles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  });

  V2DemoMarketRequest<V2MarketTicker?> requestTicker({required String symbol});
}

/// 一次请求及其取消动作；取消必须幂等，取消后结果仍由宿主代际守卫判定。
final class V2DemoMarketRequest<T> {
  const V2DemoMarketRequest({required this.result, required this.cancel});

  final Future<T> result;
  final void Function() cancel;
}

/// 示例摘要需要的交易所无关 24 小时数据形状。
class V2MarketTicker {
  const V2MarketTicker({
    required this.symbol,
    required this.last,
    required this.open24h,
    required this.high24h,
    required this.low24h,
    required this.baseVolume24h,
    required this.quoteVolume24h,
  });

  final String symbol;
  final double last;
  final double open24h;
  final double high24h;
  final double low24h;
  final double baseVolume24h;
  final double quoteVolume24h;

  double get change24h => last - open24h;

  double get changePercent24h => open24h == 0 ? 0 : change24h / open24h * 100;
}
