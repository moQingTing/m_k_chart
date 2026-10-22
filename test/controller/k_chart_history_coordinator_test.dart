import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/controller/k_chart_history_contract.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final all = buildV2KlineFixture(40);
  final current = all.sublist(20);
  final series = KlineSeries.fromKline(all.first);
  final owner = Object();

  KChartDataCoordinator create(
    KChartHistoryLoader? loader, {
    bool attach = true,
    double width = 80,
    double offset = 10,
    List<Kline>? data,
  }) {
    final input = data ?? current;
    final chart = KChartDataCoordinator(
      series: series,
      initialData: input,
      initialViewport: ChartViewport(
        itemCount: input.length,
        width: width,
        scrollOffsetItems: offset,
      ),
      historyLoader: loader,
    );
    addTearDown(chart.dispose);
    if (attach) chart.attach(owner);
    return chart;
  }

  KChartHistoryPage page({bool hasMore = false}) => KChartHistoryPage(
        candles: all.sublist(10, 20),
        hasMore: hasMore,
      );

  double xOf(KChartDataCoordinator chart, int time) => ChartXTransform(
        viewport: chart.value.viewport,
        data: chart.value.data,
      ).timeToLocalX(time);

  test('page freezes host collection', () {
    final input = List<Kline>.of(current);
    final result = KChartHistoryPage(candles: input, hasMore: true);
    input.clear();
    expect(result.candles, current);
    expect(() => result.candles.clear(), throwsUnsupportedError);
  });

  test('automatic history waits for mount and layout near the oldest edge',
      () async {
    final source = _HistorySource();
    final chart = create(source.load, attach: false, offset: 0);
    await _flush();
    expect(source.requests, isEmpty);
    chart.attach(owner);
    await _flush();
    expect(source.requests, isEmpty);
    chart.applyViewport(chart.value.viewport.copyWith(scrollOffsetItems: 8));
    expect(
      source.requests,
      isEmpty,
      reason: 'Loader must not run in the layout stack.',
    );
    await _flush();
    expect(source.requests, hasLength(1));
    expect(source.requests.single.session, same(chart.session));
    expect(source.requests.single.beforeOpenTime, current.first.openTime);
    expect(chart.value.history.phase, KChartHistoryPhase.loading);
    source.complete(0, page());
    await _flush();
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
  });

  test('unmounted, unlaid out, empty and loader-free charts do not load',
      () async {
    final source = _HistorySource();
    final charts = [
      create(source.load, attach: false),
      create(source.load, width: 0),
      create(source.load, data: []),
      create(null),
    ];
    for (final chart in charts) {
      await chart.retryHistory();
    }
    await _flush();
    expect(source.requests, isEmpty);
    charts[1].applyViewport(charts[1].value.viewport.copyWith(width: 80));
    await _flush();
    expect(source.requests, hasLength(1));
    source.complete(0, page());
    await _flush();
  });

  test(
      'in-flight retries share a Future and success commits data and paging once',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    chart.select(openTime: current[3].openTime, panelId: 'main', price: 1000);
    final before = chart.value;
    final x = xOf(chart, current[3].openTime);
    final states = <KChartRuntimeState>[];
    chart.addListener(() => states.add(chart.value));
    final pending = chart.retryHistory();
    expect(chart.retryHistory(), same(pending));
    await _flush();
    expect(source.requests, hasLength(1));
    expect(states, hasLength(1));
    source.complete(0, page());
    await pending;
    expect(states, hasLength(2));
    expect(states.last.history.phase, KChartHistoryPhase.exhausted);
    expect(states.last.data.data, hasLength(30));
    expect(states.last.selectedIndex, 13);
    expect(states.last.selectedCandle, current[3]);
    expect(xOf(chart, current[3].openTime), closeTo(x, 1e-8));
    expect(before.data.data, hasLength(20));
    expect(before.history.phase, KChartHistoryPhase.idle);
    await chart.retryHistory();
    expect(source.requests, hasLength(1));
  });

  test('history merges into latest snapshot without losing live updates',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final pending = chart.retryHistory();
    final updated = current.last.copyWith(close: current.last.close + 0.1);
    chart.updateKline(updated, session: chart.session);
    final added = buildV2KlineFixture(1, startIndex: 40).single;
    chart.appendData([added], session: chart.session);
    source.complete(0, page());
    await pending;
    expect(chart.value.data.data, hasLength(31));
    expect(chart.value.data.data[29], updated);
    expect(chart.value.data.data.last, added);
  });

  test('empty terminal page changes only history state', () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final data = chart.value.data;
    final pending = chart.retryHistory();
    source.complete(0, KChartHistoryPage(candles: const [], hasMore: false));
    await pending;
    expect(chart.value.data, same(data));
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
  });

  test('invalid pages retain data and selection and require explicit retry',
      () async {
    final invalidPages = [
      KChartHistoryPage(candles: const [], hasMore: true),
      KChartHistoryPage(candles: all.sublist(10, 20).reversed, hasMore: false),
      KChartHistoryPage(candles: [all[10], all[10]], hasMore: false),
      KChartHistoryPage(candles: [current.first], hasMore: false),
      KChartHistoryPage(
        candles: buildV2KlineFixture(1, symbol: 'ETHUSDT'),
        hasMore: false,
      ),
    ];
    for (final invalid in invalidPages) {
      final source = _HistorySource();
      final chart = create(source.load);
      chart.select(
        openTime: current.first.openTime,
        panelId: 'main',
        price: 1000,
      );
      final data = chart.value.data;
      final selection = chart.value.selection;
      final pending = chart.retryHistory();
      source.complete(0, invalid);
      await pending;
      expect(chart.value.history.phase, KChartHistoryPhase.failed);
      expect(chart.value.history.error, isNotNull);
      expect(chart.value.history.stackTrace, isNotNull);
      expect(chart.value.data, same(data));
      expect(chart.value.selection, same(selection));
      chart.clearSelection();
      chart.applyViewport(chart.value.viewport);
      await _flush();
      expect(
        source.requests,
        hasLength(1),
        reason: 'Failure must not auto-loop.',
      );
      final retry = chart.retryHistory();
      expect(
        source.requests[1].requestId,
        greaterThan(source.requests[0].requestId),
      );
      source.complete(1, page());
      await retry;
      expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
    }
  });

  test('both synchronous loader throws and asynchronous errors become failures',
      () async {
    final error = StateError('offline');
    final chart = create((_) => throw error);
    await chart.retryHistory();
    expect(chart.value.history.error, same(error));
    final source = _HistorySource();
    final second = create(source.load);
    final pending = second.retryHistory();
    source.fail(0, error);
    await pending;
    expect(second.value.history.error, same(error));
    expect(second.value.data.data, current);
  });

  test('replacement invalidates old cursor but keeps realtime session usable',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final token = chart.session;
    final pending = chart.retryHistory();
    chart.replaceData(current, session: token);
    await pending; // 不等待已经失效的网络请求返回。
    expect(chart.session, same(token));
    await _flush();
    expect(source.requests, hasLength(2));
    final active = chart.value.history.request;
    source.complete(0, page());
    await _flush();
    expect(chart.value.history.request, same(active));
    expect(chart.value.data.data, current);
    source.complete(1, page());
    await _flush();
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
    expect(chart.updateKline(current.last, session: token).changed, isFalse);
  });

  test('A to B to A discards old request success and failure', () async {
    for (final fail in [false, true]) {
      final source = _HistorySource();
      final chart = create(source.load);
      final pending = chart.retryHistory();
      final other = buildV2KlineFixture(10, symbol: 'ETHUSDT');
      chart.beginSeries(KlineSeries.fromKline(other.first), initialData: other);
      chart.beginSeries(series, initialData: current);
      await pending;
      final before = chart.value;
      if (fail) {
        source.fail(0, StateError('old network error'));
      } else {
        source.complete(0, page());
      }
      await _flush();
      expect(chart.value, same(before));
      expect(source.requests, hasLength(1));
    }
  });

  test('manual prepend invalidates conflicting request; empty prepend does not',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final pending = chart.retryHistory();
    chart.prependHistory(const [], session: chart.session);
    expect(chart.retryHistory(), same(pending));
    chart.prependHistory(all.sublist(10, 20), session: chart.session);
    await pending;
    final before = chart.value;
    source.complete(0, page());
    await _flush();
    expect(chart.value, same(before));
    expect(chart.value.data.data, hasLength(30));
  });

  test('invalid replacement leaves an in-flight history request intact',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final pending = chart.retryHistory();
    final before = chart.value;
    expect(
      () => chart.replaceData(current.reversed, session: chart.session),
      throwsArgumentError,
    );
    expect(chart.value, same(before));
    expect(chart.retryHistory(), same(pending));
    source.complete(0, page());
    await pending;
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
  });

  test(
      'detach cancels logical request; remount gets new id and ignores old error',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final pending = chart.retryHistory();
    chart.detach(Object());
    expect(chart.retryHistory(), same(pending));
    chart.detach(owner);
    await pending;
    expect(chart.value.history.phase, KChartHistoryPhase.idle);
    await _flush();
    expect(source.requests, hasLength(1));
    chart.attach(owner);
    await _flush();
    expect(source.requests, hasLength(2));
    final before = chart.value;
    source.fail(0, StateError('detached'));
    await _flush();
    expect(chart.value, same(before));
    source.complete(1, page());
    await _flush();
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
  });

  test('dispose cancels pending work and safely consumes late errors',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final pending = chart.retryHistory();
    chart.dispose();
    await pending;
    final before = chart.value;
    source.fail(0, StateError('late failure'));
    await _flush();
    expect(chart.value, same(before));
    expect(chart.retryHistory, throwsStateError);
  });

  test('loading listener can dispose before host loader is invoked', () async {
    final source = _HistorySource();
    final chart = create(source.load);
    chart.addListener(() {
      if (chart.value.history.phase == KChartHistoryPhase.loading) {
        chart.dispose();
      }
    });
    await chart.retryHistory();
    await _flush();
    expect(source.requests, isEmpty);
    expect(chart.isDisposed, isTrue);
  });

  test(
      'continued history stops when prepending moves the viewport past threshold',
      () async {
    final source = _HistorySource();
    final chart = create(source.load);
    await _flush();
    expect(source.requests, hasLength(1));
    source.complete(
      0,
      KChartHistoryPage(candles: all.sublist(19, 20), hasMore: true),
    );
    await _flush();
    expect(source.requests, hasLength(2));
    expect(source.requests[1].beforeOpenTime, all[19].openTime);
    source.complete(
      1,
      KChartHistoryPage(candles: all.sublist(10, 19), hasMore: true),
    );
    await _flush();
    expect(source.requests, hasLength(2));
    expect(chart.value.history.phase, KChartHistoryPhase.idle);
    chart.applyViewport(
      chart.value.viewport.copyWith(
        scrollOffsetItems: chart.value.viewport.maxScrollOffsetItems,
      ),
    );
    await _flush();
    expect(source.requests, hasLength(3));
    source.complete(2, KChartHistoryPage(candles: const [], hasMore: false));
    await _flush();
  });

  test(
      'explicit retry works away from edge and different charts do not share requests',
      () async {
    final source = _HistorySource();
    final first = create(source.load, offset: 0);
    final second = create(source.load, offset: 0);
    final one = first.retryHistory();
    final two = second.retryHistory();
    expect(source.requests, hasLength(2));
    expect(source.requests[0].session, isNot(same(source.requests[1].session)));
    source.complete(1, page());
    await two;
    expect(first.value.history.phase, KChartHistoryPhase.loading);
    source.complete(0, page());
    await one;
    expect(first.value.history.phase, KChartHistoryPhase.exhausted);
  });

  test('history prefetch threshold rejects invalid values', () {
    for (final threshold in [-1.0, double.nan, double.infinity]) {
      expect(
        () => KChartDataCoordinator(
          series: series,
          historyThresholdItems: threshold,
        ),
        throwsArgumentError,
      );
    }
  });

  test('queued automatic load rechecks mount before calling host', () async {
    final source = _HistorySource();
    final chart = create(source.load);
    chart.detach(owner);
    await _flush();
    expect(source.requests, isEmpty);
    chart.attach(owner);
    chart.dispose();
    await _flush();
    expect(source.requests, isEmpty);
  });

  test('loading listener can replace series before host invocation', () async {
    final source = _HistorySource();
    final chart = create(source.load);
    final oldSession = chart.session;
    chart.addListener(() {
      if (chart.value.history.phase == KChartHistoryPhase.loading) {
        chart.beginSeries(series);
      }
    });
    await chart.retryHistory();
    await _flush();
    expect(source.requests, isEmpty);
    expect(chart.session, isNot(same(oldSession)));
    expect(chart.value.history.phase, KChartHistoryPhase.idle);
    expect(chart.value.data.data, isEmpty);
  });

  test('live insertion that changes first candle invalidates history cursor',
      () async {
    final source = _HistorySource();
    final chart = create(source.load, data: all.sublist(20, 22), width: 8);
    final pending = chart.retryHistory();
    chart.updateKline(all[19], session: chart.session);
    await pending;
    await _flush();
    expect(source.requests, hasLength(2));
    expect(source.requests.last.beforeOpenTime, all[19].openTime);
    final active = chart.value.history.request;
    source.complete(0, page());
    await _flush();
    expect(chart.value.history.request, same(active));
    expect(chart.value.data.data, hasLength(3));
    source.complete(
      1,
      KChartHistoryPage(candles: all.sublist(10, 19), hasMore: false),
    );
    await _flush();
    expect(chart.value.data.data, hasLength(12));
    expect(chart.value.history.phase, KChartHistoryPhase.exhausted);
  });
}

/// 可控的宿主加载器：每个请求独立完成，稳定复现倒序返回和卸载后回调。
final class _HistorySource {
  final requests = <KChartHistoryRequest>[];
  final _responses = <Completer<KChartHistoryPage>>[];

  Future<KChartHistoryPage> load(KChartHistoryRequest request) {
    requests.add(request);
    final response = Completer<KChartHistoryPage>();
    _responses.add(response);
    return response.future;
  }

  void complete(int index, KChartHistoryPage page) =>
      _responses[index].complete(page);
  void fail(int index, Object error) => _responses[index].completeError(error);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
