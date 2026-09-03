import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/v2_example_support.dart';
import 'package:m_k_chart_example/binance_market_data_client.dart';

void main() {
  test('maps and chronologically sorts the official Binance candle schema',
      () async {
    final client = BinanceMarketDataClient(
      nowMilliseconds: () => 180000,
      get: (uri) async {
        expect(uri.host, 'data-api.binance.vision');
        expect(uri.path, '/api/v3/klines');
        expect(uri.queryParameters, {
          'symbol': 'BTCUSDT',
          'interval': '1h',
          'limit': '2',
        });
        return BinanceHttpResponse(
          statusCode: 200,
          body: jsonEncode([
            [120000, '11', '14', '10', '13', '4', 179999, '52', 9, '2', '26'],
            [60000, '10', '12', '9', '11', '3', 119999, '35', 8, '1', '12'],
          ]),
        );
      },
    );

    final values = await client.candles(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneHour,
      limit: 2,
    );

    expect(values.map((item) => item.openTime), [60000, 120000]);
    expect(values.first.close, 11);
    expect(values.first.baseVolume, 3);
    expect(values.first.quoteVolume, 35);
    expect(values.first.isClosed, isTrue);
    expect(values.last.isClosed, isTrue);
    expect(values.last.tradeCount, 9);
  });

  test('marks the current Binance candle as open and rejects invalid input',
      () async {
    final client = BinanceMarketDataClient(
      nowMilliseconds: () => 1000,
      get: (_) async => BinanceHttpResponse(
        statusCode: 200,
        body: jsonEncode([
          [0, '10', '12', '9', '11', '3', 1999, '35', 8, '1', '12'],
        ]),
      ),
    );

    await expectLater(
      client.candles(symbol: 'BTC-USDT', interval: KlineInterval.oneMinute),
      throwsArgumentError,
    );
    final values = await client.candles(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      limit: 1,
    );
    expect(values.single.isClosed, isFalse);
  });

  test('maps Binance 24-hour ticker and reports API errors', () async {
    final client = BinanceMarketDataClient(
      get: (uri) async {
        expect(uri.path, '/api/v3/ticker/24hr');
        expect(uri.queryParameters, {'symbol': 'BTCUSDT'});
        return BinanceHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'symbol': 'BTCUSDT',
            'lastPrice': '65000.5',
            'openPrice': '64000',
            'highPrice': '66000',
            'lowPrice': '63000',
            'volume': '123.4',
            'quoteVolume': '8000000',
          }),
        );
      },
    );

    final ticker = await client.ticker(symbol: 'BTCUSDT');

    expect(ticker.last, 65000.5);
    expect(ticker.change24h, 1000.5);
    expect(ticker.changePercent24h, closeTo(1.56328125, 0.000001));
    expect(ticker.quoteVolume24h, 8000000);
  });

  test('merges a current-candle replacement then an appended candle', () {
    Kline candle(int openTime, double close) => Kline(
          symbol: 'BTCUSDT',
          interval: KlineInterval.oneMinute,
          openTime: openTime,
          closeTime: openTime + 59999,
          open: close - 1,
          high: close + 1,
          low: close - 2,
          close: close,
          baseVolume: close,
          quoteVolume: close * 2,
          tradeCount: close.toInt(),
          isClosed: false,
        );
    final initial = [candle(0, 10), candle(60000, 11)];
    final replacement = mergeLatestBinanceCandles(
      existing: initial,
      updates: [candle(60000, 12)],
      maxLength: 2,
    );
    expect(replacement.appendedCount, 0);
    expect(replacement.replacedCount, 1);
    expect(replacement.candles.last.close, 12);

    final appended = mergeLatestBinanceCandles(
      existing: replacement.candles,
      updates: [candle(120000, 13)],
      maxLength: 2,
    );
    expect(appended.appendedCount, 1);
    expect(appended.candles.map((item) => item.openTime), [60000, 120000]);
  });
}
