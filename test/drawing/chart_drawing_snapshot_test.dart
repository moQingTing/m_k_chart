import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/drawing.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  final series = KlineSeries(
    symbol: 'BTCUSDT',
    interval: KlineInterval.oneMinute,
  );
  final drawing = ChartDrawing(
    id: 'trend-1',
    kind: ChartDrawingKind.trendLine,
    anchors: [
      ChartDrawingAnchor(epochMilliseconds: 500, price: 10),
      ChartDrawingAnchor(epochMilliseconds: 2500, price: 20),
    ],
    isLocked: true,
  );

  test('versioned snapshot JSON round-trips provider, series, and drawings',
      () {
    final snapshot = ChartDrawingSnapshot(
      series: series,
      sourceId: 'binance-spot',
      drawings: [drawing],
    );
    final decoded = jsonDecode(jsonEncode(snapshot.toJson())) as Map;
    final restored = ChartDrawingSnapshot.fromJson(
      Map<String, Object?>.from(decoded),
    );

    expect(restored.symbol, 'BTCUSDT');
    expect(restored.intervalCode, '1m');
    expect(restored.priceSource, 'trade');
    expect(restored.sourceId, 'binance-spot');
    expect(restored.drawings, [drawing]);
  });

  test('restore permits timeframe changes and optionally clamps old anchors',
      () {
    final snapshot = ChartDrawingSnapshot(
      series: series,
      sourceId: 'binance-spot',
      drawings: [drawing],
    );
    final target = KlineSeries(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneHour,
    );
    final data = [
      _candle(1000, interval: KlineInterval.oneHour),
      _candle(2000, interval: KlineInterval.oneHour),
    ];

    final preserved = snapshot.restoreFor(
      series: target,
      sourceId: 'binance-spot',
      data: data,
    );
    expect(preserved.intervalCode, '1h');
    expect(preserved.drawings.single.anchors.first.epochMilliseconds, 500);
    expect(preserved.drawings.single.anchors.last.epochMilliseconds, 2500);

    final clamped = snapshot.restoreFor(
      series: target,
      sourceId: 'binance-spot',
      data: data,
      outOfRangePolicy: ChartDrawingOutOfRangePolicy.clampToTimeline,
    );
    expect(clamped.drawings.single.anchors.first.epochMilliseconds, 1000);
    expect(clamped.drawings.single.anchors.last.epochMilliseconds, 2000);
  });

  test('restore rejects another provider or symbol', () {
    final snapshot = ChartDrawingSnapshot(
      series: series,
      sourceId: 'binance-spot',
      drawings: [drawing],
    );
    expect(
      () => snapshot.restoreFor(
        series: series,
        sourceId: 'other-exchange',
        data: const [],
      ),
      throwsStateError,
    );
    expect(
      () => snapshot.restoreFor(
        series: KlineSeries(symbol: 'ETHUSDT', interval: series.interval),
        sourceId: 'binance-spot',
        data: const [],
      ),
      throwsStateError,
    );
  });

  test('restore rejects target candles from another series or unordered data',
      () {
    final snapshot = ChartDrawingSnapshot(
      series: series,
      sourceId: 'binance-spot',
      drawings: [drawing],
    );
    expect(
      () => snapshot.restoreFor(
        series: series,
        sourceId: 'binance-spot',
        data: [_candle(1000, symbol: 'ETHUSDT')],
      ),
      throwsArgumentError,
    );
    expect(
      () => snapshot.restoreFor(
        series: series,
        sourceId: 'binance-spot',
        data: [_candle(2000), _candle(1000)],
      ),
      throwsArgumentError,
    );
  });

  test('rejects unsupported schema and duplicate drawing IDs', () {
    final snapshot = ChartDrawingSnapshot(
      series: series,
      sourceId: 'binance-spot',
      drawings: [drawing],
    );
    expect(
      () => ChartDrawingSnapshot.fromJson({
        ...snapshot.toJson(),
        'schemaVersion': ChartDrawingSnapshot.schemaVersion + 1,
      }),
      throwsUnsupportedError,
    );
    expect(
      () => ChartDrawingSnapshot(
        series: series,
        sourceId: 'binance-spot',
        drawings: [drawing, drawing],
      ),
      throwsArgumentError,
    );
  });
}

Kline _candle(
  int time, {
  String symbol = 'BTCUSDT',
  KlineInterval? interval,
}) =>
    Kline(
      symbol: symbol,
      interval: interval ?? KlineInterval.oneMinute,
      openTime: time,
      closeTime: time + 59999,
      open: 10,
      high: 12,
      low: 8,
      close: 11,
      baseVolume: 1,
      quoteVolume: 11,
      tradeCount: 1,
      isClosed: true,
    );
