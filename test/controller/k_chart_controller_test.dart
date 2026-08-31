import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('KChartController', () {
    test('publishes one notification for one non-empty transaction', () {
      final controller = KChartController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatchBatch([
        const ChartDataChanged(),
        ChartViewportChanged(ChartViewport(width: 80)),
        const ChartDataChanged(),
      ]);

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.data), 1);
      expect(controller.value.versionOf(StateSlice.viewport), 1);
      expect(notifications, 1);
    });

    test('does not notify for an empty transaction', () {
      final controller = KChartController();
      final before = controller.value;
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatchBatch(const []);

      expect(identical(controller.value, before), isTrue);
      expect(notifications, 0);
    });

    test('keeps runtime state isolated per chart instance', () {
      final first = KChartController();
      final second = KChartController();

      first.dispatch(
        ChartViewportChanged(
          ChartViewport(itemCount: 100, width: 80).scrollByItems(10),
        ),
      );

      expect(first.value.revision, 1);
      expect(first.value.viewport.scrollOffsetItems, 10);
      expect(second.value.revision, 0);
      expect(second.value.viewport, const ChartViewport.initial());
    });

    test('skips equal viewport payloads and commits the last batch value', () {
      final initial = ChartViewport(itemCount: 100, width: 80);
      final controller = KChartController(
        initialState: KChartState(viewport: initial),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatch(ChartViewportChanged(initial));
      controller.dispatchBatch([
        ChartViewportChanged(initial.scrollByItems(2)),
        ChartViewportChanged(initial.scrollByItems(4)),
      ]);

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.viewport), 1);
      expect(controller.value.viewport.scrollOffsetItems, 4);
      expect(notifications, 1);
    });

    test('keeps layout payload atomic and skips structurally equal values', () {
      final initial = ChartLayoutModel(width: 200, height: 160);
      final controller = KChartController(
        initialState: KChartState(
          layout: initial,
          viewport: ChartViewport(width: 200),
        ),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatch(
        ChartLayoutChanged(ChartLayoutModel(width: 200, height: 160)),
      );
      controller.dispatchBatch([
        ChartLayoutChanged(ChartLayoutModel(width: 240, height: 160)),
        ChartLayoutChanged(ChartLayoutModel(width: 280, height: 160)),
      ]);

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.layout), 1);
      expect(controller.value.versionOf(StateSlice.viewport), 1);
      expect(controller.value.layout?.width, 280);
      expect(controller.value.viewport.width, 280);
      expect(notifications, 1);
    });

    test('height-only layout changes do not invalidate viewport', () {
      final initial = ChartLayoutModel(width: 200, height: 160);
      final controller = KChartController(
        initialState: KChartState(
          layout: initial,
          viewport: ChartViewport(width: 200),
        ),
      );

      controller.dispatch(
        ChartLayoutChanged(ChartLayoutModel(width: 200, height: 180)),
      );

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.layout), 1);
      expect(controller.value.versionOf(StateSlice.viewport), 0);
      expect(controller.value.viewport.width, 200);
    });

    test('reduces interaction intents into typed state slices', () {
      final controller = KChartController();
      final viewport = ChartViewport(itemCount: 100, width: 80);

      controller.dispatchInteraction(ChartViewportIntent(viewport));
      controller.dispatchInteraction(
        const ChartCrosshairIntent.show(localX: 12, localY: 34),
      );
      controller.dispatchInteraction(
        const ChartHistoryPagingIntent(
          ChartHistoryPagingState(
            phase: ChartHistoryPagingPhase.loading,
            requestSerial: 1,
          ),
        ),
      );

      expect(controller.value.revision, 3);
      expect(controller.value.viewport, viewport);
      expect(controller.value.crosshair.isVisible, isTrue);
      expect(controller.value.crosshair.localX, 12);
      expect(controller.value.versionOf(StateSlice.viewport), 1);
      expect(controller.value.versionOf(StateSlice.selection), 1);
      expect(controller.value.historyPaging.isLoading, isTrue);
      expect(controller.value.versionOf(StateSlice.history), 1);
    });

    test('provides latest, time-location, and viewport-anchor commands', () {
      final data = _StableData([
        for (var index = 0; index < 20; index++) _kline(index * 60000),
      ]);
      final controller = KChartController(
        initialState: KChartState(
          viewport: ChartViewport(
            itemCount: 20,
            width: 40,
            itemExtent: 8,
            scrollOffsetItems: 10,
          ),
        ),
      );

      controller.scrollToLatest();
      expect(controller.value.viewport.isAtLatest, isTrue);
      controller.scrollToTime(
        data: data,
        epochMilliseconds: 10 * 60000,
      );
      final beforePrepend = controller.value.viewport;
      expect(
        ChartXTransform(viewport: beforePrepend, data: data)
            .timeToLocalX(10 * 60000),
        closeTo(20, 1e-12),
      );

      controller.preserveViewportAfterPrepend(prependedItemCount: 5);
      expect(controller.value.viewport.itemCount, 25);
      expect(
        controller.value.viewport.visibleLeftDataPosition,
        beforePrepend.visibleLeftDataPosition + 5,
      );

      final beforeRealtime = controller.value.viewport;
      controller.preserveViewportAfterRealtimeDataChange(
        nextItemCount: 26,
        appendedItemCount: 1,
      );
      expect(controller.value.viewport.itemCount, 26);
      expect(
        controller.value.viewport.visibleLeftDataPosition,
        beforeRealtime.visibleLeftDataPosition,
      );
    });

    test('coordinates historical request, failure, retry, and completion', () {
      final controller = KChartController(
        initialState: KChartState(
          viewport: ChartViewport(
            itemCount: 100,
            width: 80,
            itemExtent: 8,
            scrollOffsetItems: 90,
          ),
        ),
      );

      expect(controller.requestHistoryIfNeeded(), isTrue);
      expect(controller.requestHistoryIfNeeded(), isFalse);
      controller.failHistoryRequest();
      expect(controller.value.historyPaging.failureCount, 1);
      expect(controller.requestHistoryIfNeeded(), isTrue);
      expect(controller.value.historyPaging.requestSerial, 2);
      controller.completeHistoryRequest(hasMore: false);
      expect(controller.value.historyPaging.hasNoMore, isTrue);
      controller.resetHistoryPaging();
      expect(controller.value.historyPaging, const ChartHistoryPagingState());
    });

    test('supports a caller-provided initial snapshot', () {
      const initial = KChartState(
        revision: 4,
        versions: StateSliceVersions(data: 3, viewport: 1),
      );

      final controller = KChartController(initialState: initial);

      expect(identical(controller.value, initial), isTrue);
    });

    test('dispose is idempotent and rejects later mutations', () {
      final controller = KChartController();

      controller.dispose();
      controller.dispose();

      expect(controller.isDisposed, isTrue);
      expect(
        () => controller.dispatch(const ChartDataChanged()),
        throwsStateError,
      );
      expect(controller.requestHistoryIfNeeded, throwsStateError);
    });
  });
}

Kline _kline(int openTime) => Kline(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      openTime: openTime,
      closeTime: openTime + 59999,
      open: 100,
      high: 102,
      low: 99,
      close: 101,
      baseVolume: 10,
      quoteVolume: 1000,
      tradeCount: 20,
      isClosed: true,
    );

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
