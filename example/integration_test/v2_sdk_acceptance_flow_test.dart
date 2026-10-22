import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
import 'package:m_k_chart/src/widget/k_chart_surface.dart';
import 'package:m_k_chart_example/v2_chart_demo.dart';
import 'package:m_k_chart_example/v2_sdk_acceptance_main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('新组件验收页在 iOS 模拟器完成增量更新和图表手势', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2SdkAcceptancePage()));
    await tester.pump(); // Surface 首帧提交布局，下一帧才允许命中。

    final surface = find.byType(KChartSurface);
    KChartController chart() =>
        tester.widget<KChartSurface>(surface).controller;
    expect(surface, findsOneWidget);
    expect(chart().value.data.length, 180);
    expect(chart().value.viewportInfo.hasLayout, isTrue);

    // 先暂停模拟时钟，避免手势断言受到周期刷新干扰；手动按钮仍可更新。
    await tester.tap(find.byKey(const ValueKey('acceptance-pause')));
    await tester.pump();
    ({int replaced, int appended}) updateCounts() {
      final status = tester.widget<Text>(
        find.byKey(const ValueKey('acceptance-status')),
      );
      final match = RegExp(r'替换 (\d+) 次 · 新增 (\d+) 根').firstMatch(status.data!);
      expect(match, isNotNull);
      return (
        replaced: int.parse(match!.group(1)!),
        appended: int.parse(match.group(2)!),
      );
    }

    final initialCounts = updateCounts();
    final chartRect = tester.getRect(surface);
    await tester.tapAt(chartRect.topLeft + const Offset(120, 120));
    await tester.pump();
    final selectedTime = chart().value.selection!.candle.openTime;
    expect(chart().value.selection!.panelId, 'main');

    await tester.tap(find.byKey(const ValueKey('acceptance-replace')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('acceptance-append')));
    await tester.pump();
    expect(chart().value.data.length, 181);
    expect(chart().value.selection!.candle.openTime, selectedTime);
    final updatedCounts = updateCounts();
    expect(updatedCounts.replaced, initialCounts.replaced + 1);
    expect(updatedCounts.appended, initialCounts.appended + 1);

    // 图表平移应隐藏信息面板，回到最新应恢复尾部定位。
    await tester.timedDrag(
      surface,
      const Offset(260, 0),
      const Duration(milliseconds: 650),
    );
    await tester.pump();
    expect(chart().value.selection, isNull);
    expect(chart().value.viewportInfo.isAtLatest, isFalse);
    await tester.tap(find.byTooltip('回到最新'));
    await tester.pump();
    expect(chart().value.viewportInfo.isAtLatest, isTrue);

    // 两个模拟触点检验双指缩放，无需接入实体手机。
    final beforeZoom = chart().value.viewportInfo.visibleStartTime;
    final middle = tester.getCenter(surface);
    final first = await tester.startGesture(middle + const Offset(-40, -40));
    final second = await tester.startGesture(middle + const Offset(40, -40));
    await tester.pump();
    await first.moveTo(middle + const Offset(-100, -40));
    await second.moveTo(middle + const Offset(100, -40));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(chart().value.viewportInfo.visibleStartTime, isNot(beforeZoom));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认 Demo 可进入候选图表并返回原有设置', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );
    await tester.tap(find.byKey(const ValueKey('open-sdk-candidate')));
    await tester.pumpAndSettle();
    expect(find.byType(KChartSurface), findsOneWidget);
    expect(find.byKey(const ValueKey('acceptance-append')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('acceptance-append')));
    await tester.pump();
    expect(find.textContaining('新增 1 根'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('open-indicator-settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('候选图表设置可切换样式及主副指标', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2SdkAcceptancePage()));
    await tester.pump();
    final chart =
        tester.widget<KChartSurface>(find.byType(KChartSurface)).controller;

    // 设置路径较长，先暂停 12 倍模拟时钟，避免新增柱影响参数验收断言。
    await tester.tap(find.byKey(const ValueKey('acceptance-pause')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('acceptance-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sdk-mode-line')));
    await tester.pump();
    expect(chart.value.options.mainMode, ChartMainMode.line);
    await tester.tap(find.byKey(const ValueKey('sdk-indicator-ma')));
    await tester.pump();
    expect(
      chart.value.options.indicators
          .any((binding) => binding.config.instanceId == 'ma'),
      isTrue,
    );
    final macd = find.byKey(const ValueKey('sdk-indicator-macd'));
    await tester.ensureVisible(macd);
    await tester.tap(macd);
    await tester.pump();
    expect(
      chart.value.options.secondaryPanels.map((panel) => panel.id),
      contains('secondary-macd'),
    );

    // 设置页从计算定义读取周期元数据；编辑后不换 Controller 或清空行情。
    final editEma = find.byKey(const ValueKey('sdk-edit-ema'));
    await tester.ensureVisible(editEma);
    await tester.tap(editEma);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-period1')),
      '9',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pumpAndSettle();
    expect(
      chart.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'ema')
          .config
          .parameter('period1'),
      9,
    );

    final editEmaSeries = find.byKey(const ValueKey('sdk-series-ema'));
    await tester.ensureVisible(editEmaSeries);
    await tester.tap(editEmaSeries);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sdk-series-option-ema10')));
    await tester.tap(find.byKey(const ValueKey('sdk-series-save')));
    await tester.pumpAndSettle();
    expect(
      chart.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'ema')
          .visibleSeriesIds,
      {'ema5', 'ema30'},
    );

    final sar = find.byKey(const ValueKey('sdk-indicator-sar'));
    await tester.ensureVisible(sar);
    await tester.tap(sar);
    await tester.pump();
    final editSar = find.byKey(const ValueKey('sdk-edit-sar'));
    await tester.ensureVisible(editSar);
    await tester.tap(editSar);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-afStart')),
      '0.3',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pump();
    expect(find.byKey(const ValueKey('sdk-param-group-error')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-afMax')),
      '0.4',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pumpAndSettle();
    expect(
      chart.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'sar')
          .config
          .parameter('afStart'),
      0.3,
    );
    final custom =
        find.byKey(const ValueKey('sdk-indicator-custom-example.typicalPrice'));
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pump();
    final editCustom =
        find.byKey(const ValueKey('sdk-edit-custom:example.typicalPrice'));
    await tester.ensureVisible(editCustom);
    await tester.tap(editCustom);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-scale')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pumpAndSettle();
    expect(
      chart.value.options.indicators
          .firstWhere(
            (item) => item.config.instanceId == 'custom:example.typicalPrice',
          )
          .config
          .parameter('scale'),
      2,
    );
    expect(chart.value.data.length, 180);
    expect(tester.takeException(), isNull);
  });
}
