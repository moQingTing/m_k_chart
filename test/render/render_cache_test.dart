import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  test('visible window ignores selection-only changes and invalidates viewport',
      () {
    final cache = ChartRenderCache();
    final fixture = _fixture();
    final first = fixture.snapshot();
    final selectionOnly = fixture.snapshot(
      versions: const RenderSnapshotVersions(selection: 1),
      selection: RenderSelectionSnapshot.visible(localX: 10, localY: 20),
    );
    final moved = fixture.snapshot(
      versions: const RenderSnapshotVersions(viewport: 1),
      viewport: fixture.viewport.copyWith(scrollOffsetItems: 1),
    );

    final initialWindow = cache.windowFor(first);
    expect(cache.windowFor(selectionOnly), same(initialWindow));
    expect(cache.windowFor(moved), isNot(same(initialWindow)));
    expect(cache.stats.hitCount(RenderCacheKind.window), 1);
    expect(cache.stats.missCount(RenderCacheKind.window), 2);

    cache.dispose();
  });

  test('panel range shares cached visible extrema and invalidates data version',
      () {
    final cache = ChartRenderCache();
    final fixture = _fixture();
    final first = fixture.snapshot();
    final updated = fixture.snapshot(
      versions: const RenderSnapshotVersions(data: 1),
    );

    final firstRange = cache.panelRangeFor(first, 'main');
    expect(cache.panelRangeFor(first, 'main'), same(firstRange));
    expect(cache.extremaFor(first), isNotNull);
    expect(cache.panelRangeFor(updated, 'main'), isNot(same(firstRange)));

    expect(cache.stats.hitCount(RenderCacheKind.panelRange), 1);
    expect(cache.stats.missCount(RenderCacheKind.panelRange), 2);
    expect(
      cache.stats.hitCount(RenderCacheKind.extrema),
      greaterThanOrEqualTo(1),
    );
    cache.dispose();
  });

  test('text, Path and Picture caches are bounded LRU stores', () {
    final cache = ChartRenderCache(
      textCapacity: 1,
      pathCapacity: 1,
      pictureCapacity: 1,
    );

    final firstText = cache.textPainter(
      text: '100',
      color: const Color(0xffffffff),
      fontSize: 10,
    );
    expect(
      cache.textPainter(
        text: '100',
        color: const Color(0xffffffff),
        fontSize: 10,
      ),
      same(firstText),
    );
    cache.textPainter(
      text: '200',
      color: const Color(0xffffffff),
      fontSize: 10,
    );
    expect(
      cache.textPainter(
        text: '100',
        color: const Color(0xffffffff),
        fontSize: 10,
      ),
      isNot(same(firstText)),
    );

    final firstPath = cache.path('first', Path.new);
    expect(cache.path('first', Path.new), same(firstPath));
    cache.path('second', Path.new);
    expect(cache.path('first', Path.new), isNot(same(firstPath)));

    var pictureBuilds = 0;
    Picture buildPicture() {
      pictureBuilds++;
      final recorder = PictureRecorder();
      Canvas(recorder, const Rect.fromLTWH(0, 0, 1, 1));
      return recorder.endRecording();
    }

    final firstPicture = cache.picture('first', buildPicture);
    expect(cache.picture('first', buildPicture), same(firstPicture));
    cache.picture('second', buildPicture);
    expect(cache.picture('first', buildPicture), isNot(same(firstPicture)));
    expect(pictureBuilds, 3);

    expect(cache.stats.hitCount(RenderCacheKind.text), 1);
    expect(cache.stats.missCount(RenderCacheKind.text), 3);
    expect(cache.stats.hitCount(RenderCacheKind.path), 1);
    expect(cache.stats.missCount(RenderCacheKind.path), 3);
    expect(cache.stats.hitCount(RenderCacheKind.picture), 1);
    expect(cache.stats.missCount(RenderCacheKind.picture), 3);
    cache.dispose();
  });

  test('standard Layer stack reuses every cache class when repainted', () {
    final fixture = _fixture();
    final cache = ChartRenderCache();
    final layers = buildStandardChartLayerStack<DefaultChartRenderStyle>(cache);
    final snapshot = fixture.snapshot();

    _paintLayers(layers, snapshot);
    final afterFirst = cache.stats;
    _paintLayers(layers, snapshot);
    final afterSecond = cache.stats;

    for (final kind in <RenderCacheKind>[
      RenderCacheKind.window,
      RenderCacheKind.extrema,
      RenderCacheKind.panelRange,
      RenderCacheKind.text,
      RenderCacheKind.path,
      RenderCacheKind.picture,
    ]) {
      expect(
        afterSecond.hitCount(kind),
        greaterThan(afterFirst.hitCount(kind)),
        reason: '$kind should hit on the unchanged second frame',
      );
    }
    cache.dispose();
  });

  test('two chart caches never share entries or counters', () {
    final fixture = _fixture();
    final first = ChartRenderCache();
    final second = ChartRenderCache();

    final firstWindow = first.windowFor(fixture.snapshot());
    final secondWindow = second.windowFor(fixture.snapshot());

    expect(secondWindow, isNot(same(firstWindow)));
    expect(first.stats.missCount(RenderCacheKind.window), 1);
    expect(second.stats.missCount(RenderCacheKind.window), 1);
    expect(first.stats.hitCount(RenderCacheKind.window), 0);
    expect(second.stats.hitCount(RenderCacheKind.window), 0);

    first.dispose();
    second.dispose();
  });

  test('clear evicts entries while preserving cumulative diagnostics', () {
    final cache = ChartRenderCache();
    final first = cache.path('line', Path.new);

    cache.clear();

    expect(cache.path('line', Path.new), isNot(same(first)));
    expect(cache.stats.missCount(RenderCacheKind.path), 2);
    cache.dispose();
  });

  test('dispose is idempotent and rejects all later cache access', () {
    final cache = ChartRenderCache();
    final stats = cache.stats;
    expect(() => stats.hits.clear(), throwsUnsupportedError);

    cache.dispose();
    cache.dispose();

    expect(cache.isDisposed, isTrue);
    expect(
      () => cache.textPainter(
        text: 'x',
        color: const Color(0xffffffff),
        fontSize: 10,
      ),
      throwsStateError,
    );
    expect(() => cache.path('x', Path.new), throwsStateError);
  });

  test('cache rejects non-positive capacities and malformed text size', () {
    expect(() => ChartRenderCache(pathCapacity: 0), throwsArgumentError);
    final cache = ChartRenderCache();
    expect(
      () => cache.textPainter(
        text: 'x',
        color: const Color(0xffffffff),
        fontSize: double.nan,
      ),
      throwsArgumentError,
    );
    cache.dispose();
  });
}

void _paintLayers(
  RenderLayerStack<DefaultChartRenderStyle> layers,
  RenderSnapshot<DefaultChartRenderStyle> snapshot,
) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final context = RenderLayerContext(canvas: canvas, snapshot: snapshot);
  for (final layer in layers.layers) {
    layer.paint(context);
  }
  recorder.endRecording().dispose();
}

_Fixture _fixture() {
  final data = _StableData(
    UnmodifiableListView([
      for (var index = 0; index < 10; index++) _kline(index),
    ]),
  );
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
  final viewport = ChartViewport(
    itemCount: data.data.length,
    width: layout.drawingBounds.width,
    itemExtent: 30,
  );
  final indicator = RenderIndicatorSnapshot.fromResult(
    result: IndicatorResult(
      instanceId: 'ma.fast',
      definitionId: 'ma',
      dataVersion: data.version,
      length: data.data.length,
      series: [
        IndicatorSeries(
          id: 'line',
          values: [for (var index = 0; index < 10; index++) 101.0 + index],
        ),
      ],
    ),
    descriptor: IndicatorRendererDescriptor(
      placement: IndicatorPlacement.mainChart,
      series: [
        IndicatorSeriesDescriptor(
          id: 'line',
          label: 'MA',
          drawingKind: IndicatorDrawingKind.line,
        ),
      ],
    ),
    panelId: 'main',
  );
  return _Fixture(
    data: data,
    layout: layout,
    viewport: viewport,
    indicator: indicator,
    style: DefaultChartRenderStyle(),
  );
}

Kline _kline(int index) => Kline(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      openTime: 1704067200000 + index * 60000,
      closeTime: 1704067259999 + index * 60000,
      open: 100.0 + index,
      high: 103.0 + index,
      low: 99.0 + index,
      close: 102.0 + index,
      baseVolume: 10,
      quoteVolume: 1000,
      tradeCount: 20,
      isClosed: true,
    );

final class _Fixture {
  const _Fixture({
    required this.data,
    required this.layout,
    required this.viewport,
    required this.indicator,
    required this.style,
  });

  final _StableData data;
  final ChartLayoutModel layout;
  final ChartViewport viewport;
  final RenderIndicatorSnapshot indicator;
  final DefaultChartRenderStyle style;

  RenderSnapshot<DefaultChartRenderStyle> snapshot({
    RenderSnapshotVersions versions = const RenderSnapshotVersions(),
    ChartViewport? viewport,
    RenderSelectionSnapshot selection = const RenderSelectionSnapshot.hidden(),
  }) =>
      RenderSnapshot<DefaultChartRenderStyle>(
        data: data,
        viewport: viewport ?? this.viewport,
        layout: layout,
        theme: style,
        versions: versions,
        indicators: [indicator],
        selection: selection,
      );
}

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
