import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/k_chart_theme.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
import 'package:m_k_chart/src/controller/k_chart_facade.dart' as binding;
import 'package:m_k_chart/src/widget/k_chart_frame.dart';
import 'package:m_k_chart/src/widget/k_chart_legend.dart';
import 'package:m_k_chart/src/widget/k_chart_overlays.dart';
import 'package:m_k_chart/src/widget/k_chart_surface.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(100);
  KChartIndicatorBinding indicator(
    String id,
    String definition, {
    String panel = 'main',
    Map<String, num> parameters = const {},
  }) =>
      KChartIndicatorBinding(
        panelId: panel,
        config: IndicatorConfig(
          instanceId: id,
          definitionId: definition,
          parameters: parameters,
        ),
      );
  KChartController create(KChartOptions options) {
    final chart = KChartController(
      series: KlineSeries.fromKline(candles.first),
      initialData: candles,
      options: options,
    );
    addTearDown(chart.dispose);
    return chart;
  }

  Future<void> mount(
    WidgetTester tester,
    KChartController chart, {
    double width = 480,
    double scale = 1,
    KChartTheme? theme,
    KChartLabels labels = const KChartLabels.zhCN(),
    KChartSelectionBuilder? selectionBuilder,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 500,
              child: KChartSurface(
                controller: chart,
                style: theme ?? KChartTheme.light(),
                currentTime: candles.last.openTime + 10000,
                labels: labels,
                selectionBuilder: selectionBuilder,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  KChartFrame frame(WidgetTester tester) =>
      tester.widget<KChartOverlaysView>(find.byType(KChartOverlaysView)).frame;
  String legendText(WidgetTester tester, String id) => tester
      .widget<RichText>(find.byKey(ValueKey('k-chart-legend-$id')))
      .text
      .toPlainText();

  testWidgets('多指标同时显示，MA 仅三路，周期修改同步参数文字和输出', (tester) async {
    final chart = create(
      KChartOptions(
        indicators: [
          indicator(
            'ma',
            'legacy.ma',
            parameters: {'period1': 7, 'period2': 25, 'period3': 99},
          ),
          indicator('ema', 'legacy.ema', parameters: {'period1': 7}),
          indicator(
            'super',
            'builtin.super',
            parameters: {'period': 12, 'multiplier': 2.5},
          ),
        ],
      ),
    );
    await mount(tester, chart);
    expect(legendText(tester, 'ma:ma5'), startsWith('MA(7): '));
    expect(legendText(tester, 'ma:ma10'), startsWith('MA(25): '));
    expect(legendText(tester, 'ma:ma20'), startsWith('MA(99): '));
    expect(find.byKey(const ValueKey('k-chart-legend-ma:ma30')), findsNothing);
    expect(frame(tester).snapshot.indicator('ma').series.length, 3);
    expect(
      binding
          .runtimeForKChartWidget(chart)
          .value
          .indicatorBatch
          .results['ma']!
          .series
          .length,
      4,
    );
    expect(legendText(tester, 'ema:ema5'), startsWith('EMA(7): '));
    expect(
      legendText(tester, 'super:selected'),
      startsWith('SUPERTREND(12,2.5) '),
    );
    chart.setOptions(
      chart.value.options.copyWith(
        indicators: [
          indicator('ema', 'legacy.ema', parameters: {'period1': 9}),
        ],
      ),
    );
    await tester.pump();
    expect(legendText(tester, 'ema:ema5'), startsWith('EMA(9): '));
    expect(
      find.byKey(const ValueKey('k-chart-legend-super:selected')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('透明普通字体，主副图最小参数高度相同且文字不会进入数据区', (tester) async {
    final chart = create(
      KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
        indicators: [
          indicator('avl', 'builtin.avl'),
          indicator('cci', 'builtin.cci', panel: 'sub'),
        ],
      ),
    );
    await mount(tester, chart);
    final projected = frame(tester);
    expect(projected.snapshot.layout.mainPanel.headerBounds.height, 18);
    expect(projected.snapshot.layout.panel('sub').headerBounds.height, 18);
    for (final legend in tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(KChartLegend),
        matching: find.byType(RichText),
      ),
    )) {
      expect(legend.text.style!.fontWeight, FontWeight.normal);
    }
    expect(
      find.descendant(
        of: find.byType(KChartLegend),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    final header =
        tester.getRect(find.byKey(const ValueKey('k-chart-header-main')));
    final value =
        tester.getRect(find.byKey(const ValueKey('k-chart-legend-avl:avl')));
    expect(header.contains(value.center), isTrue);
    expect(
      value.bottom,
      lessThanOrEqualTo(projected.snapshot.layout.mainPanel.bounds.top),
    );
    expect((value.center.dy - header.center.dy).abs(), lessThan(1));
  });

  testWidgets('窄屏、多指标与大字体自动增高但仍保留每个面板最小内容高度', (tester) async {
    final chart = create(
      KChartOptions(
        secondaryPanels: [
          KChartSecondaryPanelOptions(
            id: 'sub',
            layout: KChartPanelOptions(minHeight: 108, autoHeaderHeight: true),
          ),
        ],
        indicators: [
          for (var i = 0; i < 12; i++)
            indicator('ema$i', 'legacy.ema', panel: i.isEven ? 'main' : 'sub'),
        ],
      ),
    );
    await mount(tester, chart, width: 240, scale: 2);
    final projected = frame(tester);
    expect(
      projected.snapshot.layout.mainPanel.headerBounds.height,
      greaterThan(18),
    );
    expect(
      projected.snapshot.layout.panel('sub').headerBounds.height,
      greaterThan(18),
    );
    expect(
      projected.snapshot.layout.mainPanel.bounds.height,
      greaterThanOrEqualTo(220),
    );
    expect(
      projected.snapshot.layout.panel('sub').bounds.height,
      greaterThanOrEqualTo(108),
    );
    expect(find.byType(KChartLegend), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('固定参数高度不被自动测量改变，主副格式独立生效', (tester) async {
    final chart = create(
      KChartOptions(
        mainPanel:
            KChartPanelOptions(headerHeight: 24, autoHeaderHeight: false),
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
        indicators: [
          indicator('ema', 'legacy.ema'),
          indicator('cci', 'builtin.cci', panel: 'sub'),
        ],
      ),
    );
    await mount(
      tester,
      chart,
      width: 240,
      scale: 2,
      theme: KChartTheme.light(
        mainValueFormatter: (value, places) => '主${value.toStringAsFixed(1)}',
        secondaryValueFormatter: (value, places) =>
            '副${value.toStringAsFixed(3)}',
      ),
    );
    expect(frame(tester).snapshot.layout.mainPanel.headerBounds.height, 24);
    expect(legendText(tester, 'ema:ema5'), contains(': 主'));
    expect(legendText(tester, 'cci:cci'), contains(': 副'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('信息面板以中线左右避让，所有字段与命中值显示，拖动不被面板拦截', (tester) async {
    final chart = create(KChartOptions());
    await mount(tester, chart);
    await tester.tapAt(const Offset(120, 180));
    await tester.pump();
    final position = find.byKey(const ValueKey('k-chart-details-position'));
    expect(tester.getRect(position).left, greaterThan(240));
    for (final label in [
      '时间',
      '开',
      '高',
      '低',
      '收',
      '涨跌',
      '涨跌幅',
      '振幅',
      '量',
      '额',
      '命中值',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tapAt(const Offset(350, 280));
    await tester.pump();
    expect(tester.getRect(position).left, 8);
    final panelBounds =
        tester.getRect(find.byKey(const ValueKey('k-chart-details')));
    expect(panelBounds.left, greaterThanOrEqualTo(0));
    expect(
      panelBounds.bottom,
      lessThanOrEqualTo(
        frame(tester).snapshot.layout.mainPanel.bounds.bottom,
      ),
    );
    await tester.dragFrom(panelBounds.center, const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(chart.value.selection, isNull);
    expect(find.byKey(const ValueKey('k-chart-details')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选中柱替换后信息与指标更新，其他柱刷新不丢失选中', (tester) async {
    final chart =
        create(KChartOptions(indicators: [indicator('avl', 'builtin.avl')]));
    await mount(tester, chart);
    final runtime = binding.runtimeForKChartWidget(chart);
    runtime.select(
      openTime: candles.last.openTime,
      panelId: 'main',
      price: candles.last.close,
    );
    await tester.pump();
    final oldLegend = legendText(tester, 'avl:avl');
    final changed = candles.last.copyWith(
      close: candles.last.close + 0.1,
      quoteVolume: candles.last.quoteVolume + 20000,
    );
    chart.updateKline(changed, session: chart.session);
    await tester.pump();
    expect(chart.value.selection!.candle.close, changed.close);
    expect(
      find.text(KChartTheme.light().formatMainValue(changed.close)),
      findsWidgets,
    );
    expect(legendText(tester, 'avl:avl'), isNot(oldLegend));
    chart.appendData(
      buildV2KlineFixture(1, startIndex: 100),
      session: chart.session,
    );
    await tester.pump();
    expect(chart.value.selection!.candle.openTime, changed.openTime);
    expect(find.byKey(const ValueKey('k-chart-details')), findsOneWidget);
  });

  testWidgets('自定义内容与文案可替换，不接管信息面板定位', (tester) async {
    final chart = create(KChartOptions());
    await mount(
      tester,
      chart,
      labels: const KChartLabels(time: 'Time', close: 'Close'),
    );
    await tester.tapAt(const Offset(120, 180));
    await tester.pump();
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await mount(
      tester,
      chart,
      selectionBuilder: (_, selected) =>
          Text('自定义 ${selected.candle.openTime}'),
    );
    expect(find.text('Time'), findsNothing);
    expect(
      find.text('自定义 ${chart.value.selection!.candle.openTime}'),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('k-chart-details-position')))
          .left,
      greaterThan(240),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('线图不显示主图指标图例，切回蜡烛无需重新配置指标', (tester) async {
    final chart =
        create(KChartOptions(indicators: [indicator('ema', 'legacy.ema')]));
    await mount(tester, chart);
    chart
        .setOptions(chart.value.options.copyWith(mainMode: ChartMainMode.line));
    await tester.pump();
    expect(find.byType(KChartLegend), findsNothing);
    chart.setOptions(
      chart.value.options.copyWith(mainMode: ChartMainMode.candlestick),
    );
    await tester.pump();
    expect(find.byType(KChartLegend), findsOneWidget);
  });
}
