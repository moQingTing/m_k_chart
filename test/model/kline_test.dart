import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  group('Kline', () {
    test('stores immutable Binance-compatible OHLCV fields', () {
      final kline = _validKline();

      expect(kline.symbol, 'BTCUSDT');
      expect(kline.interval, KlineInterval.oneMinute);
      expect(kline.openTime, 1724457600000);
      expect(kline.closeTime, 1724457659999);
      expect(kline.open, 64000);
      expect(kline.high, 64200);
      expect(kline.low, 63900);
      expect(kline.close, 64150);
      expect(kline.baseVolume, 12.5);
      expect(kline.quoteVolume, 801875);
      expect(kline.tradeCount, 240);
      expect(kline.takerBuyBaseVolume, 7.5);
      expect(kline.takerBuyQuoteVolume, 481125);
      expect(kline.firstTradeId, 1000);
      expect(kline.lastTradeId, 1239);
      expect(kline.isClosed, isTrue);
      expect(kline.timeZoneOffset, Duration.zero);
      expect(kline.priceSource, KlinePriceSource.trade);
    });

    test('exposes UTC DateTime without changing stored epoch values', () {
      final kline = _validKline();

      expect(kline.openDateTime.isUtc, isTrue);
      expect(kline.closeDateTime.isUtc, isTrue);
      expect(kline.openDateTime.millisecondsSinceEpoch, kline.openTime);
      expect(kline.closeDateTime.millisecondsSinceEpoch, kline.closeTime);
    });

    test('identity excludes mutable candle values but includes price source',
        () {
      final original = _validKline();
      final updated = original.copyWith(close: 64180, isClosed: false);
      final mark = _validKline(priceSource: KlinePriceSource.mark);

      expect(original.hasSameIdentity(updated), isTrue);
      expect(original.hasSameIdentity(mark), isFalse);
      expect(KlinePriceSource.indexPrice.code, 'index');
    });

    test('copyWith returns a validated value and preserves identity fields',
        () {
      final original = _validKline(isClosed: false);
      final updated = original.copyWith(
        high: 64300,
        close: 64250,
        baseVolume: 13,
        quoteVolume: 835250,
        takerBuyBaseVolume: 8,
        takerBuyQuoteVolume: 514000,
        tradeCount: 250,
        lastTradeId: 1249,
        isClosed: true,
      );

      expect(updated.symbol, original.symbol);
      expect(updated.interval, original.interval);
      expect(updated.openTime, original.openTime);
      expect(updated.close, 64250);
      expect(updated.isClosed, isTrue);
      expect(original.close, 64150);
      expect(original.isClosed, isFalse);
    });

    test('uses structural equality for deterministic snapshots', () {
      final first = _validKline();
      final second = _validKline();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('BTCUSDT'));
    });

    test('rejects invalid identity and timestamps', () {
      expect(() => _validKline(symbol: '  '), throwsArgumentError);
      expect(
        () => _validKline(closeTime: 1724457599999),
        throwsArgumentError,
      );
    });

    test('rejects non-finite, negative, and inconsistent prices', () {
      expect(() => _validKline(open: double.nan), throwsArgumentError);
      expect(() => _validKline(low: -1), throwsArgumentError);
      expect(() => _validKline(high: 64001, close: 64150), throwsArgumentError);
      expect(() => _validKline(low: 64100, open: 64000), throwsArgumentError);
    });

    test('rejects invalid volume, count, and trade ID ranges', () {
      expect(() => _validKline(baseVolume: -1), throwsArgumentError);
      expect(
        () => _validKline(baseVolume: 5, takerBuyBaseVolume: 7.5),
        throwsArgumentError,
      );
      expect(() => _validKline(tradeCount: -1), throwsArgumentError);
      expect(
        () => _validKline(firstTradeId: 2000, lastTradeId: 1239),
        throwsArgumentError,
      );
    });

    test('accepts Binance timezone range in whole minutes only', () {
      expect(
        _validKline(timeZoneOffset: const Duration(hours: -12)),
        isA<Kline>(),
      );
      expect(
        _validKline(timeZoneOffset: const Duration(hours: 14)),
        isA<Kline>(),
      );
      expect(
        () => _validKline(timeZoneOffset: const Duration(hours: 15)),
        throwsArgumentError,
      );
      expect(
        () => _validKline(timeZoneOffset: const Duration(seconds: 30)),
        throwsArgumentError,
      );
    });
  });
}

Kline _validKline({
  String symbol = 'BTCUSDT',
  int closeTime = 1724457659999,
  double open = 64000,
  double high = 64200,
  double low = 63900,
  double close = 64150,
  double baseVolume = 12.5,
  double quoteVolume = 801875,
  int tradeCount = 240,
  double takerBuyBaseVolume = 7.5,
  double takerBuyQuoteVolume = 481125,
  int? firstTradeId = 1000,
  int? lastTradeId = 1239,
  bool isClosed = true,
  Duration timeZoneOffset = Duration.zero,
  KlinePriceSource priceSource = KlinePriceSource.trade,
}) =>
    Kline(
      symbol: symbol,
      interval: KlineInterval.oneMinute,
      openTime: 1724457600000,
      closeTime: closeTime,
      open: open,
      high: high,
      low: low,
      close: close,
      baseVolume: baseVolume,
      quoteVolume: quoteVolume,
      tradeCount: tradeCount,
      takerBuyBaseVolume: takerBuyBaseVolume,
      takerBuyQuoteVolume: takerBuyQuoteVolume,
      firstTradeId: firstTradeId,
      lastTradeId: lastTradeId,
      isClosed: isClosed,
      timeZoneOffset: timeZoneOffset,
      priceSource: priceSource,
    );
