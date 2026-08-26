import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/chart_layer_geometry.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  test('main range merges visible OHLC and included indicator values', () {
    final snapshot = _snapshot(
      data: [_kline(low: 90, high: 110)],
      indicators: [
        _indicator(
          instanceId: 'main',
          panelId: 'main',
          placement: IndicatorPlacement.mainChart,
          values: const {
            'included': [120],
            'excluded': [1000],
          },
          excludedSeriesId: 'excluded',
        ),
      ],
    );

    final range = ChartLayerGeometry.rangeFor(snapshot, 'main');

    expect(range.min, closeTo(88.5, 1e-12));
    expect(range.max, closeTo(121.5, 1e-12));
  });

  test('secondary range honors includeZero and excluded Series', () {
    final snapshot = _snapshot(
      data: [_kline(low: 90, high: 110), _kline(low: 91, high: 111)],
      indicators: [
        _indicator(
          instanceId: 'secondary',
          panelId: 'secondary',
          placement: IndicatorPlacement.separatePanel,
          values: const {
            'included': [-2, 4],
            'excluded': [-100, 100],
          },
          excludedSeriesId: 'excluded',
          includeZero: true,
        ),
      ],
    );

    final range = ChartLayerGeometry.rangeFor(snapshot, 'secondary');

    expect(range.min, closeTo(-2.3, 1e-12));
    expect(range.max, closeTo(4.3, 1e-12));
  });

  test('line and area range use visible closes without main indicators', () {
    for (final mode in [ChartMainMode.line, ChartMainMode.area]) {
      final snapshot = _snapshot(
        data: [
          _kline(low: 50, high: 150, close: 100),
          _kline(low: 40, high: 160, close: 110),
        ],
        mainMode: mode,
        indicators: [
          _indicator(
            instanceId: 'main',
            panelId: 'main',
            placement: IndicatorPlacement.mainChart,
            values: const {
              'included': [1000, 1100],
            },
          ),
        ],
      );

      final range = ChartLayerGeometry.rangeFor(snapshot, 'main');
      final extrema = ChartLayerGeometry.visibleMainExtrema(snapshot)!;

      expect(range.min, closeTo(99.5, 1e-12));
      expect(range.max, closeTo(110.5, 1e-12));
      expect(extrema.min, 100);
      expect(extrema.max, 110);
      expect(extrema.minIndex, 0);
      expect(extrema.maxIndex, 1);
    }
  });

  test('Heikin-Ashi range and extrema use the projected candle values', () {
    final source = [
      _kline(open: 100, high: 120, low: 90, close: 110),
      _kline(open: 110, high: 130, low: 100, close: 120),
    ];
    final snapshot = _snapshot(
      data: source,
      mainMode: ChartMainMode.heikinAshi,
    );
    final projection = ChartCandleProjection.fromKlines(
      source: source,
      mode: ChartMainMode.heikinAshi,
    );

    final extrema = ChartLayerGeometry.visibleMainExtrema(
      snapshot,
      candles: projection,
    )!;
    final range = ChartLayerGeometry.rangeFor(
      snapshot,
      'main',
      mainExtrema: extrema,
    );

    expect(extrema.min, projection.candles.first.low);
    expect(extrema.max, projection.candles.last.high);
    expect(range.min, closeTo(88, 1e-12));
    expect(range.max, closeTo(132, 1e-12));
  });

  test('flat and empty panels produce finite deterministic fallback ranges',
      () {
    final flat = _snapshot(data: [_kline(low: 100, high: 100)]);
    final empty = _snapshot(data: const []);

    final flatRange = ChartLayerGeometry.rangeFor(flat, 'main');
    final emptyRange = ChartLayerGeometry.rangeFor(empty, 'secondary');

    expect(flatRange.min, 99);
    expect(flatRange.max, 101);
    expect(emptyRange.min, 0);
    expect(emptyRange.max, 1);
  });
}

RenderSnapshot<_Theme> _snapshot({
  required List<Kline> data,
  List<RenderIndicatorSnapshot> indicators = const [],
  ChartMainMode mainMode = ChartMainMode.candlestick,
}) {
  final stable = _StableData(UnmodifiableListView(data));
  final layout = ChartLayoutModel(
    width: 180,
    height: 240,
    bottomAxisHeight: 20,
    panelSpacing: 4,
    mainPanel: const ChartPanelSpec.main(minHeight: 100),
    secondaryPanels: const [
      ChartPanelSpec.secondary(id: 'secondary', minHeight: 60),
    ],
  );
  return RenderSnapshot<_Theme>(
    data: stable,
    viewport: ChartViewport(
      itemCount: data.length,
      width: layout.drawingBounds.width,
      itemExtent: 30,
    ),
    layout: layout,
    theme: const _Theme(),
    versions: const RenderSnapshotVersions(),
    indicators: indicators,
    mainMode: mainMode,
  );
}

RenderIndicatorSnapshot _indicator({
  required String instanceId,
  required String panelId,
  required IndicatorPlacement placement,
  required Map<String, List<double?>> values,
  String? excludedSeriesId,
  bool includeZero = false,
}) =>
    RenderIndicatorSnapshot.fromResult(
      result: IndicatorResult(
        instanceId: instanceId,
        definitionId: 'test',
        dataVersion: KlineDataVersion.zero,
        length: values.values.first.length,
        series: [
          for (final entry in values.entries)
            IndicatorSeries(id: entry.key, values: entry.value),
        ],
      ),
      descriptor: IndicatorRendererDescriptor(
        placement: placement,
        includeZeroInRange: includeZero,
        series: [
          for (final id in values.keys)
            IndicatorSeriesDescriptor(
              id: id,
              label: id,
              drawingKind: IndicatorDrawingKind.line,
              includeInRange: id != excludedSeriesId,
            ),
        ],
      ),
      panelId: panelId,
    );

Kline _kline({
  required double low,
  required double high,
  double? open,
  double? close,
}) =>
    Kline(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      openTime: 1704067200000,
      closeTime: 1704067259999,
      open: open ?? low,
      high: high,
      low: low,
      close: close ?? high,
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

final class _Theme {
  const _Theme();
}
