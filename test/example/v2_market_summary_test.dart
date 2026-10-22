import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/v2_example_support.dart';

// 示例组件不属于 SDK 的正式公开入口，测试直接引用示例目录。
// ignore: avoid_relative_lib_imports
import '../../example/lib/binance_market_data_client.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/widgets/v2_market_summary.dart';
import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(2);

  Future<void> showSummary(
    WidgetTester tester, {
    required List<Kline> values,
    BinanceTicker? ticker,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2MarketSummary(
            key: const ValueKey('market-summary'),
            instrumentId: 'BTCUSDT',
            ticker: ticker,
            candles: values,
            priceFormatter: (value) => value.toStringAsFixed(2),
          ),
        ),
      ),
    );
  }

  testWidgets('优先使用交易所 24 小时数据，且保留 Demo 的查询 key', (tester) async {
    await showSummary(
      tester,
      values: candles,
      ticker: const BinanceTicker(
        symbol: 'BTCUSDT',
        last: 1000,
        open24h: 990,
        high24h: 1010,
        low24h: 980,
        baseVolume24h: 100,
        quoteVolume24h: 100000,
      ),
    );

    expect(find.byKey(const ValueKey('market-summary')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('market-summary-last-price')),
      findsOneWidget,
    );
    expect(find.text('1000.00'), findsOneWidget);
    expect(find.text('+1.01%'), findsOneWidget);
    expect(find.text('Binance 24h'), findsOneWidget);
    final metrics = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .toList();
    expect(metrics, contains('24h 最高 1010.00'));
    expect(metrics, contains('成交额 100.00K USDT'));
  });

  testWidgets('离线时回退到 K 线窗口，空窗口不展示摘要', (tester) async {
    await showSummary(tester, values: candles);
    expect(find.text('K 线估算'), findsOneWidget);
    expect(find.text(candles.last.close.toStringAsFixed(2)), findsOneWidget);
    final metrics = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .toList();
    expect(
      metrics,
      contains('24h 最高 ${candles.last.high.toStringAsFixed(2)}'),
    );
    expect(
      metrics,
      contains('24h 最低 ${candles.first.low.toStringAsFixed(2)}'),
    );
    expect(metrics, contains('成交量 1.65K'));

    await showSummary(tester, values: const <Kline>[]);
    expect(find.text('K 线估算'), findsNothing);
    expect(
      find.byKey(const ValueKey('market-summary-last-price')),
      findsNothing,
    );
  });
}
