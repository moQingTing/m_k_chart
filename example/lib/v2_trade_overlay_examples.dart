import 'dart:collection';
import 'dart:math' as math;

import 'package:m_k_chart/v2_example_support.dart';

/// SDK-free business examples composed from the generic P8 overlay primitives.
final class DemoTradeOverlaySet {
  DemoTradeOverlaySet({required Iterable<ChartPriceLine> priceLines})
      : priceLines = UnmodifiableListView(List.of(priceLines));

  final List<ChartPriceLine> priceLines;
}

DemoTradeOverlaySet buildDemoTradeOverlays(List<Kline> candles) {
  if (candles.isEmpty) {
    return DemoTradeOverlaySet(priceLines: const []);
  }
  var lowest = candles.first.low;
  var highest = candles.first.high;
  for (final candle in candles.skip(1)) {
    lowest = math.min(lowest, candle.low);
    highest = math.max(highest, candle.high);
  }
  final latest = candles.last.close;
  final fallbackSpan = math.max(latest.abs() * 0.02, 1.0);
  final span = highest > lowest ? highest - lowest : fallbackSpan;
  double priceAt(double offset) =>
      (latest + span * offset).clamp(lowest, highest).toDouble();

  return DemoTradeOverlaySet(
    priceLines: [
      ChartPriceLine(
        id: 'demo-position-long-average',
        price: priceAt(-0.04),
        side: ChartOverlaySide.buy,
        label: '多仓均价',
        style: ChartPriceLineStyle.dashed,
      ),
      ChartPriceLine(
        id: 'demo-position-long-liquidation',
        price: priceAt(-0.30),
        side: ChartOverlaySide.sell,
        label: '强平价',
        style: ChartPriceLineStyle.dashed,
      ),
      ChartPriceLine(
        id: 'demo-order-buy-limit',
        price: priceAt(-0.12),
        side: ChartOverlaySide.buy,
        label: '买入挂单',
        style: ChartPriceLineStyle.dashed,
      ),
      ChartPriceLine(
        id: 'demo-order-long-take-profit',
        price: priceAt(0.22),
        side: ChartOverlaySide.sell,
        label: '止盈',
        style: ChartPriceLineStyle.dashed,
      ),
      ChartPriceLine(
        id: 'demo-order-long-stop-loss',
        price: priceAt(-0.20),
        side: ChartOverlaySide.sell,
        label: '止损',
        style: ChartPriceLineStyle.dashed,
      ),
    ],
  );
}
