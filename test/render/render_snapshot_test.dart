import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/drawing.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  test('RenderSnapshot freezes complete renderer input without data copying',
      () {
    final fixture = _fixture();
    final indicators = <RenderIndicatorSnapshot>[fixture.mainIndicator];
    final snapshot = RenderSnapshot<_Theme>(
      data: fixture.data,
      viewport: fixture.viewport,
      layout: fixture.layout,
      theme: const _Theme('dark'),
      versions: const RenderSnapshotVersions(
        data: 3,
        viewport: 5,
        layout: 2,
        theme: 1,
      ),
      indicators: indicators,
      selection: RenderSelectionSnapshot.visible(
        localX: 120,
        localY: 80,
        dataIndex: 1,
        price: 1001,
        valueKind: RenderSelectionValueKind.close,
      ),
      history: const RenderHistorySnapshot(
        phase: RenderHistoryPhase.loading,
      ),
      mainMode: ChartMainMode.area,
    );
    indicators.clear();

    expect(identical(snapshot.data, fixture.data), isTrue);
    expect(snapshot.indicators, hasLength(1));
    expect(snapshot.indicator('ma.fast'), same(fixture.mainIndicator));
    expect(snapshot.selection.isSnapped, isTrue);
    expect(snapshot.history.phase, RenderHistoryPhase.loading);
    expect(snapshot.mainMode, ChartMainMode.area);
    expect(
      () => snapshot.indicators.add(fixture.mainIndicator),
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.indicatorById.clear(),
      throwsUnsupportedError,
    );
  });

  test('indicator projection excludes private state and freezes series list',
      () {
    final result = _indicatorResult(
      version: KlineDataVersion(3),
      length: 3,
      computationState: IndicatorComputationState(
        length: 3,
        series: [
          IndicatorSeries(id: 'recursive', values: const [1, 2, 3]),
        ],
      ),
    );
    final projected = RenderIndicatorSnapshot.fromResult(
      result: result,
      descriptor: _mainDescriptor(),
      panelId: 'main',
    );

    expect(projected.series, hasLength(1));
    expect(projected.seriesById('value'), same(result.series.first));
    expect(() => projected.series.clear(), throwsUnsupportedError);
  });

  test('snapshot rejects mismatched data, viewport, layout and selection', () {
    final fixture = _fixture();

    expect(
      () => fixture.snapshot(
        viewport: fixture.viewport.copyWith(itemCount: 2),
      ),
      throwsArgumentError,
    );
    expect(
      () => fixture.snapshot(
        viewport: fixture.viewport.copyWith(width: 299),
      ),
      throwsArgumentError,
    );
    expect(
      () => fixture.snapshot(
        selection: RenderSelectionSnapshot.visible(
          localX: 1,
          localY: 2,
          dataIndex: 3,
          price: 100,
          valueKind: RenderSelectionValueKind.open,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('snapshot rejects stale, duplicate and misplaced indicator inputs', () {
    final fixture = _fixture();
    final stale = RenderIndicatorSnapshot.fromResult(
      result: _indicatorResult(
        version: KlineDataVersion(2),
        length: 3,
      ),
      descriptor: _mainDescriptor(),
      panelId: 'main',
    );
    final secondaryOnMain = RenderIndicatorSnapshot.fromResult(
      result: _indicatorResult(
        version: KlineDataVersion(3),
        length: 3,
        instanceId: 'macd.fast',
      ),
      descriptor: _secondaryDescriptor(),
      panelId: 'main',
    );

    expect(() => fixture.snapshot(indicators: [stale]), throwsArgumentError);
    expect(
      () => fixture.snapshot(
        indicators: [fixture.mainIndicator, fixture.mainIndicator],
      ),
      throwsArgumentError,
    );
    expect(
      () => fixture.snapshot(indicators: [secondaryOnMain]),
      throwsArgumentError,
    );
  });

  test('indicator projection requires descriptor and result parity', () {
    final result = _indicatorResult(
      version: KlineDataVersion(3),
      length: 3,
    );
    final mismatched = IndicatorRendererDescriptor(
      placement: IndicatorPlacement.mainChart,
      series: [
        IndicatorSeriesDescriptor(
          id: 'other',
          label: 'Other',
          drawingKind: IndicatorDrawingKind.line,
        ),
      ],
    );

    expect(
      () => RenderIndicatorSnapshot.fromResult(
        result: result,
        descriptor: mismatched,
        panelId: 'main',
      ),
      throwsArgumentError,
    );
  });

  test('selection validates local and snapped values as one immutable tuple',
      () {
    expect(
      () => RenderSelectionSnapshot.visible(
        localX: double.nan,
        localY: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => RenderSelectionSnapshot.visible(
        localX: 0,
        localY: 0,
        dataIndex: 0,
      ),
      throwsArgumentError,
    );
    expect(
      const RenderSelectionSnapshot.hidden().isVisible,
      isFalse,
    );
  });

  test('render versions map every declared snapshot slice', () {
    const versions = RenderSnapshotVersions(
      data: 1,
      viewport: 2,
      selection: 3,
      history: 4,
      layout: 5,
      theme: 6,
      drawings: 7,
      clock: 8,
    );

    expect(
      [
        for (final slice in RenderSnapshotSlice.values)
          versions.versionOf(slice),
      ],
      [1, 2, 3, 4, 5, 6, 7, 8],
    );
  });

  test('snapshot freezes versioned anchored drawings independently', () {
    final fixture = _fixture();
    final anchored = <ChartDrawing>[
      ChartDrawing(
        id: 'support',
        kind: ChartDrawingKind.horizontalLine,
        anchors: [
          ChartDrawingAnchor(
            epochMilliseconds: fixture.data.data.first.openTime,
            price: 1000,
          ),
        ],
      ),
    ];
    final snapshot = RenderSnapshot<_Theme>(
      data: fixture.data,
      viewport: fixture.viewport,
      layout: fixture.layout,
      theme: const _Theme('dark'),
      versions: const RenderSnapshotVersions(drawings: 1),
      anchoredDrawings: anchored,
    );
    anchored.clear();

    expect(snapshot.anchoredDrawing('support').id, 'support');
    expect(snapshot.anchoredDrawings, hasLength(1));
    expect(() => snapshot.anchoredDrawings.clear(), throwsUnsupportedError);
    expect(
      () => RenderSnapshot<_Theme>(
        data: fixture.data,
        viewport: fixture.viewport,
        layout: fixture.layout,
        theme: const _Theme('dark'),
        versions: const RenderSnapshotVersions(),
        anchoredDrawings: [
          snapshot.anchoredDrawings.first,
          snapshot.anchoredDrawings.first,
        ],
      ),
      throwsArgumentError,
    );
  });

  test('snapshot defaults to candlestick main mode', () {
    expect(_fixture().snapshot().mainMode, ChartMainMode.candlestick);
  });

  test('snapshot calculates minute countdown and rounds up partial seconds',
      () {
    final fixture = _fixture();
    final snapshot = RenderSnapshot<_Theme>(
      data: fixture.data,
      viewport: fixture.viewport,
      layout: fixture.layout,
      theme: const _Theme('dark'),
      versions: const RenderSnapshotVersions(clock: 1),
      currentTime: 1704067350500,
    );

    expect(snapshot.currentTime, 1704067350500);
    expect(snapshot.latestPriceCountdown, const Duration(milliseconds: 29500));
    expect(snapshot.latestPriceCountdownText, '00:30');

    final oneSecondLater = RenderSnapshot<_Theme>(
      data: fixture.data,
      viewport: fixture.viewport,
      layout: fixture.layout,
      theme: const _Theme('dark'),
      versions: const RenderSnapshotVersions(clock: 2),
      currentTime: 1704067351500,
    );
    expect(oneSecondLater.latestPriceCountdownText, '00:29');
  });

  test('snapshot formats long countdown and remains zero past the boundary',
      () {
    final fixture = _fixture();
    RenderSnapshot<_Theme> snapshotAt(int currentTime) =>
        RenderSnapshot<_Theme>(
          data: fixture.data,
          viewport: fixture.viewport,
          layout: fixture.layout,
          theme: const _Theme('dark'),
          versions: const RenderSnapshotVersions(clock: 1),
          currentTime: currentTime,
        );

    expect(snapshotAt(1704012480000).latestPriceCountdownText, '15:15:00');
    expect(snapshotAt(1704067380000).latestPriceCountdownText, '00:00');
    expect(snapshotAt(1704067440000).latestPriceCountdownText, '00:00');

    final nextData = _StableData(
      UnmodifiableListView(buildV2KlineFixture(4)),
      KlineDataVersion(4),
    );
    final nextCandle = RenderSnapshot<_Theme>(
      data: nextData,
      viewport: fixture.viewport.copyWith(itemCount: 4),
      layout: fixture.layout,
      theme: const _Theme('dark'),
      versions: const RenderSnapshotVersions(data: 1, clock: 2),
      currentTime: 1704067380000,
    );
    expect(nextCandle.latestPriceCountdownText, '01:00');
  });

  test('snapshot uses zero countdown without an interval and rejects time', () {
    final fixture = _fixture();
    final oneCandleData = _StableData(
      UnmodifiableListView(fixture.data.data.take(1)),
      fixture.data.version,
    );
    final oneCandleViewport = fixture.viewport.copyWith(itemCount: 1);
    final snapshot = RenderSnapshot<_Theme>(
      data: oneCandleData,
      viewport: oneCandleViewport,
      layout: fixture.layout,
      theme: const _Theme('dark'),
      versions: const RenderSnapshotVersions(),
      currentTime: 1704067200000,
    );

    expect(snapshot.latestPriceCountdown, Duration.zero);
    expect(snapshot.latestPriceCountdownText, '00:00');
    expect(
      () => RenderSnapshot<_Theme>(
        data: fixture.data,
        viewport: fixture.viewport,
        layout: fixture.layout,
        theme: const _Theme('dark'),
        versions: const RenderSnapshotVersions(),
        currentTime: -1,
      ),
      throwsArgumentError,
    );
  });
}

_Fixture _fixture() {
  final data = _StableData(
    UnmodifiableListView(buildV2KlineFixture(3)),
    KlineDataVersion(3),
  );
  final layout = ChartLayoutModel(
    width: 300,
    height: 300,
    bottomAxisHeight: 30,
    secondaryPanels: const [ChartPanelSpec.secondary(id: 'volume')],
  );
  final viewport = ChartViewport(
    itemCount: 3,
    width: layout.drawingBounds.width,
    itemExtent: 8,
  );
  final mainIndicator = RenderIndicatorSnapshot.fromResult(
    result: _indicatorResult(
      version: data.version,
      length: data.data.length,
    ),
    descriptor: _mainDescriptor(),
    panelId: 'main',
  );
  return _Fixture(data, viewport, layout, mainIndicator);
}

IndicatorResult _indicatorResult({
  required KlineDataVersion version,
  required int length,
  String instanceId = 'ma.fast',
  IndicatorComputationState? computationState,
}) =>
    IndicatorResult(
      instanceId: instanceId,
      definitionId: 'ma',
      dataVersion: version,
      length: length,
      series: [
        IndicatorSeries(
          id: 'value',
          values: List<double?>.generate(
            length,
            (index) => 1000.0 + index,
          ),
        ),
      ],
      computationState: computationState,
    );

IndicatorRendererDescriptor _mainDescriptor() => IndicatorRendererDescriptor(
      placement: IndicatorPlacement.mainChart,
      series: [
        IndicatorSeriesDescriptor(
          id: 'value',
          label: 'Value',
          drawingKind: IndicatorDrawingKind.line,
        ),
      ],
    );

IndicatorRendererDescriptor _secondaryDescriptor() =>
    IndicatorRendererDescriptor(
      placement: IndicatorPlacement.separatePanel,
      series: [
        IndicatorSeriesDescriptor(
          id: 'value',
          label: 'Value',
          drawingKind: IndicatorDrawingKind.line,
        ),
      ],
    );

final class _Fixture {
  const _Fixture(this.data, this.viewport, this.layout, this.mainIndicator);

  final _StableData data;
  final ChartViewport viewport;
  final ChartLayoutModel layout;
  final RenderIndicatorSnapshot mainIndicator;

  RenderSnapshot<_Theme> snapshot({
    ChartViewport? viewport,
    Iterable<RenderIndicatorSnapshot>? indicators,
    RenderSelectionSnapshot selection = const RenderSelectionSnapshot.hidden(),
  }) =>
      RenderSnapshot<_Theme>(
        data: data,
        viewport: viewport ?? this.viewport,
        layout: layout,
        theme: const _Theme('dark'),
        versions: const RenderSnapshotVersions(),
        indicators: indicators ?? [mainIndicator],
        selection: selection,
      );
}

final class _StableData implements VersionedKlineData {
  const _StableData(this.data, this.version);

  @override
  final List<Kline> data;

  @override
  final KlineDataVersion version;
}

final class _Theme {
  const _Theme(this.name);

  final String name;
}
