import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/renderer/legacy_chart_viewport.dart';
import 'package:m_k_chart/src/viewport/chart_viewport.dart';

void main() {
  test('legacy viewport derives scroll bounds without shared Painter state',
      () {
    final metrics = LegacyChartViewportMetrics(
      itemCount: 100,
      width: 200,
      scaleX: 1,
      pointWidth: 10,
    );

    expect(metrics.minTranslateX, -835);
    expect(metrics.maxScrollX, 835);
    expect(metrics.trailingPaddingItems, 3.5);
    expect(metrics.clampScrollX(-1), 0);
    expect(metrics.clampScrollX(1000), 835);
  });

  test('legacy trailing padding preserves scaled latest-candle position', () {
    final metrics = LegacyChartViewportMetrics(
      itemCount: 100,
      width: 200,
      scaleX: 2,
      pointWidth: 10,
    );

    expect(metrics.trailingPaddingItems, 2);
    expect(metrics.localXForIndex(99, scrollX: 0), 150);
    expect(
      200 - metrics.localXForIndex(99, scrollX: 0),
      (metrics.trailingPaddingItems + 0.5) * 20,
    );
  });

  test('V2 trailing slots reproduce legacy positions at every scroll point',
      () {
    for (final values in <(int, double, double, double)>[
      (100, 200, 1, 10),
      (100, 200, 2, 10),
      (30, 375, 0.75, 8),
      (5, 400, 1, 10),
    ]) {
      final (itemCount, width, scaleX, pointWidth) = values;
      final legacy = LegacyChartViewportMetrics(
        itemCount: itemCount,
        width: width,
        scaleX: scaleX,
        pointWidth: pointWidth,
      );
      final extent = pointWidth * scaleX;
      final scrollValues = <double>[
        0,
        legacy.maxScrollX / 2,
        legacy.maxScrollX,
      ];

      for (final legacyScrollX in scrollValues) {
        final viewport = ChartViewport(
          itemCount: itemCount,
          width: width,
          itemExtent: extent,
          minItemExtent: 0.01,
          maxItemExtent: 100,
          trailingPaddingItems: legacy.trailingPaddingItems,
          scrollOffsetItems: legacyScrollX / pointWidth,
        );
        final v2LatestX =
            (itemCount - 0.5 - viewport.visibleLeftDataPosition) * extent;

        expect(
          v2LatestX,
          closeTo(
            legacy.localXForIndex(
              itemCount - 1,
              scrollX: legacyScrollX,
            ),
            1e-9,
          ),
          reason: 'inputs=$values, legacyScrollX=$legacyScrollX',
        );
      }
    }
  });

  test('legacy viewport selects data from chart-local coordinates', () {
    final metrics = LegacyChartViewportMetrics(
      itemCount: 100,
      width: 200,
      scaleX: 1,
      pointWidth: 10,
    );

    expect(metrics.selectedIndex(localX: 100, scrollX: 0), 93);
    expect(metrics.selectedIndex(localX: 100, scrollX: metrics.maxScrollX), 10);
    expect(metrics.selectedIndex(localX: -10000, scrollX: 0), 0);
    expect(metrics.selectedIndex(localX: 10000, scrollX: 0), 99);
  });

  test('legacy viewport has stable empty and undersized-data fallbacks', () {
    final empty = LegacyChartViewportMetrics(
      itemCount: 0,
      width: 200,
      scaleX: 1,
      pointWidth: 10,
    );
    final short = LegacyChartViewportMetrics(
      itemCount: 5,
      width: 400,
      scaleX: 1,
      pointWidth: 10,
    );

    expect(empty.maxScrollX, 0);
    expect(empty.selectedIndex(localX: 20, scrollX: 0), 0);
    expect(short.maxScrollX, 0);
    expect(short.localXForIndex(4, scrollX: 0), 45);
  });
}
