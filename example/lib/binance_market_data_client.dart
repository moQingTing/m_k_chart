import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:m_k_chart/v2_example_support.dart';

import 'market/v2_demo_market_data_source.dart';

/// Public Spot market-data client used by the runnable V2 Example.
///
/// It only calls Binance's unauthenticated market-data domain and carries no
/// API keys, account state, order capability, or private user information.
class BinanceMarketDataClient implements V2DemoMarketDataSource {
  BinanceMarketDataClient({
    BinanceGetRequest? get,
    int Function()? nowMilliseconds,
  })  : _get = get ?? _defaultGet,
        _nowMilliseconds = nowMilliseconds ?? _systemNowMilliseconds;

  final BinanceGetRequest _get;
  final int Function() _nowMilliseconds;

  @override
  String get displayName => 'Binance';

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) async {
    _validateSymbol(symbol);
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 1000.');
    }
    final response = await _get(_candleUri(symbol, interval, limit))
        .timeout(const Duration(seconds: 12));
    return _decodeCandles(
      response,
      symbol: symbol,
      interval: interval,
      nowMilliseconds: _nowMilliseconds(),
    );
  }

  /// Loads the public 24-hour ticker rendered by the market summary.
  @override
  Future<BinanceTicker> ticker({required String symbol}) async {
    _validateSymbol(symbol);
    final response =
        await _get(_tickerUri(symbol)).timeout(const Duration(seconds: 12));
    return _decodeTicker(response, symbol: symbol);
  }
}

/// 默认 Demo 的可取消 HTTP 实现；不改变旧 [BinanceMarketDataClient] 子类的调用路径。
///
/// 每次请求拥有自己的 HTTP client 和 abort trigger。取消旧请求不会关闭新请求的连接。
final class AbortableBinanceMarketDataClient extends BinanceMarketDataClient
    implements V2DemoCancelableMarketDataSource {
  AbortableBinanceMarketDataClient({
    BinanceAbortableGetRequest? request,
    int Function()? nowMilliseconds,
  })  : _request = request ?? _defaultAbortableGet,
        super(nowMilliseconds: nowMilliseconds);

  final BinanceAbortableGetRequest _request;

  @override
  V2DemoMarketRequest<List<Kline>> requestCandles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) {
    _validateSymbol(symbol);
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 1000.');
    }
    final request = _request(_candleUri(symbol, interval, limit));
    Future<List<Kline>> decode() async => _decodeCandles(
          await _withAbortTimeout(request),
          symbol: symbol,
          interval: interval,
          nowMilliseconds: _nowMilliseconds(),
        );
    return V2DemoMarketRequest(result: decode(), cancel: request.cancel);
  }

  @override
  V2DemoMarketRequest<BinanceTicker> requestTicker({required String symbol}) {
    _validateSymbol(symbol);
    final request = _request(_tickerUri(symbol));
    Future<BinanceTicker> decode() async =>
        _decodeTicker(await _withAbortTimeout(request), symbol: symbol);
    return V2DemoMarketRequest(result: decode(), cancel: request.cancel);
  }

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) =>
      requestCandles(symbol: symbol, interval: interval, limit: limit).result;

  @override
  Future<BinanceTicker> ticker({required String symbol}) =>
      requestTicker(symbol: symbol).result;
}

/// 便于测试单请求取消；正式默认实现使用 [http.AbortableRequest]。
typedef BinanceAbortableGetRequest = V2DemoMarketRequest<BinanceHttpResponse>
    Function(Uri uri);

Future<BinanceHttpResponse> _withAbortTimeout(
  V2DemoMarketRequest<BinanceHttpResponse> request,
) =>
    request.result.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        request.cancel();
        throw TimeoutException('Binance request timed out.');
      },
    );

V2DemoMarketRequest<BinanceHttpResponse> _defaultAbortableGet(Uri uri) {
  final abort = Completer<void>();
  final client = http.Client();
  Future<BinanceHttpResponse> send() async {
    try {
      final response = await client.send(
        http.AbortableRequest('GET', uri, abortTrigger: abort.future),
      );
      final complete = await http.Response.fromStream(response);
      return BinanceHttpResponse(
        statusCode: complete.statusCode,
        body: complete.body,
      );
    } finally {
      client.close();
    }
  }

  return V2DemoMarketRequest(
    result: send(),
    cancel: () {
      if (!abort.isCompleted) abort.complete();
    },
  );
}

Uri _candleUri(String symbol, KlineInterval interval, int limit) => Uri.https(
      'data-api.binance.vision',
      '/api/v3/klines',
      {
        'symbol': symbol,
        'interval': _binanceInterval(interval),
        'limit': '$limit'
      },
    );

Uri _tickerUri(String symbol) => Uri.https(
      'data-api.binance.vision',
      '/api/v3/ticker/24hr',
      {'symbol': symbol},
    );

List<Kline> _decodeCandles(
  BinanceHttpResponse response, {
  required String symbol,
  required KlineInterval interval,
  required int nowMilliseconds,
}) {
  if (response.statusCode != 200) {
    throw StateError('Binance HTTP ${response.statusCode}.');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! List) {
    throw StateError(_binanceErrorMessage(decoded));
  }
  final values = decoded
      .map(
        (row) => _parseCandle(
          row,
          symbol: symbol,
          interval: interval,
          nowMilliseconds: nowMilliseconds,
        ),
      )
      .toList()
    ..sort((left, right) => left.openTime.compareTo(right.openTime));
  if (values.isEmpty) {
    throw const FormatException('Binance returned no candles.');
  }
  return List.unmodifiable(values);
}

BinanceTicker _decodeTicker(BinanceHttpResponse response,
    {required String symbol}) {
  if (response.statusCode != 200) {
    throw StateError('Binance HTTP ${response.statusCode}.');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) {
    throw StateError(_binanceErrorMessage(decoded));
  }
  return _parseTicker(decoded, symbol: symbol);
}

/// Injected in tests to keep parsing and HTTP behaviour independently tested.
typedef BinanceGetRequest = Future<BinanceHttpResponse> Function(Uri uri);

final class BinanceHttpResponse {
  const BinanceHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// Immutable subset of Binance's public 24-hour ticker payload.
final class BinanceTicker extends V2MarketTicker {
  const BinanceTicker({
    required super.symbol,
    required super.last,
    required super.open24h,
    required super.high24h,
    required super.low24h,
    required super.baseVolume24h,
    required super.quoteVolume24h,
  });
}

/// Result of merging Binance's most recent Kline window into a chart window.
///
/// Only matching candle identities are replaced; a newly opened candle is
/// appended and the oldest candles are trimmed to [maxLength]. This preserves
/// the chart's position while it is viewing history.
final class BinanceCandleMerge {
  const BinanceCandleMerge({
    required this.candles,
    required this.appendedCount,
    required this.replacedCount,
  });

  final List<Kline> candles;
  final int appendedCount;
  final int replacedCount;

  bool get changed => appendedCount > 0 || replacedCount > 0;
}

BinanceCandleMerge mergeLatestBinanceCandles({
  required List<Kline> existing,
  required List<Kline> updates,
  required int maxLength,
}) {
  if (maxLength < 1) {
    throw ArgumentError.value(maxLength, 'maxLength', 'Must be positive.');
  }
  final merged = existing.toList(growable: true);
  var appendedCount = 0;
  var replacedCount = 0;
  for (final update in updates) {
    final existingIndex = merged.indexWhere(update.hasSameIdentity);
    if (existingIndex >= 0) {
      if (merged[existingIndex] != update) {
        merged[existingIndex] = update;
        replacedCount++;
      }
      continue;
    }
    final insertionIndex = merged.indexWhere(
      (candle) => candle.openTime > update.openTime,
    );
    if (insertionIndex < 0) {
      merged.add(update);
      appendedCount++;
    } else {
      merged.insert(insertionIndex, update);
      // This is defensive for a delayed REST response. It changes the data
      // window but must not move a user who is browsing historical candles.
      replacedCount++;
    }
  }
  while (merged.length > maxLength) {
    merged.removeAt(0);
  }
  return BinanceCandleMerge(
    candles: List.unmodifiable(merged),
    appendedCount: appendedCount,
    replacedCount: replacedCount,
  );
}

Future<BinanceHttpResponse> _defaultGet(Uri uri) async {
  final response = await http.get(uri);
  return BinanceHttpResponse(
      statusCode: response.statusCode, body: response.body);
}

int _systemNowMilliseconds() => DateTime.now().millisecondsSinceEpoch;

void _validateSymbol(String symbol) {
  if (!RegExp(r'^[A-Z0-9]{5,20}$').hasMatch(symbol)) {
    throw ArgumentError.value(
      symbol,
      'symbol',
      'Use an uppercase Binance Spot symbol such as BTCUSDT.',
    );
  }
}

Kline _parseCandle(
  Object? row, {
  required String symbol,
  required KlineInterval interval,
  required int nowMilliseconds,
}) {
  if (row is! List || row.length < 11) {
    throw const FormatException('Binance candle must contain eleven fields.');
  }
  int integer(int index) {
    final value = int.tryParse(row[index].toString());
    if (value == null) {
      throw FormatException('Binance candle has invalid $index.');
    }
    return value;
  }

  double number(int index) {
    final value = double.tryParse(row[index].toString());
    if (value == null || !value.isFinite) {
      throw FormatException('Binance candle has invalid $index.');
    }
    return value;
  }

  final openTime = integer(0);
  final closeTime = integer(6);
  return Kline(
    symbol: symbol,
    interval: interval,
    openTime: openTime,
    closeTime: closeTime,
    open: number(1),
    high: number(2),
    low: number(3),
    close: number(4),
    baseVolume: number(5),
    quoteVolume: number(7),
    tradeCount: integer(8),
    takerBuyBaseVolume: number(9),
    takerBuyQuoteVolume: number(10),
    isClosed: nowMilliseconds > closeTime,
  );
}

BinanceTicker _parseTicker(Map decoded, {required String symbol}) {
  double number(String key) {
    final raw = decoded[key];
    final value = raw == null ? null : double.tryParse(raw.toString());
    if (value == null || !value.isFinite) {
      throw FormatException('Binance ticker has invalid $key.');
    }
    return value;
  }

  final responseSymbol = decoded['symbol'];
  if (responseSymbol != symbol) {
    throw const FormatException(
        'Binance ticker returned an unexpected symbol.');
  }
  return BinanceTicker(
    symbol: symbol,
    last: number('lastPrice'),
    open24h: number('openPrice'),
    high24h: number('highPrice'),
    low24h: number('lowPrice'),
    baseVolume24h: number('volume'),
    quoteVolume24h: number('quoteVolume'),
  );
}

String _binanceErrorMessage(Object? decoded) {
  if (decoded is Map && decoded['msg'] is String) {
    return 'Binance request failed: ${decoded['msg']}';
  }
  return 'Binance returned an unexpected response.';
}

String _binanceInterval(KlineInterval interval) => interval.code;
