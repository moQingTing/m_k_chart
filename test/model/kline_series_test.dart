import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candle = buildV2KlineFixture(1).single;

  test('series identity matches Kline and supports empty-window construction',
      () {
    final fromCandle = KlineSeries.fromKline(candle);
    final explicit =
        KlineSeries(symbol: 'BTCUSDT', interval: KlineInterval.oneMinute);
    expect(fromCandle, explicit);
    expect(fromCandle.hashCode, explicit.hashCode);
    expect(explicit.contains(candle), isTrue);
    expect(explicit.contains(candle.copyWith(close: candle.high)), isTrue);
  });

  test('symbol, full interval and price source all participate in identity',
      () {
    final series = KlineSeries.fromKline(candle);
    for (final other in [
      KlineSeries(symbol: 'ETHUSDT', interval: candle.interval),
      KlineSeries(symbol: candle.symbol, interval: KlineInterval.oneDay),
      KlineSeries(
        symbol: candle.symbol,
        interval: candle.interval,
        priceSource: KlinePriceSource.mark,
      ),
      // 自定义周期即使显示 code 相同，实际时长不同也不是同一序列。
      KlineSeries(
        symbol: candle.symbol,
        interval: KlineInterval.fixed(
          code: candle.interval.code,
          duration: const Duration(minutes: 2),
        ),
      ),
    ]) {
      expect(other, isNot(series));
      expect(other.contains(candle), isFalse);
    }
  });

  test('series preserves host symbol spelling and rejects blank ids', () {
    final series = KlineSeries(symbol: 'btc/usdt', interval: candle.interval);
    expect(series.symbol, 'btc/usdt');
    expect(
      () => KlineSeries(symbol: '  ', interval: candle.interval),
      throwsArgumentError,
    );
  });
}
