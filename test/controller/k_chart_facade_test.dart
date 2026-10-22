import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
// 只用于模拟未来 Widget 的布局/命中/挂载输入，不参与上方宿主编译探针。
import 'package:m_k_chart/src/controller/k_chart_facade.dart' as binding;

// 使用仅依赖候选入口的示例定义，验证宿主无需访问内部注册表。
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_custom_indicator_example.dart';

import '../contracts/fixtures/v2_candidate_host.dart' as host;
import '../contracts/fixtures/v2_host_compile_probe.dart' as data_host;
import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(100);
  final series = KlineSeries.fromKline(candles.first);
  KChartController create({
    Iterable<Kline>? data,
    KChartHistoryLoader? loader,
  }) {
    final chart = host.createPublicChart(
      series: series,
      initialData: data ?? candles,
      historyLoader: loader,
    );
    addTearDown(chart.dispose);
    return chart;
  }

  test('候选入口完成真实创建、配置和只读订阅，无第二份状态或通知器', () {
    final chart = create();
    final ValueListenable<KChartViewState> listenable = chart;
    final KChartDataCommands commands = chart;
    final runtime = binding.runtimeForKChartWidget(chart);
    expect(chart, isNot(isA<ChangeNotifier>()));
    expect(chart.value, same(runtime.view.value));
    expect(
      chart.value.options.indicators.single.config.parameters['period'],
      14,
    );
    expect(chart.value.issues, isEmpty);
    var calls = 0;
    void listener() {
      calls++;
      expect(chart.value, same(runtime.view.value));
    }

    listenable.addListener(listener);
    commands.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: chart.session,
    );
    expect(calls, 1);
    listenable.removeListener(listener);
    chart.clearSelection();
    expect(calls, 1);
  });

  test('自定义指标按实例隔离参数、计算和错误，目录保持只读', () {
    final chart = KChartController(
      series: series,
      initialData: candles,
      indicatorDefinitions: const [V2TypicalPriceIndicator()],
      options: KChartOptions(
        secondaryPanels: [
          KChartSecondaryPanelOptions(id: 'first'),
          KChartSecondaryPanelOptions(id: 'second'),
        ],
        indicators: [
          KChartIndicatorBinding(
            panelId: 'first',
            config: IndicatorConfig(
              instanceId: 'typical-a',
              definitionId: V2TypicalPriceIndicator.definitionId,
            ),
          ),
          KChartIndicatorBinding(
            panelId: 'second',
            config: IndicatorConfig(
              instanceId: 'typical-b',
              definitionId: V2TypicalPriceIndicator.definitionId,
              parameters: const {'scale': 2},
            ),
          ),
        ],
      ),
    );
    addTearDown(chart.dispose);
    final entry = chart.indicatorCatalog.last;
    expect(entry.definitionId, V2TypicalPriceIndicator.definitionId);
    expect(entry.displayName, '典型价');
    expect(entry.placement, IndicatorPlacement.separatePanel);
    expect(entry.series.single.id, 'value');
    expect(
      chart.indicatorCatalog
          .firstWhere((item) => item.definitionId == 'legacy.ma')
          .series
          .map((item) => item.id),
      ['ma5', 'ma10', 'ma20'],
    );
    expect(() => entry.series.clear(), throwsUnsupportedError);
    expect(entry.parameters.single.key, 'scale');
    expect(
      chart.indicatorParametersFor(entry.definitionId),
      same(entry.parameters),
    );
    expect(chart.indicatorCatalog, same(chart.indicatorCatalog));
    expect(() => chart.indicatorCatalog.clear(), throwsUnsupportedError);
    final runtime = binding.runtimeForKChartWidget(chart);
    final first = runtime.value.indicatorBatch.results['typical-a']!;
    final second = runtime.value.indicatorBatch.results['typical-b']!;
    expect(
      second.series.single.values.last,
      first.series.single.values.last! * 2,
    );

    chart.setOptions(
      chart.value.options.copyWith(
        indicators: [
          ...chart.value.options.indicators,
          KChartIndicatorBinding(
            panelId: 'first',
            config: IndicatorConfig(
              instanceId: 'typical-bad',
              definitionId: V2TypicalPriceIndicator.definitionId,
              parameters: const {'scale': -1},
            ),
          ),
        ],
      ),
    );
    expect(chart.value.issues.single.instanceId, 'typical-bad');
    expect(
      runtime.value.indicatorBatch.results.keys,
      containsAll(['typical-a', 'typical-b']),
    );
  });

  test('所有数据命令保留参数、回执和版本语义', () {
    final chart = create(data: candles.sublist(20, 90));
    final session = chart.session;
    expect(
      chart.prependHistory(candles.sublist(0, 20), session: session).changed,
      isTrue,
    );
    expect(
      chart.appendData(candles.sublist(90), session: session).changed,
      isTrue,
    );
    final corrected = candles.first.copyWith(close: candles.first.close + 0.1);
    expect(
      chart.updateKline(corrected, session: session).status,
      KChartDataUpdateStatus.rejectedClosedCorrection,
    );
    expect(
      chart
          .updateKline(
            corrected,
            session: session,
            allowClosedCorrection: true,
          )
          .changed,
      isTrue,
    );
    final runtime = binding.runtimeForKChartWidget(chart);
    runtime.setViewportSize(480);
    runtime.select(
      openTime: candles[80].openTime,
      panelId: 'main',
      price: 1000,
    );
    chart.replaceData(candles, session: session);
    expect(chart.value.selection!.candle, candles[80]);
    final receipt = chart.replaceData(
      candles,
      session: session,
      viewportPolicy: KChartDataViewportPolicy.resetToLatest,
    );
    expect(receipt.changed, isFalse);
    expect(chart.value.selection, isNull);
    expect(chart.value.viewportInfo.isAtLatest, isTrue);
  });

  test('真实门面可用于已有宿主异步加载探针，旧响应保持隔离', () async {
    final chart = create();
    final response = Completer<List<Kline>>();
    final load = data_host.loadSeries(chart, series, (_) => response.future);
    chart.beginSeries(series, initialData: candles);
    final before = chart.value;
    response.complete([]);
    expect((await load).status, KChartDataUpdateStatus.ignoredStaleSession);
    expect(chart.value, same(before));
    expect(
      (await data_host.loadSeries(chart, series, (_) async => candles)).changed,
      isTrue,
    );
    expect(chart.value.data, candles);
  });

  test('实时流探针绑定原令牌，不因换序列写入新会话', () async {
    final chart = create();
    final stream = StreamController<Kline>(sync: true);
    final receipts = <KChartDataUpdateResult>[];
    final subscription = data_host.subscribeRealtime(
      chart,
      stream.stream,
      receipts.add,
      (error, stack) => fail('$error'),
    );
    stream.add(candles.last.copyWith(close: candles.last.close + 0.1));
    expect(receipts.last.changed, isTrue);
    chart.beginSeries(series, initialData: candles);
    stream.add(candles.last);
    expect(receipts.last.status, KChartDataUpdateStatus.ignoredStaleSession);
    await subscription.cancel();
    await stream.close();
  });

  test('导航延迟到布局，配置与选中不暴露像素命令', () {
    final chart = create();
    chart.scrollToTime(epochMilliseconds: candles[40].openTime, alignment: 0.5);
    final runtime = binding.runtimeForKChartWidget(chart);
    runtime.setViewportSize(480);
    expect(
      chart.value.viewportInfo.visibleStartTime!,
      lessThan(candles[40].openTime),
    );
    expect(
      chart.value.viewportInfo.visibleEndTime!,
      greaterThan(candles[40].openTime),
    );
    runtime.select(openTime: candles[40].openTime, panelId: 'cci', price: -1);
    chart.setOptions(chart.value.options.copyWith(mainTimeAxisHeight: 22));
    expect(chart.value.selection!.value, -1);
    chart.clearSelection();
    expect(chart.value.selection, isNull);
    chart.scrollToLatest();
    expect(chart.value.viewportInfo.isAtLatest, isTrue);
    chart.resetViewport();
    expect(runtime.value.viewport.itemExtent, 8);
  });

  test('指标失败可读取和重试，修复配置后消失', () {
    final chart = create();
    chart.setOptions(
      chart.value.options.copyWith(
        indicators: [
          KChartIndicatorBinding(
            panelId: 'main',
            config:
                IndicatorConfig(instanceId: 'broken', definitionId: 'missing'),
          ),
        ],
      ),
    );
    expect(chart.value.issues.single.kind, KChartIssueKind.indicator);
    expect(chart.value.issues.single.instanceId, 'broken');
    final before = chart.value.revision;
    chart.retryIndicators();
    expect(chart.value.revision, greaterThan(before));
    chart.setOptions(chart.value.options.copyWith(indicators: []));
    expect(chart.value.issues, isEmpty);
  });

  test('历史失败与重试使用同一个协调器，卸载不销毁宿主控制器', () async {
    var attempts = 0;
    final chart = create(
      loader: (_) async {
        if (++attempts == 1) throw StateError('offline');
        return KChartHistoryPage(candles: [], hasMore: false);
      },
    );
    final runtime = binding.runtimeForKChartWidget(chart);
    final owner = Object();
    runtime.attach(owner);
    runtime.setViewportSize(480);
    await chart.retryHistory();
    expect(chart.value.historyStatus, KChartHistoryPhase.failed);
    await chart.retryHistory();
    expect(chart.value.historyStatus, KChartHistoryPhase.exhausted);
    runtime.detach(owner);
    expect(chart.isDisposed, isFalse);
    expect(chart.value.viewportInfo.isAttached, isFalse);
    chart.setOptions(chart.value.options.copyWith(gridColumns: 3));
    expect(chart.value.options.gridColumns, 3);
  });

  test('覆盖物可仅靠候选入口构造，切换会话与迟到回调语义不变', () {
    final chart = create();
    expect(
      host.installPublicOverlays(chart, candles.last),
      KChartOverlayUpdateStatus.applied,
    );
    final before = chart.value;
    expect(
      before.overlays.drawings.single.kind,
      ChartDrawingKind.horizontalLine,
    );
    chart.beginSeries(series, initialData: candles);
    expect(chart.value.overlays.isEmpty, isTrue);
    expect(
      chart.setOverlays(session: before.session),
      KChartOverlayUpdateStatus.ignoredStaleSession,
    );
    expect(before.overlays.events, hasLength(1));
  });

  test('双图状态独立，同一控制器不能同时挂载两个 Widget', () {
    final first = create();
    final second = create();
    final before = second.value;
    first.setOptions(first.value.options.copyWith(gridColumns: 3));
    expect(second.value, same(before));
    expect(
      second.replaceData([], session: first.session).status,
      KChartDataUpdateStatus.ignoredStaleSession,
    );
    final runtime = binding.runtimeForKChartWidget(first);
    final a = Object();
    final b = Object();
    runtime.attach(a);
    expect(() => runtime.attach(b), throwsStateError);
    runtime.detach(a);
    runtime.attach(b);
    runtime.detach(a);
    expect(first.value.viewportInfo.isAttached, isTrue);
    runtime.detach(b);
  });

  test('控制器与配置对象无内部状态/几何写入口', () {
    final dynamic chart = create();
    final dynamic options = chart.value.options;
    final dynamic viewport = options.viewport;
    expect(() => chart.dispatch(null), throwsNoSuchMethodError);
    expect(() => chart.notifyListeners(), throwsNoSuchMethodError);
    expect(() => chart.runtime, throwsNoSuchMethodError);
    expect(() => chart.applyViewport(null), throwsNoSuchMethodError);
    expect(() => chart.select(), throwsNoSuchMethodError);
    expect(() => chart.attach(Object()), throwsNoSuchMethodError);
    expect(
      () => options.createLayout(width: 480, height: 600),
      throwsNoSuchMethodError,
    );
    expect(() => viewport.resolveViewport(null), throwsNoSuchMethodError);
  });

  test('监听器重入和通知内销毁仍安全，旧数据回调忽略而主动命令拒绝', () {
    final chart = create();
    var calls = 0;
    chart.addListener(() {
      if (++calls == 1) {
        chart.setOptions(chart.value.options.copyWith(gridColumns: 4));
      } else {
        chart.dispose();
      }
    });
    final options = chart.value.options;
    final session = chart.session;
    chart.setOptions(options.copyWith(gridColumns: 3));
    expect(calls, 2);
    expect(chart.isDisposed, isTrue);
    expect(chart.value.options.gridColumns, 4);
    chart.dispose();
    expect(
      chart.replaceData(_throwingData(), session: session).status,
      KChartDataUpdateStatus.ignoredStaleSession,
    );
    expect(
      chart.setOverlays(session: session),
      KChartOverlayUpdateStatus.ignoredStaleSession,
    );
    expect(() => chart.setOptions(options), throwsStateError);
    expect(() => chart.scrollToLatest(), throwsStateError);
    expect(() => chart.addListener(() {}), throwsStateError);
    chart.removeListener(() {});
  });
}

Iterable<Kline> _throwingData() sync* {
  throw StateError('不应遍历失效数据');
}
