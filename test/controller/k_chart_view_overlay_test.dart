import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/controller/k_chart_history_contract.dart';
import 'package:m_k_chart/src/controller/k_chart_indicator_binding.dart';
import 'package:m_k_chart/src/controller/k_chart_options.dart';
import 'package:m_k_chart/src/drawing/chart_drawing.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(100);
  final series = KlineSeries.fromKline(candles.first);
  ChartPriceLine line({
    String id = 'order',
    double price = 1000,
    ChartPriceLineStyle style = ChartPriceLineStyle.dashed,
  }) =>
      ChartPriceLine(id: id, price: price, style: style);
  ChartEventOverlay event({String id = 'fill'}) => ChartEventOverlay(
        id: id,
        epochMilliseconds: candles.first.openTime,
        price: 999,
      );
  ChartValueMarker marker({String id = 'mark'}) => ChartValueMarker(
        id: id,
        price: 998,
        text: '提醒',
      );
  ChartDrawing drawing() => ChartDrawing(
        id: 'drawing',
        kind: ChartDrawingKind.horizontalLine,
        anchors: [
          ChartDrawingAnchor(
            epochMilliseconds: candles.first.openTime,
            price: 997,
          ),
        ],
      );
  KChartDataCoordinator create({
    List<Kline>? data,
    KChartHistoryLoader? loader,
    KChartOptions? options,
    double width = 480,
  }) {
    final chart = KChartDataCoordinator(
      series: series,
      initialData: data ?? candles,
      options: options ?? KChartOptions(),
      historyLoader: loader,
    );
    addTearDown(chart.dispose);
    chart.setViewportSize(width);
    return chart;
  }

  void fill(KChartDataCoordinator chart) => chart.setOverlays(
        session: chart.session,
        priceLines: [line()],
        events: [event()],
        valueMarkers: [marker()],
        drawings: [drawing()],
      );

  test('只读桥稳定且与内部通知同步，不重复复制行情列表', () {
    final chart = create();
    final ValueListenable<KChartViewState> view = chart.view;
    expect(chart.view, same(view));
    expect(view, isNot(isA<ChangeNotifier>()));
    final before = view.value;
    var calls = 0;
    void listener() {
      calls++;
      expect(view.value.revision, chart.value.revision);
      expect(view.value.dataRevision, chart.value.data.version.value);
      expect(view.value.data, same(chart.value.data.data));
      expect(view.value.options, same(chart.value.options));
      expect(view.value.overlays, same(chart.value.overlays));
    }

    view.addListener(listener);
    chart.select(openTime: candles[90].openTime, panelId: 'main', price: 123);
    expect(calls, 1);
    expect(view.value.data, same(before.data));
    expect(before.selection, isNull);
    expect(() => view.value.data.clear(), throwsUnsupportedError);
    final selected = view.value;
    chart.setOptions(chart.value.options.copyWith());
    expect(view.value, same(selected));
    expect(calls, 1);
    view.removeListener(listener);
    chart.clearSelection();
    expect(calls, 1);
  });

  test('副图命中值与收盘价分离，实时替换和前插更新选择快照', () {
    final chart = create(
      data: candles.sublist(10),
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
      ),
    );
    chart.select(openTime: candles[10].openTime, panelId: 'sub', price: -12.5);
    final old = chart.view.value;
    expect(old.selection!.previousCandle, isNull);
    expect(old.selection!.value, -12.5);
    chart.prependHistory(candles.sublist(0, 10), session: chart.session);
    expect(chart.view.value.selection!.previousCandle, candles[9]);
    final changed = candles[10].copyWith(close: candles[10].close + 0.1);
    chart.updateKline(
      changed,
      session: chart.session,
      allowClosedCorrection: true,
    );
    expect(chart.view.value.selection!.candle, changed);
    expect(chart.view.value.selection!.value, -12.5);
    expect(chart.view.value.selection!.panelId, 'sub');
    expect(old.selection!.candle, candles[10]);
    chart.setPanels(['main']);
    expect(chart.view.value.selection, isNull);
  });

  test('可见时间只来自实际柱，无布局或全空白时不虚构时间', () {
    final chart = create(width: 0);
    expect(chart.view.value.viewportInfo.hasLayout, isFalse);
    expect(chart.view.value.viewportInfo.visibleStartTime, isNull);
    expect(chart.view.value.viewportInfo.isAtLatest, isFalse);
    chart.setViewportSize(480);
    final owner = Object();
    chart.attach(owner);
    final info = chart.view.value.viewportInfo;
    final range = chart.value.viewport.visibleRange;
    expect(info.isAttached, isTrue);
    expect(info.hasLayout, isTrue);
    expect(info.isAtLatest, isTrue);
    expect(info.visibleStartTime, candles[range.start].openTime);
    expect(info.visibleEndTime, candles[range.end - 1].openTime);
    chart.detach(owner);
    expect(chart.view.value.viewportInfo.isAttached, isFalse);
    expect(chart.view.value.viewportInfo.hasLayout, isTrue);
    chart.replaceData(const [], session: chart.session);
    expect(chart.view.value.viewportInfo.visibleStartTime, isNull);
    expect(chart.view.value.viewportInfo.visibleEndTime, isNull);
    expect(chart.view.value.viewportInfo.isAtOldest, isFalse);
    expect(chart.view.value.viewportInfo.isAtLatest, isFalse);

    // 底层手工视口仍可能完全越过数据，DTO 不能越界访问。
    final blank = KChartDataCoordinator(
      series: series,
      initialData: candles,
      initialViewport: ChartViewport(width: 80, futurePaddingItems: 100),
    );
    addTearDown(blank.dispose);
    blank.applyViewport(blank.value.viewport.copyWith(scrollOffsetItems: -100));
    expect(blank.view.value.viewportInfo.visibleStartTime, isNull);
    expect(blank.view.value.viewportInfo.visibleEndTime, isNull);
  });

  test('覆盖物冻结所有输入并支持结构相等，保留中文文本及样式', () {
    final lines = [line()];
    final events = [event()];
    final markers = [marker()];
    final shapes = [drawing()];
    final first = KChartOverlays(
      priceLines: lines,
      events: events,
      valueMarkers: markers,
      drawings: shapes,
    );
    final equal = KChartOverlays(
      priceLines: [line()],
      events: [event()],
      valueMarkers: [marker()],
      drawings: [drawing()],
    );
    lines.clear();
    events.clear();
    markers.clear();
    shapes.clear();
    expect(first, equal);
    expect(first.hashCode, equal.hashCode);
    expect(first.isEmpty, isFalse);
    expect(first.valueMarkers.single.text, '提醒');
    expect(first.priceLines.single.style, ChartPriceLineStyle.dashed);
    expect(() => first.priceLines.clear(), throwsUnsupportedError);
    expect(() => first.events.clear(), throwsUnsupportedError);
    expect(() => first.valueMarkers.clear(), throwsUnsupportedError);
    expect(() => first.drawings.clear(), throwsUnsupportedError);
    expect(() => first.drawings.single.anchors.clear(), throwsUnsupportedError);
    expect(KChartOverlays().isEmpty, isTrue);
  });

  test('重复 id 跨类别也拒绝，枚举失败回滚整个事务', () {
    final chart = create();
    fill(chart);
    final before = chart.value;
    final view = chart.view.value;
    expect(
      () => chart
          .setOverlays(session: chart.session, priceLines: [line(), line()]),
      throwsArgumentError,
    );
    expect(
      () => chart.setOverlays(
        session: chart.session,
        priceLines: [line()],
        events: [event(id: 'order')],
      ),
      throwsArgumentError,
    );
    expect(
      () => chart.setOverlays(
        session: chart.session,
        valueMarkers: [marker(id: 'drawing')],
        drawings: [drawing()],
      ),
      throwsArgumentError,
    );
    expect(
      () => chart.setOverlays(
        session: chart.session,
        priceLines: _throwingLines(),
      ),
      throwsStateError,
    );
    expect(chart.value, same(before));
    expect(chart.view.value, same(view));
  });

  test('覆盖物更新只通知一次，复用数据指标视口选中，相等写入无通知', () {
    final chart = create();
    chart.select(openTime: candles[90].openTime, panelId: 'main', price: 1);
    final before = chart.value;
    var calls = 0;
    chart.view.addListener(() => calls++);
    fill(chart);
    expect(calls, 1);
    expect(chart.value.data, same(before.data));
    expect(chart.value.indicatorBatch, same(before.indicatorBatch));
    expect(chart.value.viewport, same(before.viewport));
    expect(chart.value.selection, same(before.selection));
    final snapshot = chart.view.value;
    fill(chart);
    expect(chart.view.value, same(snapshot));
    expect(calls, 1);
    expect(
      chart.setOverlays(
        session: chart.session,
        priceLines: [line(style: ChartPriceLineStyle.solid)],
      ),
      KChartOverlayUpdateStatus.applied,
    );
    expect(calls, 2);
    expect(snapshot.overlays.events, hasLength(1));
    expect(chart.view.value.overlays.events, isEmpty);
    expect(
      chart.setOverlays(session: chart.session),
      KChartOverlayUpdateStatus.applied,
    );
    expect(
      chart.setOverlays(session: chart.session),
      KChartOverlayUpdateStatus.unchanged,
    );
  });

  test('实时更新、窗口裁剪清空、导航、配置和解绑不删除覆盖物', () {
    final chart = create();
    fill(chart);
    final overlays = chart.view.value.overlays;
    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: chart.session,
    );
    chart.appendData(
      buildV2KlineFixture(1, startIndex: 100),
      session: chart.session,
    );
    chart.replaceData(candles.sublist(50), session: chart.session);
    chart.prependHistory(candles.sublist(0, 50), session: chart.session);
    chart.scrollToLatest();
    chart.resetViewport();
    chart.setOptions(chart.value.options.copyWith(gridColumns: 3));
    final owner = Object();
    chart.attach(owner);
    chart.detach(owner);
    chart.replaceData(const [], session: chart.session);
    expect(chart.view.value.overlays, same(overlays));
  });

  test('同序列重开及换交易对清覆盖物，旧令牌和跨实例回调不遍历载荷', () {
    final chart = create();
    final other = create();
    for (final next in [
      series,
      KlineSeries.fromKline(buildV2KlineFixture(1, symbol: 'ETHUSDT').first),
    ]) {
      fill(chart);
      final old = chart.view.value;
      chart.beginSeries(next);
      expect(chart.view.value.overlays.isEmpty, isTrue);
      expect(old.overlays.isEmpty, isFalse);
      expect(chart.view.value.session, isNot(same(old.session)));
      final after = chart.view.value;
      expect(
        chart.setOverlays(session: old.session, priceLines: _throwingLines()),
        KChartOverlayUpdateStatus.ignoredStaleSession,
      );
      expect(
        chart.setOverlays(
          session: other.session,
          priceLines: _throwingLines(),
        ),
        KChartOverlayUpdateStatus.ignoredStaleSession,
      );
      expect(chart.view.value, same(after));
    }
    final session = chart.session;
    chart.dispose();
    expect(
      chart.setOverlays(session: session, priceLines: _throwingLines()),
      KChartOverlayUpdateStatus.ignoredStaleSession,
    );
  });

  test('错误切换不清覆盖物，两个图表互不影响', () {
    final first = create();
    final second = create();
    fill(first);
    fill(second);
    final before = first.view.value;
    final other = second.view.value;
    expect(
      () => first.beginSeries(
        series,
        initialData: buildV2KlineFixture(1, symbol: 'ETHUSDT'),
      ),
      throwsArgumentError,
    );
    expect(first.view.value, same(before));
    first.setOverlays(session: first.session);
    expect(second.view.value, same(other));
  });

  test('只读监听器可重入提交，所有观察者始终看到同版状态', () {
    final chart = create();
    var calls = 0;
    chart.view.addListener(() {
      calls++;
      expect(chart.view.value.revision, chart.value.revision);
      expect(chart.view.value.overlays, same(chart.value.overlays));
      if (calls == 1) chart.beginSeries(series, initialData: candles);
    });
    chart.addListener(() {
      expect(chart.view.value.revision, chart.value.revision);
      expect(chart.view.value.overlays, same(chart.value.overlays));
    });
    final receipt =
        chart.setOverlays(session: chart.session, priceLines: [line()]);
    expect(receipt, KChartOverlayUpdateStatus.applied);
    expect(calls, 2);
    expect(chart.view.value.overlays.isEmpty, isTrue);
  });

  test('通知内销毁不重复释放，只读桥保留最后快照但不再接受订阅', () {
    final chart = create();
    chart.view.addListener(chart.dispose);
    fill(chart);
    final last = chart.view.value;
    expect(chart.isDisposed, isTrue);
    expect(last.overlays.isEmpty, isFalse);
    chart.view.removeListener(chart.dispose);
    expect(() => chart.view.addListener(() {}), throwsStateError);
    expect(chart.view.value, same(last));
  });

  test('指标与历史错误一并投射，重试只移除恢复的问题', () async {
    final failure = StateError('历史加载失败');
    var fail = true;
    final chart = create(
      options: KChartOptions(
        indicators: [
          KChartIndicatorBinding(
            panelId: 'main',
            config: IndicatorConfig(instanceId: 'bad', definitionId: 'missing'),
          ),
        ],
      ),
      loader: (_) async {
        if (fail) throw failure;
        return KChartHistoryPage(candles: [], hasMore: false);
      },
    );
    expect(chart.view.value.issues.single.kind, KChartIssueKind.indicator);
    expect(chart.view.value.issues.single.instanceId, 'bad');
    chart.attach(Object());
    await chart.retryHistory();
    final failed = chart.view.value;
    expect(failed.historyStatus, KChartHistoryPhase.failed);
    expect(failed.issues, hasLength(2));
    expect(failed.issues.last.kind, KChartIssueKind.history);
    expect(failed.issues.last.error, same(failure));
    expect(failed.issues.last.stackTrace, same(chart.value.history.stackTrace));
    expect(() => failed.issues.clear(), throwsUnsupportedError);
    fail = false;
    await chart.retryHistory();
    expect(chart.view.value.historyStatus, KChartHistoryPhase.exhausted);
    expect(chart.view.value.issues, hasLength(1));
    chart.setIndicators([]);
    expect(chart.view.value.issues, isEmpty);
    expect(failed.issues, hasLength(2));
  });

  test('loading 与历史数据提交时只读快照一致，期间覆盖物更新不会取消请求', () async {
    final pending = Completer<KChartHistoryPage>();
    final chart =
        create(data: candles.sublist(50), loader: (_) => pending.future);
    chart.attach(Object());
    final operation = chart.retryHistory();
    expect(chart.view.value.historyStatus, KChartHistoryPhase.loading);
    fill(chart);
    final overlays = chart.view.value.overlays;
    pending.complete(
      KChartHistoryPage(candles: candles.sublist(0, 50), hasMore: false),
    );
    await operation;
    expect(chart.view.value.historyStatus, KChartHistoryPhase.exhausted);
    expect(chart.view.value.data, candles);
    expect(chart.view.value.dataRevision, chart.value.data.version.value);
    expect(chart.view.value.overlays, same(overlays));
  });
}

Iterable<ChartPriceLine> _throwingLines() sync* {
  throw StateError('不能遍历失效载荷');
}
