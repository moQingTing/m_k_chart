import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/drawing.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  test('moves selected drawings and individual anchors immutably', () {
    final editor = ChartDrawingEditor(drawings: [_drawing()]).select('trend');
    final moved = editor.moveDrawing(
      id: 'trend',
      timeDeltaMilliseconds: 1000,
      priceDelta: 2,
    );
    final anchored = moved.moveAnchor(
      id: 'trend',
      anchorIndex: 1,
      anchor: ChartDrawingAnchor(epochMilliseconds: 9000, price: 99),
    );
    expect(editor.drawingById['trend']!.anchors.first.price, 10);
    expect(moved.drawingById['trend']!.anchors.first.price, 12);
    expect(anchored.drawingById['trend']!.anchors[1].price, 99);
  });

  test('locks mutations and clears selection when deleting', () {
    final locked = ChartDrawingEditor(drawings: [_drawing()])
        .select('trend')
        .setLocked('trend', true);
    expect(
      () => locked.moveDrawing(
        id: 'trend',
        timeDeltaMilliseconds: 1,
        priceDelta: 0,
      ),
      throwsStateError,
    );
    final removed = locked.setLocked('trend', false).remove('trend');
    expect(removed.drawings, isEmpty);
    expect(removed.selectedDrawingId, isNull);
  });

  test('persists optional locked state without changing schema version', () {
    final restored = ChartDrawing.fromJson(_drawing(isLocked: true).toJson());
    expect(restored.isLocked, isTrue);
    expect(restored.toJson()['schemaVersion'], ChartDrawing.schemaVersion);
  });

  test('snaps an anchor to nearest candle time and OHLC price', () {
    final result = ChartDrawingOhlcSnapper.snap(
      anchor: ChartDrawingAnchor(epochMilliseconds: 1600, price: 18),
      data: [_kline(1000, 10, 20, 5, 15), _kline(2000, 30, 40, 25, 35)],
    );
    expect(result.dataIndex, 1);
    expect(result.field, ChartDrawingOhlcField.low);
    expect(
      result.anchor,
      ChartDrawingAnchor(epochMilliseconds: 2000, price: 25),
    );
  });
}

Kline _kline(int time, double open, double high, double low, double close) =>
    Kline(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      openTime: time,
      closeTime: time + 999,
      open: open,
      high: high,
      low: low,
      close: close,
      baseVolume: 1,
      quoteVolume: 1,
      tradeCount: 1,
      isClosed: true,
    );

ChartDrawing _drawing({bool isLocked = false}) => ChartDrawing(
      id: 'trend',
      kind: ChartDrawingKind.trendLine,
      anchors: [
        ChartDrawingAnchor(epochMilliseconds: 1000, price: 10),
        ChartDrawingAnchor(epochMilliseconds: 2000, price: 20),
      ],
      isLocked: isLocked,
    );
