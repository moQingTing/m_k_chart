import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/entity/k_line_entity.dart';
import 'package:m_k_chart/src/adapter/adapter.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  group('KLineEntityAdapter', () {
    final adapter = KLineEntityAdapter(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
    );

    test('maps legacy seconds and shared OHLCV fields to immutable Kline', () {
      final model = adapter.toKline(_legacy(), isClosed: true);

      expect(model.symbol, 'BTCUSDT');
      expect(model.interval, KlineInterval.oneMinute);
      expect(model.openTime, 1724457600000);
      expect(model.closeTime, 1724457659999);
      expect(model.open, 64000);
      expect(model.high, 64200);
      expect(model.low, 63900);
      expect(model.close, 64150);
      expect(model.baseVolume, 12.5);
      expect(model.quoteVolume, 801875);
      expect(model.tradeCount, 240);
      expect(model.isClosed, isTrue);
    });

    test('accepts explicit fields that do not exist in legacy entity', () {
      final configured = KLineEntityAdapter(
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        timeZoneOffset: const Duration(hours: 8),
        priceSource: KlinePriceSource.mark,
      );

      final model = configured.toKline(
        _legacy(),
        isClosed: false,
        closeTime: 1724457659000,
        takerBuyBaseVolume: 7.5,
        takerBuyQuoteVolume: 481125,
        firstTradeId: 1000,
        lastTradeId: 1239,
      );

      expect(model.closeTime, 1724457659000);
      expect(model.timeZoneOffset, const Duration(hours: 8));
      expect(model.priceSource, KlinePriceSource.mark);
      expect(model.takerBuyBaseVolume, 7.5);
      expect(model.firstTradeId, 1000);
      expect(model.isClosed, isFalse);
    });

    test('requires explicit close time for a calendar interval', () {
      final monthly = KLineEntityAdapter(
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMonth,
      );

      expect(
        () => monthly.toKline(_legacy(), isClosed: true),
        throwsArgumentError,
      );

      final model = monthly.toKline(
        _legacy(),
        isClosed: true,
        closeTime: 1727222399999,
      );
      expect(model.closeTime, 1727222399999);
    });

    test('supports legacy data that already stores milliseconds', () {
      final milliseconds = KLineEntityAdapter(
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        timestampUnit: LegacyTimestampUnit.milliseconds,
      );
      final legacy = _legacy()..id = 1724457600000;

      final model = milliseconds.toKline(legacy, isClosed: true);
      final restored = milliseconds.toLegacy(model);

      expect(model.openTime, 1724457600000);
      expect(restored.id, legacy.id);
    });

    test('round trip preserves every field shared with legacy entity', () {
      final legacy = _legacy();

      final restored = adapter.toLegacy(
        adapter.toKline(legacy, isClosed: true),
      );

      expect(restored.toJson(), legacy.toJson());
    });

    test('rejects lossy millisecond to legacy-second conversion', () {
      final model = adapter
          .toKline(
            _legacy(),
            isClosed: false,
          )
          .copyWith(closeTime: 1724457659999);
      final subsecondOpen = Kline(
        symbol: model.symbol,
        interval: model.interval,
        openTime: model.openTime + 1,
        closeTime: model.closeTime,
        open: model.open,
        high: model.high,
        low: model.low,
        close: model.close,
        baseVolume: model.baseVolume,
        quoteVolume: model.quoteVolume,
        tradeCount: model.tradeCount,
        isClosed: model.isClosed,
      );

      expect(() => adapter.toLegacy(subsecondOpen), throwsStateError);
    });

    test('new model validation rejects invalid mutable legacy values', () {
      final invalid = _legacy()..high = double.nan;

      expect(
        () => adapter.toKline(invalid, isClosed: true),
        throwsArgumentError,
      );
    });
  });
}

KLineEntity _legacy() => KLineEntity()
  ..id = 1724457600
  ..open = 64000
  ..high = 64200
  ..low = 63900
  ..close = 64150
  ..vol = 12.5
  ..amount = 801875
  ..count = 240;
