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
}
