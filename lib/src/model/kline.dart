import 'kline_interval.dart';

enum KlinePriceSource {
  trade('trade'),
  mark('mark'),
  indexPrice('index');

  const KlinePriceSource(this.code);

  final String code;
}

/// Immutable OHLCV data for one symbol, interval, and price source.
final class Kline {
  factory Kline({
    required String symbol,
    required KlineInterval interval,
    required int openTime,
    required int closeTime,
    required double open,
    required double high,
    required double low,
    required double close,
    required double baseVolume,
    required double quoteVolume,
    required int tradeCount,
    required bool isClosed,
    double takerBuyBaseVolume = 0,
    double takerBuyQuoteVolume = 0,
    int? firstTradeId,
    int? lastTradeId,
    Duration timeZoneOffset = Duration.zero,
    KlinePriceSource priceSource = KlinePriceSource.trade,
  }) {
    _validate(
      symbol: symbol,
      openTime: openTime,
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
      timeZoneOffset: timeZoneOffset,
    );
    return Kline._(
      symbol: symbol,
      interval: interval,
      openTime: openTime,
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
  }

  const Kline._({
    required this.symbol,
    required this.interval,
    required this.openTime,
    required this.closeTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.baseVolume,
    required this.quoteVolume,
    required this.tradeCount,
    required this.takerBuyBaseVolume,
    required this.takerBuyQuoteVolume,
    required this.firstTradeId,
    required this.lastTradeId,
    required this.isClosed,
    required this.timeZoneOffset,
    required this.priceSource,
  });

  final String symbol;
  final KlineInterval interval;

  /// UTC Unix epoch milliseconds.
  final int openTime;

  /// UTC Unix epoch milliseconds.
  final int closeTime;

  final double open;
  final double high;
  final double low;
  final double close;
  final double baseVolume;
  final double quoteVolume;
  final int tradeCount;
  final double takerBuyBaseVolume;
  final double takerBuyQuoteVolume;
  final int? firstTradeId;
  final int? lastTradeId;
  final bool isClosed;

  /// Display/session boundary offset. Stored timestamps always remain UTC.
  final Duration timeZoneOffset;

  final KlinePriceSource priceSource;

  DateTime get openDateTime =>
      DateTime.fromMillisecondsSinceEpoch(openTime, isUtc: true);

  DateTime get closeDateTime =>
      DateTime.fromMillisecondsSinceEpoch(closeTime, isUtc: true);

  bool hasSameIdentity(Kline other) =>
      symbol == other.symbol &&
      interval == other.interval &&
      openTime == other.openTime &&
      priceSource == other.priceSource;

  Kline copyWith({
    int? closeTime,
    double? open,
    double? high,
    double? low,
    double? close,
    double? baseVolume,
    double? quoteVolume,
    int? tradeCount,
    double? takerBuyBaseVolume,
    double? takerBuyQuoteVolume,
    int? firstTradeId,
    int? lastTradeId,
    bool? isClosed,
  }) =>
      Kline(
        symbol: symbol,
        interval: interval,
        openTime: openTime,
        closeTime: closeTime ?? this.closeTime,
        open: open ?? this.open,
        high: high ?? this.high,
        low: low ?? this.low,
        close: close ?? this.close,
        baseVolume: baseVolume ?? this.baseVolume,
        quoteVolume: quoteVolume ?? this.quoteVolume,
        tradeCount: tradeCount ?? this.tradeCount,
        takerBuyBaseVolume: takerBuyBaseVolume ?? this.takerBuyBaseVolume,
        takerBuyQuoteVolume: takerBuyQuoteVolume ?? this.takerBuyQuoteVolume,
        firstTradeId: firstTradeId ?? this.firstTradeId,
        lastTradeId: lastTradeId ?? this.lastTradeId,
        isClosed: isClosed ?? this.isClosed,
        timeZoneOffset: timeZoneOffset,
        priceSource: priceSource,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Kline &&
          symbol == other.symbol &&
          interval == other.interval &&
          openTime == other.openTime &&
          closeTime == other.closeTime &&
          open == other.open &&
          high == other.high &&
          low == other.low &&
          close == other.close &&
          baseVolume == other.baseVolume &&
          quoteVolume == other.quoteVolume &&
          tradeCount == other.tradeCount &&
          takerBuyBaseVolume == other.takerBuyBaseVolume &&
          takerBuyQuoteVolume == other.takerBuyQuoteVolume &&
          firstTradeId == other.firstTradeId &&
          lastTradeId == other.lastTradeId &&
          isClosed == other.isClosed &&
          timeZoneOffset == other.timeZoneOffset &&
          priceSource == other.priceSource;

  @override
  int get hashCode => Object.hashAll([
        symbol,
        interval,
        openTime,
        closeTime,
        open,
        high,
        low,
        close,
        baseVolume,
        quoteVolume,
        tradeCount,
        takerBuyBaseVolume,
        takerBuyQuoteVolume,
        firstTradeId,
        lastTradeId,
        isClosed,
        timeZoneOffset,
        priceSource,
      ]);

  @override
  String toString() =>
      'Kline(symbol: $symbol, interval: $interval, openTime: $openTime, '
      'open: $open, high: $high, low: $low, close: $close, '
      'isClosed: $isClosed, priceSource: $priceSource)';

  static void _validate({
    required String symbol,
    required int openTime,
    required int closeTime,
    required double open,
    required double high,
    required double low,
    required double close,
    required double baseVolume,
    required double quoteVolume,
    required int tradeCount,
    required double takerBuyBaseVolume,
    required double takerBuyQuoteVolume,
    required int? firstTradeId,
    required int? lastTradeId,
    required Duration timeZoneOffset,
  }) {
    if (symbol.trim().isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', 'Must not be empty.');
    }
    if (openTime < 0 || closeTime < openTime) {
      throw ArgumentError('Kline timestamps must be ordered UTC epoch values.');
    }

    final prices = <String, double>{
      'open': open,
      'high': high,
      'low': low,
      'close': close,
    };
    for (final entry in prices.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Price must be finite and non-negative.',
        );
      }
    }
    if (high < open || high < close || high < low) {
      throw ArgumentError.value(high, 'high', 'Must be the highest price.');
    }
    if (low > open || low > close) {
      throw ArgumentError.value(low, 'low', 'Must be the lowest price.');
    }

    final volumes = <String, double>{
      'baseVolume': baseVolume,
      'quoteVolume': quoteVolume,
      'takerBuyBaseVolume': takerBuyBaseVolume,
      'takerBuyQuoteVolume': takerBuyQuoteVolume,
    };
    for (final entry in volumes.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Volume must be finite and non-negative.',
        );
      }
    }
    if (takerBuyBaseVolume > baseVolume || takerBuyQuoteVolume > quoteVolume) {
      throw ArgumentError('Taker buy volume cannot exceed total volume.');
    }
    if (tradeCount < 0) {
      throw ArgumentError.value(
        tradeCount,
        'tradeCount',
        'Must be non-negative.',
      );
    }
    if ((firstTradeId != null && firstTradeId < 0) ||
        (lastTradeId != null && lastTradeId < 0) ||
        (firstTradeId != null &&
            lastTradeId != null &&
            firstTradeId > lastTradeId)) {
      throw ArgumentError('Trade IDs must be non-negative and ordered.');
    }

    const minimumOffset = Duration(hours: -12);
    const maximumOffset = Duration(hours: 14);
    if (timeZoneOffset < minimumOffset ||
        timeZoneOffset > maximumOffset ||
        timeZoneOffset.inSeconds % Duration.secondsPerMinute != 0) {
      throw ArgumentError.value(
        timeZoneOffset,
        'timeZoneOffset',
        'Must use whole minutes between UTC-12:00 and UTC+14:00.',
      );
    }
  }
}
