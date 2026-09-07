import '../../entity/k_line_entity.dart';
import '../model/model.dart';

enum LegacyTimestampUnit {
  seconds,
  milliseconds,
}

/// Loss-aware bridge between the mutable 1.x entity and immutable 2.0 Kline.
final class KLineEntityAdapter {
  const KLineEntityAdapter({
    required this.symbol,
    required this.interval,
    this.timestampUnit = LegacyTimestampUnit.seconds,
    this.timeZoneOffset = Duration.zero,
    this.priceSource = KlinePriceSource.trade,
  });

  final String symbol;
  final KlineInterval interval;
  final LegacyTimestampUnit timestampUnit;
  final Duration timeZoneOffset;
  final KlinePriceSource priceSource;

  Kline toKline(
    KLineEntity entity, {
    required bool isClosed,
    int? closeTime,
    double takerBuyBaseVolume = 0,
    double takerBuyQuoteVolume = 0,
    int? firstTradeId,
    int? lastTradeId,
  }) {
    final openTime = _legacyToMilliseconds(entity.id);
    return Kline(
      symbol: symbol,
      interval: interval,
      openTime: openTime,
      closeTime: closeTime ?? _deriveCloseTime(openTime),
      open: entity.open,
      high: entity.high,
      low: entity.low,
      close: entity.close,
      baseVolume: entity.vol,
      quoteVolume: entity.amount,
      tradeCount: entity.count,
      takerBuyBaseVolume: takerBuyBaseVolume,
      takerBuyQuoteVolume: takerBuyQuoteVolume,
      firstTradeId: firstTradeId,
      lastTradeId: lastTradeId,
      isClosed: isClosed,
      timeZoneOffset: timeZoneOffset,
      priceSource: priceSource,
    );
  }

  KLineEntity toLegacy(Kline kline) {
    final entity = KLineEntity()
      ..id = _millisecondsToLegacy(kline.openTime)
      ..open = kline.open
      ..high = kline.high
      ..low = kline.low
      ..close = kline.close
      ..vol = kline.baseVolume
      ..amount = kline.quoteVolume
      ..count = kline.tradeCount;
    return entity;
  }

  int _legacyToMilliseconds(int timestamp) => switch (timestampUnit) {
        LegacyTimestampUnit.seconds => timestamp * 1000,
        LegacyTimestampUnit.milliseconds => timestamp,
      };

  int _millisecondsToLegacy(int timestamp) => switch (timestampUnit) {
        LegacyTimestampUnit.seconds => _exactSeconds(timestamp),
        LegacyTimestampUnit.milliseconds => timestamp,
      };

  int _exactSeconds(int timestamp) {
    if (timestamp % Duration.millisecondsPerSecond != 0) {
      throw StateError(
        'Kline openTime $timestamp cannot be represented as whole legacy '
        'seconds without losing precision.',
      );
    }
    return timestamp ~/ Duration.millisecondsPerSecond;
  }

  int _deriveCloseTime(int openTime) {
    final duration = interval.duration;
    if (duration == null) {
      throw ArgumentError(
        'closeTime is required for calendar interval ${interval.code}.',
      );
    }
    return openTime + duration.inMilliseconds - 1;
  }
}
