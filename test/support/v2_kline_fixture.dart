import 'dart:math' as math;

import 'package:m_k_chart/src/model/model.dart';

List<Kline> buildV2KlineFixture(
  int count, {
  int startIndex = 0,
  String symbol = 'BTCUSDT',
}) =>
    List<Kline>.generate(
      count,
      (offset) {
        final index = startIndex + offset;
        final trend = index * 0.37;
        final cycle = ((index % 23) - 11) * 0.41;
        final open = 1000.0 + trend + cycle;
        final close = open + ((index % 7) - 3) * 0.29;
        final high = math.max(open, close) + 1.2 + (index % 5) * 0.13;
        final low = math.min(open, close) - 1.1 - (index % 3) * 0.17;
        final volume = 800.0 + (index % 17) * 53.0 + index * 1.7;
        final openTime =
            1704067200000 + index * 60 * Duration.millisecondsPerSecond;
        return Kline(
          symbol: symbol,
          interval: KlineInterval.oneMinute,
          openTime: openTime,
          closeTime: openTime + 60 * Duration.millisecondsPerSecond - 1,
          open: open,
          high: high,
          low: low,
          close: close,
          baseVolume: volume,
          quoteVolume: volume * (open + close) / 2,
          tradeCount: 20 + index % 31,
          isClosed: index != startIndex + count - 1,
        );
      },
      growable: false,
    );
