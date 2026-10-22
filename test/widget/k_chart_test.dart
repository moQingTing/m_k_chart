import 'dart:ui' show SemanticsAction;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
import 'package:m_k_chart/src/widget/chart_gesture_region.dart';
import 'package:m_k_chart/src/widget/k_chart_overlays.dart';
import 'package:m_k_chart/src/widget/k_chart_surface.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(100);

  KChartController create({KChartOptions? options}) {
    final chart = KChartController(
      series: KlineSeries.fromKline(candles.first),
      initialData: candles,
      options: options,
    );
    addTearDown(chart.dispose);
    return chart;
  }

  Widget host(KChart child) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 480, height: 500, child: child),
      );

  Future<void> mount(WidgetTester tester, KChart child) async {
    await tester.pumpWidget(host(child));
    await tester.pump(); // Surface 延迟提交初始尺寸。
  }

  testWidgets('仓库候选入口可直接创建 Widget，选中回调帧后去重', (tester) async {
    final chart = create();
    final changes = <KChartSelection?>[];
    await mount(
      tester,
      KChart(
        controller: chart,
        onSelectionChanged: (selection) {
          expect(
            SchedulerBinding.instance.schedulerPhase,
            isNot(SchedulerPhase.persistentCallbacks),
          );
          changes.add(selection);
        },
      ),
    );
    expect(find.byType(KChartSurface), findsOneWidget);
    expect(changes, isEmpty);

    await tester.tapAt(const Offset(150, 180));
    await tester.pump();
    expect(changes.length, 1);
    expect(changes.single!.panelId, 'main');
    await mount(
      tester,
      KChart(controller: chart, onSelectionChanged: changes.add),
    );
    expect(changes.length, 1, reason: '宿主重建并更换回调函数不构成新的选中事件');
    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 1),
      session: chart.session,
    );
    await tester.pump();
    expect(changes.length, 1, reason: '更新未选中的尾柱不应重复通知选中');
    chart.clearSelection();
    await tester.pump();
    expect(changes.length, 2);
    expect(changes.last, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(chart.isDisposed, isFalse, reason: 'Controller 的销毁权属于宿主');
  });

  testWidgets('同一错误只回调一次，清除后再次出现可重新通知', (tester) async {
    final broken = KChartIndicatorBinding(
      panelId: 'main',
      config: IndicatorConfig(instanceId: 'bad', definitionId: 'missing'),
    );
    final chart = create(options: KChartOptions(indicators: [broken]));
    final issues = <KChartIssue>[];
    await mount(tester, KChart(controller: chart, onIssue: issues.add));
    expect(issues.length, 1);
    expect(issues.single.instanceId, 'bad');
    await mount(
      tester,
      KChart(controller: chart, onIssue: (issue) => issues.add(issue)),
    );
    expect(issues.length, 1, reason: '更换错误回调函数不应重放未变化的错误');
    chart.scrollToLatest();
    await tester.pump();
    expect(issues.length, 1);

    chart.setOptions(KChartOptions());
    await tester.pump();
    chart.setOptions(KChartOptions(indicators: [broken]));
    await tester.pump();
    expect(issues.length, 2);
  });

  testWidgets('错误回调同步修复配置后，不再交付同一旧快照里的其余错误', (tester) async {
    final chart = create(
      options: KChartOptions(
        indicators: [
          KChartIndicatorBinding(
            panelId: 'main',
            config:
                IndicatorConfig(instanceId: 'bad-1', definitionId: 'missing'),
          ),
          KChartIndicatorBinding(
            panelId: 'main',
            config:
                IndicatorConfig(instanceId: 'bad-2', definitionId: 'missing'),
          ),
        ],
      ),
    );
    final issues = <KChartIssue>[];
    await mount(
      tester,
      KChart(
        controller: chart,
        onIssue: (issue) {
          issues.add(issue);
          chart.setOptions(KChartOptions());
        },
      ),
    );
    await tester.pump();
    expect(issues, hasLength(1));
    expect(chart.value.issues, isEmpty);
  });

  testWidgets('时钟在后台或 TickerMode 禁用时暂停，恢复后同步', (tester) async {
    final chart = create();
    var now = candles.last.openTime + 1000;
    await mount(
      tester,
      KChart(controller: chart, currentTimeMilliseconds: () => now),
    );
    int displayedTime() =>
        tester.widget<KChartSurface>(find.byType(KChartSurface)).currentTime;
    expect(displayedTime(), now);
    final clockBuilder = tester.widget<ValueListenableBuilder<int>>(
      find.byType(ValueListenableBuilder<int>),
    );
    now += 1000;
    await tester.pump(const Duration(seconds: 1));
    expect(displayedTime(), now);
    expect(
      tester.widget<ValueListenableBuilder<int>>(
        find.byType(ValueListenableBuilder<int>),
      ),
      same(clockBuilder),
      reason: '时钟更新只通知内部显示树，不重建外层 KChart',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now += 10000;
    await tester.pump(const Duration(seconds: 3));
    expect(displayedTime(), isNot(now));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(displayedTime(), now);

    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child:
            host(KChart(controller: chart, currentTimeMilliseconds: () => now)),
      ),
    );
    now += 1000;
    await tester.pump(const Duration(seconds: 2));
    expect(displayedTime(), isNot(now));
    await tester.pumpWidget(
      TickerMode(
        enabled: true,
        child:
            host(KChart(controller: chart, currentTimeMilliseconds: () => now)),
      ),
    );
    expect(displayedTime(), now);
  });

  testWidgets('非 resumed 状态下挂载图表不会启动时钟，回前台才同步', (tester) async {
    final chart = create();
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    // inactive 仍允许测试绑定绘制首帧；paused 会让 Scheduler 不调度任何新帧。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    var now = candles.last.openTime + 1000;
    await mount(
      tester,
      KChart(controller: chart, currentTimeMilliseconds: () => now),
    );
    int displayedTime() =>
        tester.widget<KChartSurface>(find.byType(KChartSurface)).currentTime;
    expect(displayedTime(), now);

    now += 5000;
    await tester.pump(const Duration(seconds: 3));
    expect(displayedTime(), isNot(now));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(displayedTime(), now);
    expect(tester.takeException(), isNull);
  });

  testWidgets('倒计时只更新时钟快照，复用指标、图例和布局', (tester) async {
    final chart = create(
      options: KChartOptions(
        indicators: [
          KChartIndicatorBinding(
            panelId: 'main',
            config: IndicatorConfig(
              instanceId: 'ema',
              definitionId: 'legacy.ema',
            ),
          ),
        ],
      ),
    );
    var now = candles.last.openTime + 1000;
    await mount(
      tester,
      KChart(controller: chart, currentTimeMilliseconds: () => now),
    );
    KChartOverlaysView overlay() =>
        tester.widget<KChartOverlaysView>(find.byType(KChartOverlaysView));
    final first = overlay().frame;
    final firstCountdown = first.snapshot.latestPriceCountdownText;

    now += 1000;
    await tester.pump(const Duration(seconds: 1));
    final second = overlay().frame;
    expect(second.snapshot.latestPriceCountdownText, isNot(firstCountdown));
    expect(second.snapshot.versions.clock, first.snapshot.versions.clock + 1);
    expect(second.snapshot.data, same(first.snapshot.data));
    expect(second.snapshot.indicators, same(first.snapshot.indicators));
    expect(second.snapshot.layout, same(first.snapshot.layout));
    expect(second.legends, same(first.legends));
    expect(second.legends['main'], same(first.legends['main']));

    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 1),
      session: chart.session,
    );
    await tester.pump();
    final updated = overlay().frame;
    expect(updated.snapshot.data, isNot(same(second.snapshot.data)));
    expect(
      updated.snapshot.indicators,
      isNot(same(second.snapshot.indicators)),
    );
  });

  testWidgets('切换 Controller 后解绑旧实例并通知清除旧选中', (tester) async {
    final first = create();
    final second = create();
    final changes = <KChartSelection?>[];
    await mount(
      tester,
      KChart(controller: first, onSelectionChanged: changes.add),
    );
    await tester.tapAt(const Offset(150, 180));
    await tester.pump();
    expect(changes.length, 1);
    await mount(
      tester,
      KChart(controller: second, onSelectionChanged: changes.add),
    );
    expect(changes.last, isNull);
    final count = changes.length;
    first.clearSelection();
    await tester.pump();
    expect(changes.length, count);
    expect(first.isDisposed || second.isDisposed, isFalse);
  });

  testWidgets('读屏播报行情和选中值，提供缩放及返回最新操作', (tester) async {
    final semantics = tester.ensureSemantics();
    final chart = create();
    await mount(tester, KChart(controller: chart));
    final label = 'K 线图 ${candles.last.symbol} ${candles.last.interval.code}';
    var data =
        tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
    expect(data.value, contains('最新'));
    expect(data.value, contains('收 '));
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isLiveRegion, isFalse);

    var region =
        tester.widget<ChartGestureRegion>(find.byType(ChartGestureRegion));
    final itemExtent = region.viewport().itemExtent;
    region.semantics!.onIncrease!();
    await tester.pump();
    region = tester.widget<ChartGestureRegion>(find.byType(ChartGestureRegion));
    expect(region.viewport().itemExtent, greaterThan(itemExtent));

    await tester.tapAt(const Offset(150, 180));
    await tester.pump();
    data = tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
    expect(data.value, contains('已选中'));
    expect(data.value, contains('收 '));
    expect(data.value, contains('命中值'));

    chart.scrollToTime(epochMilliseconds: candles[20].openTime);
    await tester.pump();
    expect(chart.value.viewportInfo.isAtLatest, isFalse);
    region = tester.widget<ChartGestureRegion>(find.byType(ChartGestureRegion));
    expect(region.semantics!.onTap, isNotNull);
    region.semantics!.onTap!();
    await tester.pump();
    expect(chart.value.viewportInfo.isAtLatest, isTrue);
    semantics.dispose();
  });

  testWidgets('只读图表保留可本地化播报但不提供导航动作', (tester) async {
    final semantics = tester.ensureSemantics();
    final chart = create();
    await mount(
      tester,
      KChart(
        controller: chart,
        interactionEnabled: false,
        labels: const KChartLabels(
          chart: 'Candles',
          latest: 'Current',
          zoomHint: 'Read only',
        ),
      ),
    );
    final data = tester
        .getSemantics(find.bySemanticsLabel('Candles BTCUSDT 1m'))
        .getSemanticsData();
    expect(data.value, contains('Current'));
    expect(data.hint, 'Read only');
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    expect(find.byType(ChartGestureRegion), findsNothing);
    semantics.dispose();
  });

  testWidgets('空行情有明确读屏状态且不提供缩放操作', (tester) async {
    final semantics = tester.ensureSemantics();
    final chart = KChartController(
      series: KlineSeries.fromKline(candles.first),
      initialData: const [],
    );
    addTearDown(chart.dispose);
    await mount(tester, KChart(controller: chart));
    final data =
        tester.getSemantics(find.bySemanticsLabel('K 线图')).getSemanticsData();
    expect(data.value, '暂无行情数据');
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });
}
