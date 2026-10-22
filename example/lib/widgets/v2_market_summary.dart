import 'package:flutter/material.dart';
import 'package:m_k_chart/v2_example_support.dart';

import '../market/v2_demo_market_data_source.dart';

/// 示例页的 24 小时行情摘要，与 K 线渲染及交互状态无关。
///
/// 有真实 ticker 时优先展示交易所的 24 小时统计；离线时从当前 K 线窗口估算。
/// 后者只是演示兜底值，不保证该窗口恰好覆盖 24 小时。
class V2MarketSummary extends StatelessWidget {
  const V2MarketSummary({
    super.key,
    required this.instrumentId,
    this.sourceLabel = 'Binance',
    required this.ticker,
    required this.candles,
    required this.priceFormatter,
  });

  final String instrumentId;
  final String sourceLabel;
  final V2MarketTicker? ticker;
  final List<Kline> candles;
  final String Function(double value) priceFormatter;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.shrink();
    final source = ticker;
    // 真实 24h ticker 已包含全部统计值，无需每次构建时重复遍历 K 线。
    // 离线兜底则只遍历一次，汇总最高、最低和成交量。
    final fallback = source == null ? _summarizeCandles(candles) : null;
    final latest = source?.last ?? candles.last.close;
    final opening = source?.open24h ?? candles.first.open;
    final high = source?.high24h ?? fallback!.high;
    final low = source?.low24h ?? fallback!.low;
    final baseVolume = source?.baseVolume24h ?? fallback!.baseVolume;
    final quoteVolume = source?.quoteVolume24h ?? fallback!.quoteVolume;
    final change = latest - opening;
    final changePercent = opening == 0 ? 0 : change / opening * 100;
    final positive = change >= 0;
    final changeColor =
        positive ? const Color(0xff059669) : const Color(0xffdc2626);
    final quote = _binanceQuoteAsset(instrumentId);

    return Semantics(
      label: '24 小时行情摘要',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffe2e8f0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceFormatter(latest),
                  key: const ValueKey('market-summary-last-price'),
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${positive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  source == null ? 'K 线估算' : '$sourceLabel 24h',
                  style:
                      const TextStyle(color: Color(0xff64748b), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _MarketSummaryMetric('24h 涨跌',
                    '${positive ? '+' : ''}${priceFormatter(change)}'),
                _MarketSummaryMetric('24h 最高', priceFormatter(high)),
                _MarketSummaryMetric('24h 最低', priceFormatter(low)),
                _MarketSummaryMetric('成交量', _compactMarketValue(baseVolume)),
                _MarketSummaryMetric(
                    '成交额', '${_compactMarketValue(quoteVolume)} $quote'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

_MarketWindowStats _summarizeCandles(List<Kline> candles) {
  var high = candles.first.high;
  var low = candles.first.low;
  var baseVolume = 0.0;
  var quoteVolume = 0.0;
  for (final candle in candles) {
    if (candle.high > high) high = candle.high;
    if (candle.low < low) low = candle.low;
    baseVolume += candle.baseVolume;
    quoteVolume += candle.quoteVolume;
  }
  return _MarketWindowStats(high, low, baseVolume, quoteVolume);
}

final class _MarketWindowStats {
  const _MarketWindowStats(
    this.high,
    this.low,
    this.baseVolume,
    this.quoteVolume,
  );

  final double high;
  final double low;
  final double baseVolume;
  final double quoteVolume;
}

class _MarketSummaryMetric extends StatelessWidget {
  const _MarketSummaryMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xff0f172a),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

String _compactMarketValue(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (absolute >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (absolute >= 1000) {
    return '${(value / 1000).toStringAsFixed(2)}K';
  }
  return value.toStringAsFixed(2);
}

String _binanceQuoteAsset(String symbol) {
  const knownQuotes = [
    'USDT',
    'USDC',
    'FDUSD',
    'BUSD',
    'BTC',
    'ETH',
    'BNB',
    'EUR',
    'TRY',
  ];
  return knownQuotes.firstWhere(
    symbol.endsWith,
    orElse: () => symbol.length > 3 ? symbol.substring(symbol.length - 3) : '',
  );
}
