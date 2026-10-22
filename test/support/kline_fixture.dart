import 'dart:math' as math;

import 'package:m_k_chart/m_k_chart.dart';

/// Builds deterministic, chronologically ordered K-line data for tests and
/// benchmarks. The generated values intentionally include both rising and
/// falling candles, trend changes, and varying volume.
List<KLineEntity> buildKlineFixture(
  int count, {
  int startTime = 1704067200,
  int intervalSeconds = 60,
}) {
  assert(count >= 0);

  return List<KLineEntity>.generate(count, (index) {
    final trend = index * 0.37;
    final cycle = ((index % 23) - 11) * 0.41;
    final open = 1000.0 + trend + cycle;
    final closeOffset = ((index % 7) - 3) * 0.29;
    final close = open + closeOffset;
    final high = math.max(open, close) + 1.2 + (index % 5) * 0.13;
    final low = math.min(open, close) - 1.1 - (index % 3) * 0.17;
    final volume = 800.0 + (index % 17) * 53.0 + index * 1.7;

    return KLineEntity()
      ..id = startTime + index * intervalSeconds
      ..open = open
      ..high = high
      ..low = low
      ..close = close
      ..vol = volume
      ..amount = volume * (open + close) / 2
      ..count = 20 + index % 31;
  });
}
