import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/widget/chart_gesture_region.dart';

// 示例不属于正式 SDK 公共 API；通过真实按钮和指针事件验证，不调用私有 State。
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_chart_demo.dart';

final _canvas = find.byKey(const ValueKey('v2-chart-canvas'));
final _timeLabel = find.byKey(
  const ValueKey('crosshair-time-label'),
  skipOffstage: false,
);

Future<void> _mount(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
  );
  // 这些用例聚焦数据选中，关闭交易覆盖物，避免测试坐标命中订单按钮。
  await tester.tap(find.byKey(const ValueKey('open-chart-settings')));
  await tester.pumpAndSettle();
  await _scrollTo(tester, find.byKey(const ValueKey('trade-overlay-examples')));
  await tester.tap(find.byKey(const ValueKey('trade-overlay-examples')));
  await tester.pump();
  await _closeSettings(tester);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    400,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('settings-sheet-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

Future<void> _closeSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('关闭'));
  await tester.pumpAndSettle();
}

String _selectedTime(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: _timeLabel, matching: find.byType(Text)))
    .data!;

Future<void> _select(WidgetTester tester, {String panel = 'main'}) async {
  final legend = find.byKey(ValueKey('panel-indicator-legend-$panel'));
  final point = tester.getTopLeft(legend) + const Offset(120, 50);
  await tester.tapAt(point);
  await tester.pump();
  expect(_timeLabel, findsOneWidget);
}

Future<void> _openIndicators(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-indicator-settings')));
  await tester.pumpAndSettle();
}

Future<void> _toggle(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('secondary-indicator-$id')));
  await tester.pump();
}

Future<void> _toggleOverlay(WidgetTester tester) async {
  final toggle = find.widgetWithText(SwitchListTile, '副图指标叠加到同一面板');
  await _scrollTo(tester, toggle);
  await tester.tap(toggle);
  await tester.pump();
}

void main() {
  testWidgets(
      'zooming selection outside viewport keeps identity and clamps label',
      (tester) async {
    await _mount(tester);
    await _select(tester);
    final time = _selectedTime(tester);
    final bounds = tester.getRect(_canvas);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: Offset(bounds.right - 40, bounds.top + 50),
        scrollDelta: const Offset(0, -750),
      ),
    );
    await tester.pump();
    expect(_selectedTime(tester), time);
    expect(tester.getRect(_timeLabel).left, closeTo(bounds.left, 0.01));
  });

  testWidgets('first touch drag clears selected data', (tester) async {
    await _mount(tester);
    await _select(tester);
    final start = tester.getTopLeft(_canvas) + const Offset(120, 50);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(_timeLabel, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('reordering secondary panels preserves selection identity',
      (tester) async {
    await _mount(tester);
    await _select(tester, panel: 'secondary-vol');
    final time = _selectedTime(tester);
    await _openIndicators(tester);
    final down = find.byTooltip('下移 VOL 面板');
    await _scrollTo(tester, down);
    await tester.tap(down);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_selectedTime(tester), time);
  });

  testWidgets(
      'shared panel selection lasts until its last indicator is removed',
      (tester) async {
    await _mount(tester);
    await _openIndicators(tester);
    await _toggleOverlay(tester);
    await _closeSettings(tester);
    await _select(tester, panel: 'secondary-overlay');
    final time = _selectedTime(tester);
    await _openIndicators(tester);
    await _toggle(tester, 'vol');
    expect(_selectedTime(tester), time);
    await _toggle(tester, 'macd');
    expect(tester.takeException(), isNull);
    expect(_timeLabel, findsNothing);
  });

  testWidgets('splitting the selected shared panel clears its old identity',
      (tester) async {
    await _mount(tester);
    await _openIndicators(tester);
    await _toggleOverlay(tester);
    await _closeSettings(tester);
    await _select(tester, panel: 'secondary-overlay');
    await _openIndicators(tester);
    await _toggleOverlay(tester);
    expect(tester.takeException(), isNull);
    expect(_timeLabel, findsNothing);
  });

  testWidgets('instrument changes clear selection before the network responds',
      (tester) async {
    await _mount(tester);
    await _select(tester);
    await tester.tap(find.byKey(const ValueKey('open-data-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('instrument-input')),
      'ETHUSDT',
    );
    await tester.tap(find.byKey(const ValueKey('load-instrument')));
    await tester.pump();
    expect(_timeLabel, findsNothing);
  });

  for (final panel in ['main', 'secondary-vol']) {
    testWidgets('realtime updates and wheel zoom retain $panel identity',
        (tester) async {
      await _mount(tester);
      await _select(tester, panel: panel);
      final time = _selectedTime(tester);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getTopLeft(_canvas) + const Offset(120, 50),
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
      expect(_selectedTime(tester), time);
      await tester.tap(find.byKey(const ValueKey('open-simulation-settings')));
      await tester.pumpAndSettle();
      for (final action in [
        'simulate-update-latest',
        'simulate-append-latest',
      ]) {
        await tester.tap(find.byKey(ValueKey(action)));
        await tester.pump();
        expect(_selectedTime(tester), time);
        expect(
          find.byKey(
            const ValueKey('crosshair-details-position'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }
    });
  }

  testWidgets('removing unrelated panels preserves main selection',
      (tester) async {
    await _mount(tester);
    await _select(tester);
    final time = _selectedTime(tester);
    final semanticValue = tester
        .widget<ChartGestureRegion>(find.byType(ChartGestureRegion))
        .semantics!
        .value;
    await _openIndicators(tester);
    await _toggle(tester, 'vol');
    expect(_selectedTime(tester), time);
    await _toggle(tester, 'macd');
    expect(tester.takeException(), isNull);
    // 无副图时底部时间标签由 Canvas 绘制；不能用中间时间轴 Widget 判断选中状态。
    expect(
      tester
          .widget<ChartGestureRegion>(find.byType(ChartGestureRegion))
          .semantics!
          .value,
      semanticValue,
    );
    expect(
      find.byKey(
        const ValueKey('crosshair-details-position'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing the last secondary panel clears selection',
      (tester) async {
    await _mount(tester);
    await _select(tester, panel: 'secondary-vol');
    final time = _selectedTime(tester);
    await _openIndicators(tester);
    await _toggle(tester, 'macd');
    expect(_selectedTime(tester), time);
    await _toggle(tester, 'vol');
    expect(tester.takeException(), isNull);
    expect(_timeLabel, findsNothing);
  });

  testWidgets('period changes invalidate the selected data series',
      (tester) async {
    await _mount(tester);
    await _select(tester);
    await tester.tap(find.byKey(const ValueKey('open-data-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-1d')));
    await tester.pump();
    expect(_timeLabel, findsNothing);
  });

  testWidgets('first horizontal navigation clears selection before any zoom',
      (tester) async {
    await _mount(tester);
    await _select(tester, panel: 'secondary-vol');
    // 一次滚轮事件只产生一次平移意图，防止第二帧掩盖首次导航漏清理的问题。
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getTopLeft(_canvas) + const Offset(120, 50),
        scrollDelta: const Offset(-40, 0),
      ),
    );
    await tester.pump();
    expect(_timeLabel, findsNothing);
  });

  testWidgets('removing the selected secondary panel clears its selection',
      (tester) async {
    await _mount(tester);
    await _select(tester, panel: 'secondary-vol');
    await _openIndicators(tester);
    await _toggle(tester, 'vol');
    expect(tester.takeException(), isNull);
    expect(_timeLabel, findsNothing);
  });

  testWidgets('switching secondary layout invalidates the old panel identity',
      (tester) async {
    await _mount(tester);
    await _select(tester, panel: 'secondary-macd');
    await _openIndicators(tester);
    await _toggleOverlay(tester);
    expect(tester.takeException(), isNull);
    expect(_timeLabel, findsNothing);
  });
}
