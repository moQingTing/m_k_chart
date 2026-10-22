import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_data_contract.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../contracts/fixtures/v2_host_compile_probe.dart' as host;
import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(40);
  final series = KlineSeries.fromKline(candles.first);
  final other = buildV2KlineFixture(40, symbol: 'ETHUSDT');
  final otherSeries = KlineSeries.fromKline(other.first);

  KChartDataCoordinator create({List<Kline>? data, double width = 80}) {
    final chart = KChartDataCoordinator(
      series: series,
      initialData: data ?? candles,
      initialViewport: ChartViewport(width: width, futurePaddingItems: 10),
      panelIds: const ['main', 'macd'],
    );
    addTearDown(chart.dispose);
    return chart;
  }

  void select(KChartDataCoordinator chart, int index, {String panel = 'main'}) {
    chart.select(
      openTime: chart.value.data.data[index].openTime,
      panelId: panel,
      price: 1000,
    );
  }

  double xOf(KChartDataCoordinator chart, int time) => ChartXTransform(
        viewport: chart.value.viewport,
        data: chart.value.data,
      ).timeToLocalX(time);

  test('snapshots own immutable data and panels; each update commits once', () {
    final input = List<Kline>.of(candles);
    final chart = create(data: input);
    final before = chart.value;
    input.clear();
    expect(before.data.data, hasLength(40));
    expect(() => before.data.data.clear(), throwsUnsupportedError);
    expect(() => before.panelIds.clear(), throwsUnsupportedError);
    var calls = 0;
    chart.addListener(() {
      calls++;
      expect(chart.value.viewport.itemCount, chart.value.data.data.length);
      expect(chart.value.selectedCandle?.openTime, candles.last.openTime);
    });
    select(chart, 39);
    final selected = chart.value;
    final updated = candles.last.copyWith(close: candles.last.close + 0.1);
    final receipt = chart.updateKline(updated, session: chart.session);
    expect(calls, 2);
    expect(receipt.changed, isTrue);
    expect(chart.value.selectedCandle, updated);
    expect(chart.value.previousSelectedCandle, candles[38]);
    expect(selected.selectedCandle, candles.last);
    expect(before.selection, isNull);
    expect(chart.value.selection, same(selected.selection));
  });

  test('duplicate and empty batches preserve fractional viewport and identity',
      () {
    final chart = create();
    chart
        .applyViewport(chart.value.viewport.copyWith(scrollOffsetItems: 7.123));
    select(chart, 35);
    final before = chart.value;
    var calls = 0;
    chart.addListener(() => calls++);
    expect(chart.replaceData(candles, session: chart.session).changed, isFalse);
    chart.appendData(const [], session: chart.session);
    chart.prependHistory(const [], session: chart.session);
    chart.updateKline(candles.last, session: chart.session);
    chart.setPanels(const ['main', 'macd']);
    select(chart, 35);
    expect(chart.value, same(before));
    expect(calls, 0);
  });

  test('proven incremental changes advance once and keep old snapshots', () {
    final chart = create(data: candles.sublist(1, 39));
    final initial = chart.value.data;
    final appended = chart.appendData([candles[39]], session: chart.session);
    final afterAppend = chart.value.data;
    expect(appended.dataRevision, initial.version.next().value);
    expect(initial.data, hasLength(38));
    expect(chart.appendData(const [], session: chart.session).changed, isFalse);
    expect(chart.value.data, same(afterAppend));

    final updated = candles[39].copyWith(close: candles[39].close + 0.1);
    final update = chart.updateKline(
      updated,
      session: chart.session,
      allowClosedCorrection: true,
    );
    final afterUpdate = chart.value.data;
    expect(update.dataRevision, afterAppend.version.next().value);
    expect(afterAppend.data.last, candles[39]);
    expect(chart.value.data.data.last, updated);

    final prepended =
        chart.prependHistory([candles.first], session: chart.session);
    expect(prepended.dataRevision, afterUpdate.version.next().value);
    expect(afterUpdate.data.first, candles[1]);
    expect(chart.value.data.data.first, candles.first);
  });

  test('append follows latest but preserves historical and future anchors', () {
    for (final offset in [0.0, 7.25, -4.5]) {
      final chart = create();
      chart.applyViewport(
        chart.value.viewport.copyWith(scrollOffsetItems: offset),
      );
      select(chart, 35);
      final x = xOf(chart, candles[35].openTime);
      chart.appendData(
        buildV2KlineFixture(1, startIndex: 40),
        session: chart.session,
      );
      expect(chart.value.selectedIndex, 35);
      if (offset == 0) {
        expect(chart.value.viewport.isAtLatest, isTrue);
        expect(xOf(chart, candles[35].openTime), closeTo(x - 8, 1e-8));
      } else {
        expect(xOf(chart, candles[35].openTime), closeTo(x, 1e-8));
      }
    }
  });

  test('prepend and rolling replacement preserve visible time and selection',
      () {
    final chart = create(data: candles.sublist(10));
    chart.applyViewport(chart.value.viewport.copyWith(scrollOffsetItems: 8.25));
    select(chart, 15, panel: 'macd');
    final time = candles[25].openTime;
    final x = xOf(chart, time);
    chart.prependHistory(candles.sublist(0, 10), session: chart.session);
    expect(chart.value.selectedIndex, 25);
    expect(xOf(chart, time), closeTo(x, 1e-8));
    chart.replaceData(candles.sublist(5), session: chart.session);
    expect(chart.value.selectedIndex, 20);
    expect(xOf(chart, time), closeTo(x, 1e-8));
    expect(chart.value.selection?.panelId, 'macd');
    chart.replaceData(candles.sublist(30), session: chart.session);
    expect(chart.value.selection, isNull);
    expect(chart.value.viewport.scrollOffsetItems.isFinite, isTrue);
  });

  test('closed corrections and out-of-window events return stable receipts',
      () {
    final chart = create();
    select(chart, 5);
    final before = chart.value;
    final corrected = candles[5].copyWith(close: candles[5].close + 0.1);
    final rejected = chart.updateKline(corrected, session: chart.session);
    expect(rejected.status, KChartDataUpdateStatus.rejectedClosedCorrection);
    expect(chart.value, same(before));
    expect(
      chart
          .updateKline(
            corrected,
            session: chart.session,
            allowClosedCorrection: true,
          )
          .changed,
      isTrue,
    );
    expect(chart.value.selectedCandle, corrected);
    final old = buildV2KlineFixture(1, startIndex: -1).single;
    final reload = chart.updateKline(old, session: chart.session);
    expect(reload.requiresReload, isTrue);
    expect(reload.dataRevision, chart.value.data.version.value);
  });

  test('small out-of-order insertion restores selection by timestamp', () {
    final chart = create(data: [...candles.take(38), candles.last]);
    select(chart, 38);
    chart.applyViewport(chart.value.viewport.copyWith(scrollOffsetItems: -3));
    final x = xOf(chart, candles.last.openTime);
    final leftTime = candles[32].openTime;
    final leftX = xOf(chart, leftTime);
    final result = chart.updateKline(candles[38], session: chart.session);
    expect(result.changed, isTrue);
    expect(chart.value.selectedIndex, 39);
    // 可见左边缘为锚；插入点右侧的柱必须向右让出一个槽位，而不是整窗一起偏移。
    expect(xOf(chart, leftTime), closeTo(leftX, 1e-8));
    expect(xOf(chart, candles.last.openTime), closeTo(x + 8, 1e-8));
  });

  test('invalid batches and failed series changes are atomic', () {
    final chart = create();
    select(chart, 10);
    final before = chart.value;
    var calls = 0;
    chart.addListener(() => calls++);
    final invalid = <void Function()>[
      () => chart.replaceData(candles.reversed, session: chart.session),
      () => chart
          .replaceData([candles.first, candles.first], session: chart.session),
      () => chart.appendData([candles.last], session: chart.session),
      () => chart.prependHistory([candles.first], session: chart.session),
      () => chart.updateKline(other.last, session: chart.session),
      () => chart.replaceData(other, session: chart.session),
      () => chart.beginSeries(otherSeries, initialData: candles),
      () => chart.setPanels(const ['main', 'main']),
      () => chart.select(
            openTime: candles.first.openTime,
            panelId: 'missing',
            price: 1,
          ),
      () => chart.select(openTime: 0, panelId: 'main', price: 1),
      () => chart.select(
            openTime: candles.first.openTime,
            panelId: 'main',
            price: double.nan,
          ),
      () => chart.applyViewport(ChartViewport(itemCount: 1)),
      () => chart.scrollToTime(epochMilliseconds: -1),
      () => chart.scrollToTime(epochMilliseconds: 1, alignment: 2),
    ];
    for (final command in invalid) {
      expect(command, throwsArgumentError);
      expect(chart.value, same(before));
    }
    expect(calls, 0);
    expect(
      chart.updateKline(candles.last, session: before.session).status,
      KChartDataUpdateStatus.unchanged,
    );
  });

  test('stale, foreign and disposed tokens are ignored before reading payload',
      () {
    final chart = create();
    final old = chart.session;
    final foreign = create().session;
    chart.beginSeries(otherSeries, initialData: other);
    chart.beginSeries(series, initialData: candles);
    final before = chart.value;
    for (final token in [old, foreign]) {
      expect(
        chart.replaceData(_unreadable(), session: token).status,
        KChartDataUpdateStatus.ignoredStaleSession,
      );
      expect(
        chart.appendData(_unreadable(), session: token).status,
        KChartDataUpdateStatus.ignoredStaleSession,
      );
      expect(
        chart.prependHistory(_unreadable(), session: token).status,
        KChartDataUpdateStatus.ignoredStaleSession,
      );
      expect(
        chart.updateKline(other.last, session: token).status,
        KChartDataUpdateStatus.ignoredStaleSession,
      );
    }
    expect(chart.value, same(before));
    chart.dispose();
    expect(
      chart.replaceData(_unreadable(), session: before.session).status,
      KChartDataUpdateStatus.ignoredStaleSession,
    );
    expect(chart.scrollToLatest, throwsStateError);
    expect(() => chart.beginSeries(series), throwsStateError);
    expect(() => chart.addListener(() {}), throwsStateError);
    chart.dispose();
    chart.removeListener(() {});
    expect(chart.value, same(before));
  });

  test('beginSeries resets zoom and selection but keeps panel configuration',
      () {
    final chart = create();
    final old = chart.session;
    chart.applyViewport(
      chart.value.viewport.copyWith(itemExtent: 20, scrollOffsetItems: 10),
    );
    select(chart, 20, panel: 'macd');
    final next = chart.beginSeries(series, initialData: candles);
    expect(next, isNot(same(old)));
    expect(chart.value.selection, isNull);
    expect(chart.value.viewport.itemExtent, 8);
    expect(chart.value.viewport.isAtLatest, isTrue);
    expect(chart.value.panelIds, ['main', 'macd']);
  });

  test('pan and inertia clear selection; scale and layout retain it', () {
    final chart = create();
    for (final source in ChartViewportChangeSource.values) {
      select(chart, 20);
      chart.applyViewport(chart.value.viewport, source: source);
      expect(
        chart.value.selection == null,
        source == ChartViewportChangeSource.pan ||
            source == ChartViewportChangeSource.inertia,
      );
    }
  });

  test('panel reorder retains selection; removal clears it', () {
    final chart = create();
    select(chart, 20, panel: 'macd');
    chart.setPanels(const ['macd', 'main']);
    expect(chart.value.selection?.panelId, 'macd');
    chart.setPanels(const ['main']);
    expect(chart.value.selection, isNull);
  });

  test('reset policy clears selection even if replacement data is unchanged',
      () {
    final chart = create();
    select(chart, 20);
    chart.applyViewport(chart.value.viewport.copyWith(scrollOffsetItems: 7));
    final result = chart.replaceData(
      candles,
      session: chart.session,
      viewportPolicy: KChartDataViewportPolicy.resetToLatest,
    );
    expect(result.status, KChartDataUpdateStatus.unchanged);
    expect(chart.value.selection, isNull);
    expect(chart.value.viewport.isAtLatest, isTrue);
  });

  test(
      'explicit navigation clears selection and deferred location awaits layout',
      () {
    final chart = create(width: 0);
    select(chart, 20);
    chart.scrollToTime(epochMilliseconds: candles[20].openTime);
    expect(chart.value.selection, isNull);
    chart.applyViewport(chart.value.viewport.copyWith(width: 80));
    expect(xOf(chart, candles[20].openTime), closeTo(40, 1e-8));
    select(chart, 20);
    chart.scrollToLatest();
    expect(chart.value.selection, isNull);
    expect(chart.value.viewport.isAtLatest, isTrue);
    chart.applyViewport(chart.value.viewport.copyWith(itemExtent: 20));
    chart.resetViewport();
    expect(chart.value.viewport.itemExtent, 8);
  });

  test('deferred location waits for data and is cancelled by a new session',
      () {
    final chart = create(data: []);
    chart.scrollToTime(epochMilliseconds: candles[20].openTime);
    chart.replaceData(candles, session: chart.session);
    expect(xOf(chart, candles[20].openTime), closeTo(40, 1e-8));
    chart.replaceData(const [], session: chart.session);
    chart.scrollToTime(epochMilliseconds: candles[20].openTime);
    chart.beginSeries(series, initialData: candles);
    expect(chart.value.viewport.isAtLatest, isTrue);
  });

  test('user navigation cancels deferred location', () {
    final chart = create(width: 0);
    chart.scrollToTime(epochMilliseconds: candles[20].openTime);
    chart.applyViewport(
      chart.value.viewport,
      source: ChartViewportChangeSource.scale,
    );
    chart.applyViewport(chart.value.viewport.copyWith(width: 80));
    expect(chart.value.viewport.isAtLatest, isTrue);
  });

  test('one active mount per coordinator and independent chart instances', () {
    final chart = create();
    final second = create();
    final secondBefore = second.value;
    final owner = Object();
    final staleOwner = Object();
    chart.attach(owner);
    final mounted = chart.value;
    chart.attach(owner);
    chart.detach(staleOwner);
    expect(chart.value, same(mounted));
    expect(() => chart.attach(staleOwner), throwsStateError);
    chart.detach(owner);
    expect(chart.value.isAttached, isFalse);
    chart.attach(staleOwner);
    expect(chart.value.isAttached, isTrue);
    chart.replaceData(const [], session: chart.session);
    expect(second.value, same(secondBefore));
  });

  test('listener reentry does not recurse or rewrite original command receipt',
      () {
    final chart = create();
    var depth = 0;
    var calls = 0;
    final initialVersion = chart.value.data.version.value;
    chart.addListener(() {
      depth++;
      expect(depth, 1);
      calls++;
      if (calls == 1) {
        chart.appendData(
          buildV2KlineFixture(1, startIndex: 41),
          session: chart.session,
        );
      }
      expect(chart.value.viewport.itemCount, chart.value.data.data.length);
      depth--;
    });
    final result = chart.appendData(
      buildV2KlineFixture(1, startIndex: 40),
      session: chart.session,
    );
    expect(calls, 2);
    expect(result.dataRevision, initialVersion + 1);
    expect(chart.value.data.version.value, initialVersion + 2);
    expect(chart.value.data.data, hasLength(42));
  });

  test('dispose during notification is safe and invalidates late data', () {
    final chart = create();
    final token = chart.session;
    chart.addListener(chart.dispose);
    chart.appendData(buildV2KlineFixture(1, startIndex: 40), session: token);
    expect(chart.isDisposed, isTrue);
    expect(
      chart.appendData(_unreadable(), session: token).status,
      KChartDataUpdateStatus.ignoredStaleSession,
    );
  });

  test('host async loader cannot replace data after switching away and back',
      () async {
    final chart = create();
    final pending = Completer<List<Kline>>();
    final request = host.loadSeries(chart, series, (_) => pending.future);
    chart.beginSeries(otherSeries, initialData: other);
    chart.beginSeries(series, initialData: candles);
    final before = chart.value;
    pending.complete(candles.take(2).toList());
    expect((await request).status, KChartDataUpdateStatus.ignoredStaleSession);
    expect(chart.value, same(before));
  });

  test('empty windows retain explicit series and accept the first live candle',
      () {
    final chart = create(data: []);
    expect(
      () => chart.updateKline(other.last, session: chart.session),
      throwsArgumentError,
    );
    expect(
      chart.updateKline(candles.last, session: chart.session).changed,
      isTrue,
    );
    select(chart, 0);
    expect(chart.value.previousSelectedCandle, isNull);
    chart.replaceData(const [], session: chart.session);
    expect(chart.value.selection, isNull);
    expect(chart.value.selectedIndex, isNull);
    expect(chart.value.viewport.itemCount, 0);
    expect(chart.session.series, series);
    expect(chart.value.data.version.value, 2);
  });

  test('constructor rejects invalid identities, panels and merge settings', () {
    expect(
      () => KChartDataCoordinator(series: series, initialData: other),
      throwsArgumentError,
    );
    expect(
      () => KChartDataCoordinator(series: series, panelIds: const []),
      throwsArgumentError,
    );
    expect(
      () =>
          KChartDataCoordinator(series: series, panelIds: const ['main', ' ']),
      throwsArgumentError,
    );
    expect(
      () => KChartDataCoordinator(series: series, maxOutOfOrderCandles: -1),
      throwsArgumentError,
    );
  });

  test(
      'listener errors are reported without rollback or skipping other listeners',
      () {
    final chart = create();
    final originalHandler = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = originalHandler);
    var calls = 0;
    chart.addListener(() => throw StateError('host callback failed'));
    chart.addListener(() => calls++);
    final result = chart.appendData(
      buildV2KlineFixture(1, startIndex: 40),
      session: chart.session,
    );
    expect(result.changed, isTrue);
    expect(chart.value.data.data, hasLength(41));
    expect(calls, 1);
    expect(errors.single.exception, isA<StateError>());
  });

  test('host stream captures its own session instead of the latest token',
      () async {
    final chart = create();
    final stream = StreamController<Kline>(sync: true);
    final results = <KChartDataUpdateResult>[];
    final errors = <Object>[];
    final subscription = host.subscribeRealtime(
      chart,
      stream.stream,
      results.add,
      (error, _) => errors.add(error),
    );
    stream.add(candles.last.copyWith(close: candles.last.close + 0.1));
    chart.beginSeries(otherSeries, initialData: other);
    final before = chart.value;
    stream.add(candles.last);
    expect(results.map((result) => result.status), [
      KChartDataUpdateStatus.applied,
      KChartDataUpdateStatus.ignoredStaleSession,
    ]);
    expect(chart.value, same(before));
    expect(errors, isEmpty);
    await subscription.cancel();
    await stream.close();
  });
}

/// 如果过期请求仍被遍历，立即失败；验证会话检查发生在任何数据工作之前。
Iterable<Kline> _unreadable() sync* {
  throw StateError('A stale payload must never be read.');
}
