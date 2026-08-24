import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/adapter/adapter.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  group('BinanceKlinePayloadAdapter REST', () {
    const adapter = BinanceKlinePayloadAdapter();

    test('maps the official twelve-field REST tuple', () {
      final kline = adapter.parseRestKline(
        _restRow(),
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        isClosed: true,
      );

      expect(kline.openTime, 1499040000000);
      expect(kline.closeTime, 1499040059999);
      expect(kline.open, 0.01634790);
      expect(kline.high, 0.8);
      expect(kline.low, 0.015758);
      expect(kline.close, 0.015771);
      expect(kline.baseVolume, 148976.11427815);
      expect(kline.quoteVolume, 2434.19055334);
      expect(kline.tradeCount, 308);
      expect(kline.takerBuyBaseVolume, 1756.87402397);
      expect(kline.takerBuyQuoteVolume, 28.46694368);
      expect(kline.firstTradeId, isNull);
      expect(kline.isClosed, isTrue);
    });

    test('bulk response derives closed status from injected current time', () {
      final first = _restRow();
      final second = _restRow(
        openTime: 1499040060000,
        closeTime: 1499040119999,
      );

      final values = adapter.parseRestResponse(
        [first, second],
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        currentTime: 1499040100000,
      );

      expect(values.first.isClosed, isTrue);
      expect(values.last.isClosed, isFalse);
      expect(() => values.add(values.first), throwsUnsupportedError);
    });

    test('supports official microsecond response mode', () {
      const microseconds = BinanceKlinePayloadAdapter(
        timestampUnit: BinanceTimestampUnit.microseconds,
      );
      final row = _restRow(
        openTime: 1499040000000000,
        closeTime: 1499040059999999,
      );

      final kline = microseconds.parseRestKline(
        row,
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        isClosed: true,
      );

      expect(kline.openTime, 1499040000000);
      expect(kline.closeTime, 1499040059999);
    });

    test('rejects malformed tuple shape and numeric fields', () {
      expect(
        () => adapter.parseRestKline(
          [1, 2],
          symbol: 'BTCUSDT',
          interval: KlineInterval.oneMinute,
          isClosed: true,
        ),
        throwsFormatException,
      );
      final invalid = _restRow()..[1] = 'not-a-price';
      expect(
        () => adapter.parseRestKline(
          invalid,
          symbol: 'BTCUSDT',
          interval: KlineInterval.oneMinute,
          isClosed: true,
        ),
        throwsFormatException,
      );
    });
  });

  group('BinanceKlinePayloadAdapter WebSocket', () {
    const adapter = BinanceKlinePayloadAdapter();

    test('maps an official raw Kline stream payload', () {
      final event = adapter.parseWebSocketEvent(_webSocketPayload());
      final kline = event.kline;

      expect(event.eventTime, 1672515782136);
      expect(event.streamName, isNull);
      expect(kline.symbol, 'BNBBTC');
      expect(kline.interval, KlineInterval.oneMinute);
      expect(kline.openTime, 1672515780000);
      expect(kline.closeTime, 1672515839999);
      expect(kline.firstTradeId, 100);
      expect(kline.lastTradeId, 200);
      expect(kline.tradeCount, 100);
      expect(kline.isClosed, isFalse);
      expect(kline.takerBuyBaseVolume, 500);
    });

    test('unwraps a combined stream payload', () {
      final event = adapter.parseWebSocketEvent({
        'stream': 'bnbbtc@kline_1m',
        'data': _webSocketPayload(),
      });

      expect(event.streamName, 'bnbbtc@kline_1m');
      expect(event.kline.symbol, 'BNBBTC');
    });

    test('applies configured timezone and price source metadata', () {
      const configured = BinanceKlinePayloadAdapter(
        timeZoneOffset: Duration(hours: 8),
        priceSource: KlinePriceSource.mark,
      );

      final event = configured.parseWebSocketEvent(_webSocketPayload());

      expect(event.kline.timeZoneOffset, const Duration(hours: 8));
      expect(event.kline.priceSource, KlinePriceSource.mark);
    });

    test('rejects wrong event, symbol mismatch, and unknown interval', () {
      final wrongEvent = _webSocketPayload()..['e'] = 'trade';
      expect(
        () => adapter.parseWebSocketEvent(wrongEvent),
        throwsFormatException,
      );

      final mismatch = _webSocketPayload();
      (mismatch['k']! as Map<String, Object?>)['s'] = 'ETHBTC';
      expect(
        () => adapter.parseWebSocketEvent(mismatch),
        throwsFormatException,
      );

      final unknown = _webSocketPayload();
      (unknown['k']! as Map<String, Object?>)['i'] = '45m';
      expect(
        () => adapter.parseWebSocketEvent(unknown),
        throwsFormatException,
      );
    });

    test('supports every documented Binance Kline interval', () {
      const codes = [
        '1s',
        '1m',
        '3m',
        '5m',
        '15m',
        '30m',
        '1h',
        '2h',
        '4h',
        '6h',
        '8h',
        '12h',
        '1d',
        '3d',
        '1w',
        '1M',
      ];

      expect(
        codes.map(BinanceKlinePayloadAdapter.intervalFromCode).map(
              (value) => value.code,
            ),
        codes,
      );
    });
  });

  test('Binance adapter has no network or transport package dependency', () {
    final source = File(
      '${Directory.current.path}/lib/src/adapter/'
      'binance_kline_payload_adapter.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
    expect(source, isNot(contains('package:http')));
    expect(source, isNot(contains('package:web_socket')));
  });
}

List<Object?> _restRow({
  int openTime = 1499040000000,
  int closeTime = 1499040059999,
}) =>
    [
      openTime,
      '0.01634790',
      '0.80000000',
      '0.01575800',
      '0.01577100',
      '148976.11427815',
      closeTime,
      '2434.19055334',
      308,
      '1756.87402397',
      '28.46694368',
      '0',
    ];

Map<String, Object?> _webSocketPayload() => {
      'e': 'kline',
      'E': 1672515782136,
      's': 'BNBBTC',
      'k': <String, Object?>{
        't': 1672515780000,
        'T': 1672515839999,
        's': 'BNBBTC',
        'i': '1m',
        'f': 100,
        'L': 200,
        'o': '0.0010',
        'c': '0.0020',
        'h': '0.0025',
        'l': '0.0005',
        'v': '1000',
        'n': 100,
        'x': false,
        'q': '1.0000',
        'V': '500',
        'Q': '0.500',
        'B': '123456',
      },
    };
