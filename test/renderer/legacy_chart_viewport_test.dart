import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/renderer/legacy_chart_viewport.dart';

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
    expect(metrics.clampScrollX(-1), 0);
    expect(metrics.clampScrollX(1000), 835);
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
