import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('ChartNavigationMachine inertia', () {
    test('decelerates from release velocity and stops deterministically', () {
      final machine = ChartNavigationMachine(
        decelerationLocalXPerSecondSquared: 800,
        minimumVelocityLocalXPerSecond: 10,
      );
      final viewport = _viewport(scrollOffsetItems: 20);

      expect(
        machine.startInertia(
          viewport: viewport,
          velocityLocalXPerSecond: 400,
        ),
        isTrue,
      );
      final first = machine.advanceInertia(const Duration(milliseconds: 100));
      final finalIntent =
          machine.advanceInertia(const Duration(milliseconds: 1000));

      expect(first!.viewport.scrollOffsetItems, closeTo(24.5, 1e-12));
      expect(finalIntent!.viewport.scrollOffsetItems, closeTo(32.5, 1e-12));
      expect(machine.isInertiaActive, isFalse);
      expect(machine.advanceInertia(const Duration(milliseconds: 16)), isNull);
    });

    test('rejects weak or outward velocity and stops at boundaries', () {
      final machine = ChartNavigationMachine(
        minimumVelocityLocalXPerSecond: 50,
      );

      expect(
        machine.startInertia(
          viewport: _viewport(scrollOffsetItems: 20),
          velocityLocalXPerSecond: 20,
        ),
        isFalse,
      );
      expect(
        machine.startInertia(
          viewport: _viewport(scrollOffsetItems: 0),
          velocityLocalXPerSecond: -500,
        ),
        isFalse,
      );

      machine.startInertia(
        viewport: _viewport(scrollOffsetItems: 1),
        velocityLocalXPerSecond: -500,
      );
      final bounded = machine.advanceInertia(const Duration(milliseconds: 500));
      expect(bounded!.viewport.isAtLatest, isTrue);
      expect(machine.isInertiaActive, isFalse);
    });

    test('continues through latest and stops at the configured future limit',
        () {
      final machine = ChartNavigationMachine(
        decelerationLocalXPerSecondSquared: 800,
        minimumVelocityLocalXPerSecond: 10,
      );
      final viewport = _viewport(scrollOffsetItems: 0).copyWith(
        futurePaddingItems: 5,
      );

      expect(
        machine.startInertia(
          viewport: viewport,
          velocityLocalXPerSecond: -400,
        ),
        isTrue,
      );
      final bounded = machine.advanceInertia(const Duration(seconds: 1));

      expect(bounded!.viewport.scrollOffsetItems, -5);
      expect(bounded.viewport.isAtFutureLimit, isTrue);
      expect(machine.isInertiaActive, isFalse);

      final shortDataViewport = ChartViewport(
        itemCount: 5,
        width: 160,
        itemExtent: 8,
        futurePaddingItems: 5,
      );
      expect(shortDataViewport.maxScrollOffsetItems, 0);
      expect(
        machine.startInertia(
          viewport: shortDataViewport,
          velocityLocalXPerSecond: -400,
        ),
        isTrue,
      );
    });

    test('validates configuration and velocity', () {
      expect(
        () => ChartNavigationMachine(
          decelerationLocalXPerSecondSquared: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartNavigationMachine(
          minimumVelocityLocalXPerSecond: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartNavigationMachine().startInertia(
          viewport: _viewport(),
          velocityLocalXPerSecond: double.infinity,
        ),
        throwsArgumentError,
      );
      final machine = ChartNavigationMachine()
        ..startInertia(
          viewport: _viewport(),
          velocityLocalXPerSecond: 500,
        );
      expect(
        () => machine.advanceInertia(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
    });
  });

  group('ChartViewportNavigator', () {
    test('returns to latest and locates an irregular timestamp', () {
      final data = _data([0, 60000, 180000, 240000, 300000]);
      final viewport = ChartViewport(
        itemCount: 5,
        width: 16,
        itemExtent: 8,
        trailingPaddingItems: 2,
        scrollOffsetItems: 2,
      );

      expect(ChartViewportNavigator.toLatest(viewport).isAtLatest, isTrue);
      final located = ChartViewportNavigator.locateTime(
        viewport: viewport,
        data: data,
        epochMilliseconds: 120000,
      );
      final transform = ChartXTransform(viewport: located, data: data);

      expect(transform.timeToLocalX(120000), closeTo(8, 1e-12));
    });

    test('supports alignment boundaries and clamps timeline endpoints', () {
      final data = _data(List.generate(20, (index) => index * 60000));
      final viewport = ChartViewport(
        itemCount: 20,
        width: 40,
        itemExtent: 8,
      );

      final left = ChartViewportNavigator.locateTime(
        viewport: viewport,
        data: data,
        epochMilliseconds: 10 * 60000,
        alignment: 0,
      );
      expect(
        ChartXTransform(viewport: left, data: data).timeToLocalX(10 * 60000),
        closeTo(0, 1e-12),
      );
      expect(
        () => ChartViewportNavigator.locateTime(
          viewport: viewport,
          data: data,
          epochMilliseconds: 0,
          alignment: 2,
        ),
        throwsArgumentError,
      );
    });

    test('preserves visible candle positions after historical prepend', () {
      final before = _viewport(scrollOffsetItems: 90);
      final after = ChartViewportNavigator.preserveAfterPrepend(
        before,
        prependedItemCount: 20,
      );

      expect(after.itemCount, 120);
      expect(after.scrollOffsetItems, 90);
      expect(
        after.visibleLeftDataPosition,
        before.visibleLeftDataPosition + 20,
      );
      expect(
        () => ChartViewportNavigator.preserveAfterPrepend(
          before,
          prependedItemCount: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ChartHistoryPagingState', () {
    test('loads near oldest, suppresses duplicates, fails, and retries', () {
      const initial = ChartHistoryPagingState();
      final away = initial.requestIfNeeded(
        _viewport(scrollOffsetItems: 20),
      );
      final loading = initial.requestIfNeeded(
        _viewport(scrollOffsetItems: 89),
      );

      expect(identical(away, initial), isTrue);
      expect(loading.phase, ChartHistoryPagingPhase.loading);
      expect(loading.requestSerial, 1);
      expect(identical(loading.requestIfNeeded(_viewport()), loading), isTrue);

      final failure = loading.fail();
      final retry = failure.requestIfNeeded(_viewport(scrollOffsetItems: 90));
      expect(failure.phase, ChartHistoryPagingPhase.failure);
      expect(failure.failureCount, 1);
      expect(retry.phase, ChartHistoryPagingPhase.loading);
      expect(retry.requestSerial, 2);
    });

    test('publishes idle or terminal noMore completion', () {
      final loading = const ChartHistoryPagingState().requestIfNeeded(
        _viewport(scrollOffsetItems: 90),
      );
      final idle = loading.complete(hasMore: true);
      final noMore = loading.complete(hasMore: false);

      expect(idle.phase, ChartHistoryPagingPhase.idle);
      expect(noMore.phase, ChartHistoryPagingPhase.noMore);
      expect(noMore.canRequest, isFalse);
      expect(identical(noMore.requestIfNeeded(_viewport()), noMore), isTrue);
      expect(noMore.reset(), const ChartHistoryPagingState());
    });
  });

  test('ChartOhlcSnapper chooses candle center and nearest OHLC value', () {
    final data = _data([0, 60000, 120000]);
    final viewport = ChartViewport(itemCount: 3, width: 24, itemExtent: 8);
    final prices = ChartPriceTransform(
      minPrice: 90,
      maxPrice: 110,
      top: 0,
      bottom: 200,
    );

    final result = ChartOhlcSnapper.snap(
      data: data,
      viewport: viewport,
      priceTransform: prices,
      localX: 9,
      localY: prices.priceToLocalY(103),
    );
    final intent = ChartCrosshairIntent.snapped(result);

    expect(result.dataIndex, 1);
    expect(result.localX, 12);
    expect(result.field, ChartOhlcField.high);
    expect(result.price, 103);
    expect(intent.state.isSnapped, isTrue);
    expect(intent.state.dataIndex, 1);
  });
}

ChartViewport _viewport({double scrollOffsetItems = 10}) => ChartViewport(
      itemCount: 100,
      width: 80,
      itemExtent: 8,
      scrollOffsetItems: scrollOffsetItems,
    );

_StableData _data(List<int> openTimes) => _StableData([
      for (var index = 0; index < openTimes.length; index++)
        Kline(
          symbol: 'BTCUSDT',
          interval: KlineInterval.oneMinute,
          openTime: openTimes[index],
          closeTime: openTimes[index] + 59999,
          open: 100 + index.toDouble(),
          high: 102 + index.toDouble(),
          low: 99 + index.toDouble(),
          close: 101 + index.toDouble(),
          baseVolume: 10,
          quoteVolume: 1000,
          tradeCount: 20,
          isClosed: true,
        ),
    ]);

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
