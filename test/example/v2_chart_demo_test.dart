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
    expect(
      find.byKey(const ValueKey('right-axis-width-setting')),
      findsOneWidget,
    );

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

    await tester.ensureVisible(chartCanvas);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(chartCanvas) + const Offset(100, 80));
    await tester.pump();
    expect(find.byKey(const ValueKey('crosshair-details')), findsOneWidget);
    expect(find.textContaining('横坐标：'), findsOneWidget);
    expect(find.textContaining('纵坐标：'), findsOneWidget);

    await tester.drag(chartCanvas, const Offset(90, 0));
    await tester.pump();
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
