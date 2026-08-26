import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/render/render.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  test('Heikin-Ashi projection follows the recursive OHLC formula', () {
    final source = buildV2KlineFixture(2);
    final projection = ChartCandleProjection.fromKlines(
      source: source,
      mode: ChartMainMode.heikinAshi,
    );

    final first = projection.candles.first;
    final firstClose =
        (source[0].open + source[0].high + source[0].low + source[0].close) / 4;
    expect(first.open, closeTo((source[0].open + source[0].close) / 2, 1e-12));
    expect(first.close, closeTo(firstClose, 1e-12));
    expect(first.high, greaterThanOrEqualTo(source[0].high));
    expect(first.low, lessThanOrEqualTo(source[0].low));

    final second = projection.candles[1];
    expect(second.open, closeTo((first.open + first.close) / 2, 1e-12));
    expect(
      second.close,
      closeTo(
        (source[1].open + source[1].high + source[1].low + source[1].close) / 4,
        1e-12,
      ),
    );
    expect(() => projection.candles.clear(), throwsUnsupportedError);
  });

  test('raw candle modes preserve source OHLC values', () {
    final source = buildV2KlineFixture(1);
    for (final mode in [
      ChartMainMode.candlestick,
      ChartMainMode.hollowCandlestick,
      ChartMainMode.ohlc,
    ]) {
      final candle = ChartCandleProjection.fromKlines(
        source: source,
        mode: mode,
      ).candles.single;
      expect(candle.open, source.single.open);
      expect(candle.high, source.single.high);
      expect(candle.low, source.single.low);
      expect(candle.close, source.single.close);
      expect(mode.isCandleMode, isTrue);
      expect(mode.showsMainIndicators, isTrue);
    }
    expect(ChartMainMode.line.isCandleMode, isFalse);
    expect(ChartMainMode.area.showsMainIndicators, isFalse);
  });
}
