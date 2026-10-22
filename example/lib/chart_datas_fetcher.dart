import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:m_k_chart/m_k_chart.dart';

/// Legacy Widget 示例使用的公开 Binance Spot K 线获取器。
///
/// 默认 V2 Demo 使用 BinanceMarketDataClient 进行实时增量轮询；这个保留类
/// 只为旧 ExamplePage 的回调式 API 演示提供同一个 Binance 数据源。
class ChartDatasFetcher {
  String apiURL = 'https://data-api.binance.vision/api/v3';

  ChartDatasFetcher._();

  static final ChartDatasFetcher shared = ChartDatasFetcher._();

  Future<void> getRemoteChartData(
    String symbol,
    String timeType,
    int size,
    Function(bool success, List<KLineEntity> data) callback, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!RegExp(r'^[A-Z0-9]{5,20}$').hasMatch(symbol)) {
      callback(false, []);
      return;
    }
    try {
      final url = Uri.parse('$apiURL/klines').replace(
        queryParameters: {
          'symbol': symbol,
          'interval': _binanceInterval(timeType),
          'limit': '${size.clamp(1, 1000)}',
        },
      );
      final response = await http.get(url).timeout(timeout);
      if (response.statusCode != 200) {
        callback(false, []);
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        callback(false, []);
        return;
      }
      final values = <KLineEntity>[
        for (final row in decoded)
          if (row is List)
            if (_parseKlineData(row) case final value?) value,
      ]..sort((left, right) => left.id.compareTo(right.id));
      callback(values.isNotEmpty, values);
    } on Object {
      callback(false, []);
    }
  }

  /// Binance K 线行：
  /// [openTime, open, high, low, close, volume, closeTime, quoteVolume,
  ///  tradeCount, takerBuyBaseVolume, takerBuyQuoteVolume, ignored]。
  KLineEntity? _parseKlineData(List<dynamic> values) {
    if (values.length < 9) return null;
    final timestamp = int.tryParse(values[0].toString());
    final open = _safeParseDouble(values[1]);
    final high = _safeParseDouble(values[2]);
    final low = _safeParseDouble(values[3]);
    final close = _safeParseDouble(values[4]);
    final volume = _safeParseDouble(values[5]);
    final amount = _safeParseDouble(values[7]);
    final count = int.tryParse(values[8].toString());
    if (timestamp == null ||
        count == null ||
        !open.isFinite ||
        !high.isFinite ||
        !low.isFinite ||
        !close.isFinite ||
        !volume.isFinite ||
        !amount.isFinite ||
        open <= 0 ||
        high <= 0 ||
        low <= 0 ||
        close <= 0 ||
        volume < 0 ||
        high < open ||
        high < close ||
        low > open ||
        low > close) {
      return null;
    }
    return KLineEntity()
      ..id = timestamp
      ..open = open
      ..close = close
      ..high = high
      ..low = low
      ..vol = volume
      ..amount = amount
      ..count = count;
  }

  double _safeParseDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? double.nan;
}

String _binanceInterval(String value) => switch (value.toLowerCase()) {
      '1h' => '1h',
      '4h' => '4h',
      '1d' => '1d',
      _ => value,
    };
