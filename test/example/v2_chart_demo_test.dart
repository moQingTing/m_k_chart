import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    expect(find.byKey(const ValueKey('market-summary')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('market-summary-last-price')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('open-fullscreen-demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('close-fullscreen-demo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-fullscreen-demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-fullscreen-demo')), findsOneWidget);

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
    for (final id in ['avl', 'super']) {
      await tester.tap(find.byKey(ValueKey('main-indicator-$id')));
      await tester.pump();
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(ValueKey('main-indicator-$id')),
            )
            .selected,
        isTrue,
      );
    }
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
    final tradeOverlays = find.byKey(
      const ValueKey('trade-overlay-examples'),
    );
    await tester.scrollUntilVisible(
      tradeOverlays,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilterChip>(tradeOverlays).selected, isTrue);
    expect(
      find.byKey(const ValueKey('trade-overlay-example-labels')),
      findsOneWidget,
    );
    await tester.tap(tradeOverlays);
    await tester.pump();
    expect(tester.widget<FilterChip>(tradeOverlays).selected, isFalse);
    await tester.tap(tradeOverlays);
    await tester.pump();
    expect(tester.widget<FilterChip>(tradeOverlays).selected, isTrue);
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
    expect(
      find.textContaining('SUPERTREND(10,3)', findRichText: true),
      findsOneWidget,
    );
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

  testWidgets('trade overlay supports exclusive tap drag and cancel actions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

    final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
    await tester.scrollUntilVisible(
      chartCanvas,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final chartTopLeft = tester.getTopLeft(chartCanvas);
    final chartSize = tester.getSize(chartCanvas);
    Offset? overlayPosition;
    for (var localY = 22.0; localY < 300; localY += 6) {
      final candidate = chartTopLeft + Offset(chartSize.width * 0.45, localY);
      await tester.tapAt(candidate);
      await tester.pump();
      if (find
          .byKey(const ValueKey('trade-overlay-actions'))
          .evaluate()
          .isNotEmpty) {
        overlayPosition = candidate;
        break;
      }
    }

    expect(overlayPosition, isNotNull);
    expect(find.byKey(const ValueKey('trade-overlay-actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    await tester.dragFrom(overlayPosition!, const Offset(0, 36));
    await tester.pump();
    expect(find.byKey(const ValueKey('trade-overlay-actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('trade-overlay-action-cancel')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('trade-overlay-actions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'supports RTL large text minute timezone and localized chart semantics',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: V2TradingChartDemo(loadOnStart: false),
            ),
          ),
        ),
      );

      final timeZone = find.byKey(const ValueKey('time-zone-offset'));
      await tester.scrollUntilVisible(
        timeZone,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      final dropdown = tester.widget<DropdownButton<int>>(timeZone);
      dropdown.onChanged!(5 * 60 + 30);
      await tester.pump();
      expect(tester.widget<DropdownButton<int>>(timeZone).value, 330);

      final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
      await tester.scrollUntilVisible(
        chartCanvas,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final chartSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.startsWith('V2 图表') ?? false),
      );
      final semantics = tester.getSemantics(chartSemantics).getSemanticsData();
      expect(semantics.label, startsWith('V2 图表 1m 蜡烛图'));
      expect(semantics.textDirection, TextDirection.rtl);
      expect(semantics.value, contains('最新'));
      expect(semantics.hasAction(SemanticsAction.increase), isTrue);
      expect(semantics.hasAction(SemanticsAction.decrease), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semanticsHandle.dispose();
    }
  });
}
