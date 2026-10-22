import 'dart:math' as math;

import 'package:m_k_chart/v2_example_support.dart';

/// 旧 Demo 使用的最小不可变数据适配器；它不是 SDK 的正式数据接口。
///
/// 将输入复制为不可修改列表，避免外部行情缓冲区后续原地更新污染已发布版本。
final class V2DemoKlineData implements VersionedKlineData {
  V2DemoKlineData.fromCandles(
    Iterable<Kline> candles, {
    required int revision,
  })  : data = List<Kline>.unmodifiable(candles),
        version = KlineDataVersion(revision);

  @override
  final List<Kline> data;

  @override
  final KlineDataVersion version;
}

/// 生成确定性的离线首帧数据，而非模仿实时行情。
///
/// 同一周期始终生成相同的 180 根 K 线；[revision] 只标识快照版本。
/// 正式接入时可改用宿主缓存或空状态，不应把这个生成器当作行情源。
V2DemoKlineData createV2DemoSeedData(
  KlineInterval interval, {
  required int revision,
}) {
  final duration = interval.duration;
  if (duration == null) {
    throw ArgumentError.value(
      interval,
      'interval',
      '离线示例仅支持固定时长周期。',
    );
  }
  final step = duration.inMilliseconds;
  final seed =
      interval.code.codeUnits.fold<int>(0, (sum, value) => sum + value);
  final values = List<Kline>.generate(180, (index) {
    final trend = index * (0.36 + seed % 5 * .02);
    final wave = ((index + seed) % 19 - 9) * .48;
    final open = 1000 + trend + wave;
    final close = open + ((index + seed) % 7 - 3) * .32;
    final openTime = 1704067200000 + index * step;
    return Kline(
      symbol: 'BTCUSDT',
      interval: interval,
      openTime: openTime,
      closeTime: openTime + step - 1,
      open: open,
      high: math.max(open, close) + 1.25 + index % 4 * .1,
      low: math.min(open, close) - 1.15 - index % 3 * .1,
      close: close,
      baseVolume: 800 + index % 17 * 53,
      quoteVolume: 1000,
      tradeCount: 20 + index % 30,
      isClosed: index != 179,
    );
  });
  return V2DemoKlineData.fromCandles(values, revision: revision);
}
