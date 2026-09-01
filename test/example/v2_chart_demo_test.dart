import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The runnable demo is intentionally outside the package's public API.
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_chart_demo.dart';

void main() {
  testWidgets('V2 example switches periods and all chart modes offline',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

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

    for (final mode in [
      ('hollowCandlestick', '空心蜡烛'),
      ('ohlc', 'OHLC'),
      ('heikinAshi', '平均 K 线'),
      ('line', '折线图'),
      ('area', '面积图'),
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
    }

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main-indicator-boll')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('main-indicator-boll')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('main-indicator-boll')),
          )
          .selected,
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('secondary-indicator-rsi')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('secondary-indicator-rsi')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('secondary-indicator-rsi')),
          )
          .selected,
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.byType(Switch),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main-header-height-setting')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('main-header-height-setting')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('secondary-header-height-setting')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('main-time-axis-height-setting')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main-value-decimals')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final mainDecimals = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('main-value-decimals')),
    );
    mainDecimals.onChanged!(4);
    await tester.pump();
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const ValueKey('main-value-decimals')),
          )
          .value,
      4,
    );
    final secondaryThousands = find.byKey(
      const ValueKey('secondary-value-thousands'),
    );
    expect(tester.widget<FilterChip>(secondaryThousands).selected, isTrue);
    await tester.tap(secondaryThousands);
    await tester.pump();
    expect(tester.widget<FilterChip>(secondaryThousands).selected, isFalse);
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('panel-indicator-legend-main')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('panel-indicator-legend-secondary-overlay')),
      findsOneWidget,
    );
    final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
    expect(chartCanvas, findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 420));
    await tester.pumpAndSettle();
    final simulateUpdate = find.byKey(
      const ValueKey('simulate-update-latest'),
      skipOffstage: false,
    );
    await tester.ensureVisible(simulateUpdate);
    await tester.pump();
    await tester.tap(simulateUpdate);
    await tester.pump();
    expect(find.textContaining('已模拟更新最新 K 线'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(
        const ValueKey('simulate-append-latest'),
        skipOffstage: false,
      ),
    );
    await tester.pump();
    expect(find.textContaining('已模拟新增 K 线'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(chartCanvas);
    await tester.pump();
    final chartTopLeft = tester.getTopLeft(chartCanvas);
    final chartSize = tester.getSize(chartCanvas);
    await tester.tapAt(chartTopLeft + const Offset(100, 80));
    await tester.pump();
    expect(find.byKey(const ValueKey('crosshair-details')), findsOneWidget);
    expect(find.byKey(const ValueKey('crosshair-time-label')), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('命中值'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('crosshair-details'))).dx,
      greaterThan(chartTopLeft.dx + chartSize.width / 2),
    );

    await tester.tapAt(
      chartTopLeft + Offset(chartSize.width * 0.7, 80),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('crosshair-details'))).dx,
      lessThan(chartTopLeft.dx + chartSize.width / 2),
    );

    await tester.drag(chartCanvas, const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    final latestPriceReturn = find.byKey(const ValueKey('latest-price-return'));
    expect(latestPriceReturn, findsOneWidget);
    await tester.tap(latestPriceReturn);
    await tester.pump();
    expect(latestPriceReturn, findsNothing);
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    final center = tester.getCenter(chartCanvas);
    final first = await tester.startGesture(center + const Offset(-40, 0));
    final second = await tester.startGesture(center + const Offset(40, 0));
    await first.moveTo(center + const Offset(-70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
