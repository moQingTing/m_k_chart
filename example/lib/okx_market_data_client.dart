import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:m_k_chart/v2_example_support.dart';

/// Public-market-data client used by the runnable V2 Example.
///
/// It only calls OKX's unauthenticated candlestick endpoint and carries no API
/// keys, account state, or trading capability.
class OkxMarketDataClient {
  OkxMarketDataClient({OkxGetRequest? get}) : _get = get ?? _defaultGet;

  final OkxGetRequest _get;

  Future<List<Kline>> candles({
    required String instId,
    required KlineInterval interval,
    int limit = 180,
  }) async {
    if (!RegExp(r'^[A-Z0-9]+-[A-Z0-9]+(?:-[A-Z]+)?$').hasMatch(instId)) {
      throw ArgumentError.value(instId, 'instId', 'Invalid OKX instrument id.');
    }
    if (limit < 1 || limit > 300) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 300.');
    }
    final response = await _get(
      Uri.https('www.okx.com', '/api/v5/market/candles', {
        'instId': instId,
        'bar': _okxBar(interval),
        'limit': '$limit',
      }),
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('OKX HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['code'] != '0') {
      final message = decoded is Map ? decoded['msg'] : null;
      throw StateError(
          'OKX request failed${message == null ? '' : ': $message'}');
    }
    final rows = decoded['data'];
    if (rows is! List) {
      throw const FormatException('OKX data must be an array.');
    }
    final values = rows
        .map((row) => _parseCandle(
              row,
              instId: instId,
              interval: interval,
            ))
        .toList()
      ..sort((left, right) => left.openTime.compareTo(right.openTime));
    if (values.isEmpty) {
      throw const FormatException('OKX returned no candles.');
    }
    return List.unmodifiable(values);
  }

  /// Loads the public 24-hour ticker used by the example's market summary.
  ///
  /// This remains an unauthenticated read-only request and intentionally does
  /// not expose any account, order, or trading capability.
  Future<OkxTicker> ticker({required String instId}) async {
    if (!RegExp(r'^[A-Z0-9]+-[A-Z0-9]+(?:-[A-Z]+)?$').hasMatch(instId)) {
      throw ArgumentError.value(instId, 'instId', 'Invalid OKX instrument id.');
    }
    final response = await _get(
      Uri.https('www.okx.com', '/api/v5/market/ticker', {'instId': instId}),
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('OKX HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['code'] != '0') {
      final message = decoded is Map ? decoded['msg'] : null;
      throw StateError(
        'OKX request failed${message == null ? '' : ': $message'}',
      );
    }
    final rows = decoded['data'];
    if (rows is! List || rows.isEmpty) {
      throw const FormatException('OKX ticker data must contain one row.');
    }
    return _parseTicker(rows.first, instId: instId);
  }
}

/// Injected in tests to keep parsing and HTTP behaviour independently tested.
typedef OkxGetRequest = Future<OkxHttpResponse> Function(Uri uri);

final class OkxHttpResponse {
  const OkxHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// Immutable subset of the OKX public ticker payload rendered by the demo.
final class OkxTicker {
  const OkxTicker({
    required this.instId,
    required this.last,
    required this.open24h,
    required this.high24h,
    required this.low24h,
    required this.baseVolume24h,
    required this.quoteVolume24h,
  });

  final String instId;
  final double last;
  final double open24h;
  final double high24h;
  final double low24h;
  final double baseVolume24h;
  final double quoteVolume24h;

  double get change24h => last - open24h;

  double get changePercent24h => open24h == 0 ? 0 : change24h / open24h * 100;
}

Future<OkxHttpResponse> _defaultGet(Uri uri) async {
  final response = await http.get(uri);
  return OkxHttpResponse(statusCode: response.statusCode, body: response.body);
}

Kline _parseCandle(
  Object? row, {
  required String instId,
  required KlineInterval interval,
}) {
  if (row is! List || row.length < 9) {
    throw const FormatException('OKX candle must contain nine fields.');
  }
  int integer(int index) => int.parse(row[index].toString());
  double number(int index) {
    final value = double.parse(row[index].toString());
    if (!value.isFinite) {
      throw const FormatException('OKX candle has a non-finite number.');
    }
    return value;
  }

  final openTime = integer(0);
  final open = number(1);
  final high = number(2);
  final low = number(3);
  final close = number(4);
  final baseVolume = number(5);
  final quoteVolume = number(7);
  final closeTime = openTime + (interval.duration?.inMilliseconds ?? 1) - 1;
  return Kline(
    symbol: instId,
    interval: interval,
    openTime: openTime,
    closeTime: closeTime,
    open: open,
    high: high,
    low: low,
    close: close,
    baseVolume: baseVolume,
    quoteVolume: quoteVolume,
    tradeCount: 0,
    isClosed: row[8].toString() == '1',
  );
}

OkxTicker _parseTicker(Object? row, {required String instId}) {
  if (row is! Map) {
    throw const FormatException('OKX ticker must be an object.');
  }
  double number(String key) {
    final raw = row[key];
    if (raw == null) {
      throw FormatException('OKX ticker is missing $key.');
    }
    final value = double.tryParse(raw.toString());
    if (value == null || !value.isFinite) {
      throw FormatException('OKX ticker has an invalid $key.');
    }
    return value;
  }

  return OkxTicker(
    instId: instId,
    last: number('last'),
    open24h: number('open24h'),
    high24h: number('high24h'),
    low24h: number('low24h'),
    baseVolume24h: number('vol24h'),
    quoteVolume24h: number('volCcy24h'),
  );
}

String _okxBar(KlineInterval interval) => switch (interval.code) {
      '1h' => '1H',
      '2h' => '2H',
      '4h' => '4H',
      '6h' => '6H',
      '12h' => '12H',
      '1d' => '1D',
      '3d' => '3D',
      '1w' => '1W',
      _ => interval.code,
    };
