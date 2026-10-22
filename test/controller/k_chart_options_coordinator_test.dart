import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/renderer/legacy_chart_viewport.dart';
import 'package:m_k_chart/src/controller/k_chart_data_contract.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/controller/k_chart_history_contract.dart';
import 'package:m_k_chart/src/controller/k_chart_indicator_binding.dart';
import 'package:m_k_chart/src/controller/k_chart_options.dart';
import 'package:m_k_chart/src/controller/k_chart_options_geometry.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(200);
  final series = KlineSeries.fromKline(candles.first);
  final binding = KChartIndicatorBinding(
    panelId: 'main',
    config: IndicatorConfig(
      instanceId: 'cci',
      definitionId: CciIndicatorDefinition.definitionId,
    ),
  );

  KChartDataCoordinator create({
    KChartOptions? options,
    List<Kline>? data,
    double width = 480,
    KChartHistoryLoader? loader,
  }) {
    final chart = KChartDataCoordinator(
      series: series,
      initialData: data ?? candles,
      options: options ?? KChartOptions(indicators: [binding]),
      historyLoader: loader,
    );
    addTearDown(chart.dispose);
    chart.setViewportSize(width);
    return chart;
  }

  void select(KChartDataCoordinator chart, {String panel = 'main'}) {
    chart.select(openTime: candles[150].openTime, panelId: panel, price: 1000);
  }

  double xOf(KChartDataCoordinator chart, int index) => ChartXTransform(
        viewport: chart.value.viewport,
        data: chart.value.data,
      ).timeToLocalX(candles[index].openTime);

  test('默认留白逐项对照旧版，包含空窗口、短数据、窄屏和缩放上下限', () {
    final options = KChartViewportOptions();
    for (final count in [0, 1, 5, 39, 40, 41, 90, 200]) {
      for (final width in [0.0, 1.0, 32.0, 320.0, 480.0, 1200.0]) {
        for (final extent in [0.5, 2.0, 3.3, 8.0, 20.0, 40.0, 100.0]) {
          final viewport = options.resolveViewport(
            ChartViewport(
              itemCount: count,
              width: width,
              itemExtent: extent,
            ),
          );
          final legacy = LegacyChartViewportMetrics(
            itemCount: count,
            width: width,
            scaleX: viewport.itemExtent / 8,
            pointWidth: 8,
          );
          expect(
            viewport.trailingPaddingItems,
            closeTo(legacy.trailingPaddingItems, 1e-9),
            reason: 'count=$count width=$width extent=$extent',
          );
          expect(viewport.width, width);
          expect(viewport.itemExtent, extent.clamp(2, 40));
        }
      }
    }
  });

  test('未来边界允许最新蜡烛到最左侧，关闭后只保留默认虚拟留白', () {
    final chart = create();
    final initial = chart.value.viewport;
    chart.applyViewport(initial.copyWith(scrollOffsetItems: -9999));
    expect(xOf(chart, 199), closeTo(initial.itemExtent / 2, 1e-9));
    chart.setOptions(
      chart.value.options.copyWith(
        viewport:
            chart.value.options.viewport.copyWith(allowLatestAtLeft: false),
      ),
    );
    expect(chart.value.viewport.futurePaddingItems, 0);
    expect(chart.value.viewport.scrollOffsetItems, 0);
    expect(
      chart.value.viewport.trailingPaddingItems,
      initial.trailingPaddingItems,
    );
  });

  test('首次非零布局适配根数，重排和再次显示保留用户缩放', () {
    final chart = create(width: 0);
    expect(chart.value.viewport.width, 0);
    chart.setViewportSize(450);
    expect(chart.value.viewport.itemExtent, 5);
    chart.applyViewport(
      chart.value.viewport.copyWith(itemExtent: 10),
      source: ChartViewportChangeSource.scale,
    );
    chart.setViewportSize(600);
    expect(chart.value.viewport.itemExtent, 10);
    chart.setViewportSize(0);
    chart.setViewportSize(450);
    expect(chart.value.viewport.itemExtent, 10);
    chart.resetViewport();
    expect(chart.value.viewport.itemExtent, 5);
    chart.setViewportSize(0);
    chart.resetViewport();
    chart.setViewportSize(720);
    expect(chart.value.viewport.itemExtent, 8);
  });

  test('布局配置不移动、不取消选中、不重算，并跳过相等配置', () {
    final chart = create();
    chart.applyViewport(
      chart.value.viewport.copyWith(scrollOffsetItems: 40.125),
    );
    select(chart);
    final before = chart.value;
    var calls = 0;
    chart.addListener(() => calls++);
    final options = before.options.copyWith(
      mainMode: ChartMainMode.line,
      mainPanel: before.options.mainPanel.copyWith(headerHeight: 28),
      mainTimeAxisHeight: 22,
      timeZoneOffset: Duration.zero,
    );
    chart.setOptions(options);
    expect(calls, 1);
    expect(chart.value.options, same(options));
    expect(chart.value.viewport, same(before.viewport));
    expect(chart.value.selection, same(before.selection));
    expect(chart.value.data, same(before.data));
    expect(chart.value.indicatorBatch, same(before.indicatorBatch));
    expect(chart.session, same(before.session));
    final after = chart.value;
    chart.setOptions(options.copyWith());
    chart.setViewportSize(after.viewport.width);
    expect(chart.value, same(after));
    expect(calls, 1);
    expect(before.options.mainPanel.headerHeight, 18);
  });

  test('改变留白和宽度保留历史时间像素位置，最新态继续跟随', () {
    for (final offset in [0.0, 40.125, -12.25]) {
      final chart = create();
      chart.applyViewport(
        chart.value.viewport.copyWith(scrollOffsetItems: offset),
      );
      select(chart);
      final x = xOf(chart, 150);
      final anchor = chart.value.selection;
      chart.setOptions(
        chart.value.options.copyWith(
          viewport:
              chart.value.options.viewport.copyWith(rightPaddingFraction: 0.3),
        ),
      );
      chart.setViewportSize(500);
      if (offset == 0) {
        expect(chart.value.viewport.isAtLatest, isTrue);
      } else {
        expect(xOf(chart, 150), closeTo(x, 1e-8));
      }
      expect(chart.value.selection, same(anchor));
    }
  });

  test('根数改变重新适配，缩放限制及时生效，切换会话按当前配置重置', () {
    final chart = create();
    select(chart);
    chart.setOptions(
      chart.value.options.copyWith(
        viewport: KChartViewportOptions(initialVisibleCandles: 40),
      ),
    );
    expect(chart.value.viewport.itemExtent, 12);
    expect(chart.value.selection, isNotNull);
    chart.setOptions(
      chart.value.options.copyWith(
        viewport: chart.value.options.viewport.copyWith(maxItemExtent: 6),
      ),
    );
    expect(chart.value.viewport.itemExtent, 6);
    chart.applyViewport(chart.value.viewport.copyWith(itemExtent: 3));
    chart.beginSeries(series, initialData: candles);
    expect(chart.value.viewport.itemExtent, 6);
    expect(chart.value.selection, isNull);
    expect(chart.value.viewport.isAtLatest, isTrue);
  });

  test('真实缩放意图应用新留白后仍保留手指下的数据焦点', () {
    final chart = create();
    chart.applyViewport(chart.value.viewport.scrollByItems(40));
    select(chart);
    final selection = chart.value.selection;
    final before = chart.value.viewport;
    const focalX = 240.0;
    final dataPosition =
        before.visibleLeftDataPosition + focalX / before.itemExtent;
    final machine = ChartInteractionMachine();
    machine.beginScale(viewport: before, focalLocalX: focalX);
    final intent = machine.updateScale(scale: 1.5, focalLocalX: focalX)!;
    chart.applyViewport(intent.viewport, source: intent.source);
    final after = chart.value.viewport;
    expect(
      (dataPosition - after.visibleLeftDataPosition) * after.itemExtent,
      closeTo(focalX, 1e-8),
    );
    expect(chart.value.selection, same(selection));
    expect(after.trailingPaddingItems, isNot(before.trailingPaddingItems));
  });

  test('未布局时修改根数，定位命令在首屏适配后执行', () {
    final chart = create(width: 0);
    chart.scrollToTime(
      epochMilliseconds: candles[100].openTime,
      alignment: 0.5,
    );
    chart.setOptions(
      chart.value.options.copyWith(
        viewport: KChartViewportOptions(initialVisibleCandles: 60),
      ),
    );
    chart.setViewportSize(480);
    expect(chart.value.viewport.itemExtent, 8);
    expect(xOf(chart, 100), closeTo(240, 1e-8));
  });

  test('实时尾部替换、追加、前插、裁剪均保留选中与历史锚', () {
    final chart = create(data: candles.sublist(20));
    chart
        .applyViewport(chart.value.viewport.copyWith(scrollOffsetItems: 30.25));
    select(chart);
    final x = xOf(chart, 150);
    final selection = chart.value.selection;
    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: chart.session,
    );
    chart.appendData(
      buildV2KlineFixture(1, startIndex: 200),
      session: chart.session,
    );
    chart.prependHistory(candles.sublist(0, 20), session: chart.session);
    chart.replaceData(candles.sublist(10), session: chart.session);
    expect(xOf(chart, 150), closeTo(x, 1e-8));
    expect(chart.value.selection, same(selection));
    expect(chart.value.selectedIndex, 140);
  });

  test('短窗口追加实时重算右留白，空窗口和权威重置不遗留旧边界', () {
    final chart = create(data: candles.sublist(0, 2));
    expect(xOf(chart, 0), closeTo(chart.value.viewport.itemExtent / 2, 1e-8));
    chart.appendData(candles.sublist(2), session: chart.session);
    final expected = create().value.viewport;
    expect(chart.value.viewport, expected);
    chart.replaceData(const [], session: chart.session);
    expect(chart.value.viewport.trailingPaddingItems, 0);
    expect(chart.value.viewport.futurePaddingItems, 0);
    chart.replaceData(
      candles,
      session: chart.session,
      viewportPolicy: KChartDataViewportPolicy.resetToLatest,
    );
    expect(chart.value.viewport, expected);
  });

  test('面板、指标、失效选中、配置只发布一次，旧适配入口不丢面板设置', () {
    final panel = KChartSecondaryPanelOptions(
      id: 'sub',
      layout: KChartPanelOptions(headerHeight: 31),
    );
    final chart = create(
      options: KChartOptions(
        secondaryPanels: [panel],
        indicators: [binding.copyWith(panelId: 'sub')],
      ),
    );
    select(chart, panel: 'sub');
    chart.setPanels(['sub', 'main']);
    expect(chart.value.options.secondaryPanels.single, same(panel));
    chart.setIndicators([binding.copyWith(panelId: 'sub')]);
    expect(chart.value.options.secondaryPanels.single, same(panel));
    var calls = 0;
    chart.addListener(() {
      calls++;
      expect(chart.value.panelIds, ['main']);
      expect(chart.value.indicators, isEmpty);
      expect(chart.value.indicatorBatch.results, isEmpty);
      expect(chart.value.selection, isNull);
      expect(chart.value.options.secondaryPanels, isEmpty);
    });
    chart.setOptions(
      chart.value.options.copyWith(secondaryPanels: [], indicators: []),
    );
    expect(calls, 1);
  });

  test('非法配置及混用构造参数拒绝，旧入口移交后持续采用新策略', () {
    expect(
      () => KChartDataCoordinator(
        series: series,
        options: KChartOptions(),
        maxOutOfOrderCandles: 2,
      ),
      throwsArgumentError,
    );
    final chart = KChartDataCoordinator(
      series: series,
      initialData: candles,
      initialViewport: ChartViewport(width: 480, itemExtent: 8),
    );
    addTearDown(chart.dispose);
    select(chart);
    final before = chart.value;
    expect(() => chart.setViewportSize(double.nan), throwsArgumentError);
    expect(
      () => chart.setOptions(KChartOptions(gridColumns: 0)),
      throwsArgumentError,
    );
    expect(chart.value, same(before));
    chart.setOptions(chart.value.options);
    expect(chart.value.selection, same(before.selection));
    expect(chart.value.viewport.trailingPaddingItems, greaterThan(0));
    chart.replaceData(candles.sublist(0, 3), session: chart.session);
    expect(xOf(chart, 0), closeTo(4, 1e-8));
  });

  test('setOptions 同时发布新参数和计算结果，缩放保留选中而平移取消', () {
    final chart = create();
    select(chart);
    final before = chart.value;
    final changed = binding.copyWith(
      config: IndicatorConfig(
        instanceId: binding.config.instanceId,
        definitionId: binding.config.definitionId,
        parameters: const {'period': 6},
      ),
    );
    var calls = 0;
    chart.addListener(() => calls++);
    chart.setOptions(chart.value.options.copyWith(indicators: [changed]));
    expect(calls, 1);
    expect(chart.value.indicators, [changed]);
    expect(chart.value.indicatorBatch.failures, isEmpty);
    expect(chart.value.indicatorBatch, isNot(same(before.indicatorBatch)));
    expect(chart.value.data, same(before.data));
    expect(chart.value.selection, same(before.selection));
    chart.applyViewport(
      chart.value.viewport.copyWith(itemExtent: 8),
      source: ChartViewportChangeSource.scale,
    );
    expect(chart.value.selection, same(before.selection));
    chart.applyViewport(
      chart.value.viewport.scrollByItems(1),
      source: ChartViewportChangeSource.pan,
    );
    expect(chart.value.selection, isNull);
  });

  test('修改乱序窗口不换会话，下一条事件使用新限制', () {
    final chart = create(
      data: [candles[0], candles[2], candles[3]],
      options: KChartOptions(maxOutOfOrderCandles: 0),
    );
    final token = chart.session;
    expect(
      chart.updateKline(candles[1], session: token).status,
      KChartDataUpdateStatus.rejectedOutsideWindow,
    );
    chart.setOptions(chart.value.options.copyWith(maxOutOfOrderCandles: 2));
    expect(chart.session, same(token));
    expect(chart.updateKline(candles[1], session: token).changed, isTrue);
  });

  test('调整预加载阈值启动检查，修改布局不废弃在途历史', () async {
    final pending = Completer<KChartHistoryPage>();
    var calls = 0;
    final chart = create(
      loader: (_) {
        calls++;
        return pending.future;
      },
    );
    chart.attach(Object());
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
    chart.setOptions(chart.value.options.copyWith(historyThresholdItems: 1000));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(chart.value.history.phase, KChartHistoryPhase.loading);
    final request = chart.value.history.request;
    chart.setOptions(chart.value.options.copyWith(mainTimeAxisHeight: 24));
    expect(chart.value.history.request, same(request));
    pending.complete(KChartHistoryPage(candles: [], hasMore: false));
    await Future<void>.delayed(Duration.zero);
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
    expect(calls, 1);
  });

  test('监听器重入收到完整配置状态，销毁后新命令拒绝', () {
    final chart = create();
    var calls = 0;
    chart.addListener(() {
      calls++;
      expect(chart.value.panelIds, [
        'main',
        ...chart.value.options.secondaryPanels.map((panel) => panel.id),
      ]);
      expect(chart.value.indicators, chart.value.options.indicators);
      if (calls == 1) {
        chart.setOptions(chart.value.options.copyWith(gridColumns: 4));
      }
    });
    chart.setOptions(chart.value.options.copyWith(gridColumns: 3));
    expect(calls, 2);
    expect(chart.value.options.gridColumns, 4);
    final options = chart.value.options;
    chart.dispose();
    expect(() => chart.setOptions(options), throwsStateError);
    expect(() => chart.setViewportSize(320), throwsStateError);
  });
}
