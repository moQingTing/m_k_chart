import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/drawing.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  test('preserves absolute anchors or clamps them to the new timeline', () {
    final drawing =
        ChartDrawing(id: 'line', kind: ChartDrawingKind.trendLine, anchors: [
      ChartDrawingAnchor(epochMilliseconds: 10, price: 1),
      ChartDrawingAnchor(epochMilliseconds: 40, price: 2),
    ]);
    final data = [_kline(20), _kline(30)];
    expect(ChartDrawingTimelineRestorer.restore(drawing: drawing, data: data),
        same(drawing));
    final clamped = ChartDrawingTimelineRestorer.restore(
      drawing: drawing,
      data: data,
      policy: ChartDrawingOutOfRangePolicy.clampToTimeline,
    );
    expect(clamped.anchors.map((item) => item.epochMilliseconds), [20, 30]);
  });
}

Kline _kline(int time) => Kline(
    symbol: 'BTCUSDT',
    interval: KlineInterval.oneMinute,
    openTime: time,
    closeTime: time + 1,
    open: 1,
    high: 1,
    low: 1,
    close: 1,
    baseVolume: 1,
    quoteVolume: 1,
    tradeCount: 1,
    isClosed: true);
