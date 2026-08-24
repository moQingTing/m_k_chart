import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'package:m_k_chart/src/adapter/adapter.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  testWidgets('immutable Klines can drive the legacy demo through adapter', (
    tester,
  ) async {
    final adapter = KLineEntityAdapter(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
    );
    final legacy =
        buildV2KlineFixture(200).map(adapter.toLegacy).toList(growable: false);
    final style = ChartStyle();
    DataUtil.calculate(legacy, chartStyle: style);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 600,
          child: KChartWidget(
            legacy,
            chartStyle: style,
            secondaryStates: const [],
            chartColors: ChartColors(
              isDarkMode: true,
              upColor: Colors.green,
              downColor: Colors.red,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(KChartWidget), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
