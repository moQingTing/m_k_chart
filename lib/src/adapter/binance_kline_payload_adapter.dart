import '../model/model.dart';

enum BinanceTimestampUnit {
  milliseconds,
  microseconds,
}

final class BinanceKlineEvent {
  const BinanceKlineEvent({
    required this.kline,
    required this.eventTime,
    this.streamName,
  });

  final Kline kline;
  final int eventTime;
  final String? streamName;
}

/// Pure payload mapper for Binance Spot REST and WebSocket Kline responses.
///
/// Network ownership, JSON decoding, retries, subscription lifecycle, and
/// authentication remain the responsibility of the host application.
final class BinanceKlinePayloadAdapter {
  const BinanceKlinePayloadAdapter({
    this.timeZoneOffset = Duration.zero,
    this.priceSource = KlinePriceSource.trade,
    this.timestampUnit = BinanceTimestampUnit.milliseconds,
  });

  final Duration timeZoneOffset;
  final KlinePriceSource priceSource;
  final BinanceTimestampUnit timestampUnit;

  Kline parseRestKline(
    List<Object?> row, {
    required String symbol,
    required KlineInterval interval,
    required bool isClosed,
  }) {
    if (row.length != 12) {
      throw FormatException(
        'Binance REST Kline must contain exactly 12 fields; got ${row.length}.',
      );
    }
    return Kline(
      symbol: symbol,
      interval: interval,
      openTime: _timestamp(row[0], 'openTime'),
      open: _double(row[1], 'open'),
      high: _double(row[2], 'high'),
      low: _double(row[3], 'low'),
      close: _double(row[4], 'close'),
      baseVolume: _double(row[5], 'baseVolume'),
      closeTime: _timestamp(row[6], 'closeTime'),
      quoteVolume: _double(row[7], 'quoteVolume'),
      tradeCount: _integer(row[8], 'tradeCount'),
      takerBuyBaseVolume: _double(row[9], 'takerBuyBaseVolume'),
      takerBuyQuoteVolume: _double(row[10], 'takerBuyQuoteVolume'),
      isClosed: isClosed,
      timeZoneOffset: timeZoneOffset,
      priceSource: priceSource,
    );
  }

  List<Kline> parseRestResponse(
    List<Object?> response, {
    required String symbol,
    required KlineInterval interval,
    required int currentTime,
  }) {
    final currentTimeMs = _timestamp(currentTime, 'currentTime');
    return List<Kline>.unmodifiable(
      response.map((value) {
        final row = _list(value, 'REST Kline row');
        final closeTime = _timestamp(
          row.length > 6 ? row[6] : null,
          'closeTime',
        );
        return parseRestKline(
          row,
          symbol: symbol,
          interval: interval,
          isClosed: closeTime < currentTimeMs,
        );
      }),
    );
  }

  BinanceKlineEvent parseWebSocketEvent(Map<String, Object?> message) {
    final combinedData = message['data'];
    final payload = combinedData == null
        ? message
        : _map(combinedData, 'combined stream data');
    final streamName =
        combinedData == null ? null : _string(message['stream'], 'stream');

    if (_string(payload['e'], 'event type') != 'kline') {
      throw const FormatException('Expected Binance kline event.');
    }
    final klinePayload = _map(payload['k'], 'kline');
    final outerSymbol = _string(payload['s'], 'symbol');
    final symbol = _string(klinePayload['s'], 'kline symbol');
    if (outerSymbol != symbol) {
      throw FormatException(
        'Outer symbol $outerSymbol does not match Kline symbol $symbol.',
      );
    }
    final interval = intervalFromCode(
      _string(klinePayload['i'], 'interval'),
    );

    final kline = Kline(
      symbol: symbol,
      interval: interval,
      openTime: _timestamp(klinePayload['t'], 'openTime'),
      closeTime: _timestamp(klinePayload['T'], 'closeTime'),
      open: _double(klinePayload['o'], 'open'),
      high: _double(klinePayload['h'], 'high'),
      low: _double(klinePayload['l'], 'low'),
      close: _double(klinePayload['c'], 'close'),
      baseVolume: _double(klinePayload['v'], 'baseVolume'),
      quoteVolume: _double(klinePayload['q'], 'quoteVolume'),
      tradeCount: _integer(klinePayload['n'], 'tradeCount'),
      takerBuyBaseVolume: _double(
        klinePayload['V'],
        'takerBuyBaseVolume',
      ),
      takerBuyQuoteVolume: _double(
        klinePayload['Q'],
        'takerBuyQuoteVolume',
      ),
      firstTradeId: _integer(klinePayload['f'], 'firstTradeId'),
      lastTradeId: _integer(klinePayload['L'], 'lastTradeId'),
      isClosed: _boolean(klinePayload['x'], 'isClosed'),
      timeZoneOffset: timeZoneOffset,
      priceSource: priceSource,
    );

    return BinanceKlineEvent(
      kline: kline,
      eventTime: _timestamp(payload['E'], 'eventTime'),
      streamName: streamName,
    );
  }

  static KlineInterval intervalFromCode(String code) => switch (code) {
        '1s' => KlineInterval.oneSecond,
        '1m' => KlineInterval.oneMinute,
        '3m' => KlineInterval.threeMinutes,
        '5m' => KlineInterval.fiveMinutes,
        '15m' => KlineInterval.fifteenMinutes,
        '30m' => KlineInterval.thirtyMinutes,
        '1h' => KlineInterval.oneHour,
        '2h' => KlineInterval.twoHours,
        '4h' => KlineInterval.fourHours,
        '6h' => KlineInterval.sixHours,
        '8h' => KlineInterval.eightHours,
        '12h' => KlineInterval.twelveHours,
        '1d' => KlineInterval.oneDay,
        '3d' => KlineInterval.threeDays,
        '1w' => KlineInterval.oneWeek,
        '1M' => KlineInterval.oneMonth,
        _ => throw FormatException('Unsupported Binance Kline interval: $code'),
      };

  int _timestamp(Object? value, String field) {
    final parsed = _integer(value, field);
    return switch (timestampUnit) {
      BinanceTimestampUnit.milliseconds => parsed,
      BinanceTimestampUnit.microseconds =>
        parsed ~/ Duration.microsecondsPerMillisecond,
    };
  }
}

int _integer(Object? value, String field) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('Binance field $field must be an integer; got $value.');
}

double _double(Object? value, String field) {
  final parsed = switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
  if (parsed == null || !parsed.isFinite) {
    throw FormatException(
      'Binance field $field must be a finite number; got $value.',
    );
  }
  return parsed;
}

bool _boolean(Object? value, String field) {
  if (value is bool) {
    return value;
  }
  throw FormatException('Binance field $field must be a boolean; got $value.');
}

String _string(Object? value, String field) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Binance field $field must be a string; got $value.');
}

List<Object?> _list(Object? value, String field) {
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('Binance field $field must be a list; got $value.');
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    try {
      return value.cast<String, Object?>();
    } on TypeError {
      // Converted to the consistent FormatException below.
    }
  }
  throw FormatException('Binance field $field must be an object; got $value.');
}
