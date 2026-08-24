import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'package:m_k_chart_example/main.dart';

void main() {
  testWidgets('loads chart data when the demo opens', (tester) async {
    var requestCount = 0;

    Future<void> loadChartData(
      String symbol,
      String timeType,
      int size,
      void Function(bool success, List<KLineEntity> data) callback,
    ) async {
      requestCount++;
      expect(symbol, 'BTC-USDT');
      expect(timeType, '1m');
      expect(size, 100);
      callback(false, <KLineEntity>[]);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ExamplePage(chartDataLoader: loadChartData),
      ),
    );
    await tester.pump();

    expect(requestCount, 1);
    expect(find.text('获取数据失败，请检查网络连接'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
