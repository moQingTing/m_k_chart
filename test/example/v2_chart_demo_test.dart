import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/v2_chart_demo.dart';

void main() {
  testWidgets('V2 example switches periods and all chart modes offline',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo()),
    );

    expect(find.byKey(const ValueKey('v2-chart-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('period-1m')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-candlestick')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('period-5m')));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('period-5m')))
          .selected,
      isTrue,
    );
    expect(find.bySemanticsLabel('V2 chart 5m Candle'), findsOneWidget);

    for (final mode in [
      ('hollowCandlestick', 'Hollow'),
      ('ohlc', 'OHLC'),
      ('heikinAshi', 'Heikin-Ashi'),
      ('line', 'Line'),
      ('area', 'Area'),
    ]) {
      await tester.tap(find.byKey(ValueKey('mode-${mode.$1}')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(ValueKey('mode-${mode.$1}')),
            )
            .selected,
        isTrue,
      );
      expect(find.bySemanticsLabel('V2 chart 5m ${mode.$2}'), findsOneWidget);
    }
  });
}
