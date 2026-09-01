import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/v2_example_support.dart';
import 'package:m_k_chart_example/okx_market_data_client.dart';

void main() {
  test('maps and chronologically sorts the official OKX candle schema',
      () async {
    final client = OkxMarketDataClient(
      get: (uri) async {
        expect(uri.path, '/api/v5/market/candles');
        expect(uri.queryParameters, {
          'instId': 'BTC-USDT',
          'bar': '1H',
          'limit': '2',
        });
        return OkxHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'code': '0',
            'msg': '',
            'data': [
              ['120000', '11', '14', '10', '13', '4', '50', '52', '0'],
              ['60000', '10', '12', '9', '11', '3', '33', '35', '1'],
            ],
          }),
        );
      },
    );

    final values = await client.candles(
      instId: 'BTC-USDT',
      interval: KlineInterval.oneHour,
      limit: 2,
    );

    expect(values.map((item) => item.openTime), [60000, 120000]);
    expect(values.first.close, 11);
    expect(values.first.baseVolume, 3);
    expect(values.first.quoteVolume, 35);
    expect(values.first.isClosed, isTrue);
    expect(values.last.isClosed, isFalse);
  });

  test('rejects malformed OKX envelopes and invalid requests', () async {
    final client = OkxMarketDataClient(
      get: (_) async => const OkxHttpResponse(
        statusCode: 200,
        body: '{"code":"51000"}',
      ),
    );

    await expectLater(
      client.candles(
        instId: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
      ),
      throwsArgumentError,
    );
    await expectLater(
      client.candles(
        instId: 'BTC-USDT',
        interval: KlineInterval.oneMinute,
      ),
      throwsStateError,
    );
  });

  test('maps the official OKX 24-hour ticker schema', () async {
    final client = OkxMarketDataClient(
      get: (uri) async {
        expect(uri.path, '/api/v5/market/ticker');
        expect(uri.queryParameters, {'instId': 'BTC-USDT'});
        return OkxHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'code': '0',
            'data': [
              {
                'instId': 'BTC-USDT',
                'last': '65000.5',
                'open24h': '64000',
                'high24h': '66000',
                'low24h': '63000',
                'vol24h': '123.4',
                'volCcy24h': '8000000',
              },
            ],
          }),
        );
      },
    );

    final ticker = await client.ticker(instId: 'BTC-USDT');

    expect(ticker.last, 65000.5);
    expect(ticker.change24h, 1000.5);
    expect(ticker.changePercent24h, closeTo(1.56328125, 0.000001));
    expect(ticker.quoteVolume24h, 8000000);
  });
}
