import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  test('standard Layers repaint only for their declared version slices', () {
    final pipeline = StandardChartRenderPipeline<DefaultChartRenderStyle>();

    final first = _paint(pipeline, _snapshot());
    expect(first.repaintedLayerIds, _standardLayerIds);
    expect(first.reusedLayerIds, isEmpty);
    expect(
      first.invalidatedSlices['crosshair'],
      {
        RenderSnapshotSlice.selection,
        RenderSnapshotSlice.layout,
        RenderSnapshotSlice.theme,
        RenderSnapshotSlice.locale,
      },
    );
    expect(() => first.repaintedLayerIds.clear(), throwsUnsupportedError);
    expect(() => first.invalidatedSlices.clear(), throwsUnsupportedError);
    expect(
      () => first.invalidatedSlices['crosshair']!
          .add(RenderSnapshotSlice.history),
      throwsUnsupportedError,
    );

    final unchanged = _paint(pipeline, _snapshot());
    expect(unchanged.repaintedLayerIds, isEmpty);
    expect(unchanged.reusedLayerIds, _standardLayerIds);

    final selection = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(selection: 1),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(selection.repaintedLayerIds, ['crosshair']);
    expect(
      selection.invalidatedSlices['crosshair'],
      {RenderSnapshotSlice.selection},
    );

    final history = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(selection: 1, history: 1),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
        history: const RenderHistorySnapshot(
          phase: RenderHistoryPhase.loading,
        ),
      ),
    );
    expect(history.repaintedLayerIds, isEmpty);

    final viewport = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          viewport: 1,
          selection: 1,
          history: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(
      viewport.repaintedLayerIds,
      [
        'grid',
        'main',
        'secondary',
        'axis',
        'marker',
        'tradeOverlay',
        'drawing',
      ],
    );

    final data = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          data: 1,
          viewport: 1,
          selection: 1,
          history: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(
      data.repaintedLayerIds,
      [
        'grid',
        'main',
        'secondary',
        'axis',
        'marker',
        'tradeOverlay',
        'drawing',
      ],
    );

    final layout = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          data: 1,
          viewport: 1,
          selection: 1,
          history: 1,
          layout: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(layout.repaintedLayerIds, _standardLayerIds);

    final theme = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          data: 1,
          viewport: 1,
          selection: 1,
          history: 1,
          layout: 1,
          theme: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(theme.repaintedLayerIds, _standardLayerIds);

    final locale = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          data: 1,
          viewport: 1,
          selection: 1,
          history: 1,
          layout: 1,
          theme: 1,
          locale: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(locale.repaintedLayerIds, ['axis', 'crosshair']);
    expect(
      locale.invalidatedSlices['axis'],
      {RenderSnapshotSlice.locale},
    );
    expect(
      locale.invalidatedSlices['crosshair'],
      {RenderSnapshotSlice.locale},
    );

    final clock = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          data: 1,
          viewport: 1,
          selection: 1,
          history: 1,
          layout: 1,
          theme: 1,
          clock: 1,
          locale: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(clock.repaintedLayerIds, ['marker']);
    expect(
      clock.invalidatedSlices['marker'],
      {RenderSnapshotSlice.clock},
    );

    final drawings = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          data: 1,
          viewport: 1,
          selection: 1,
          history: 1,
          layout: 1,
          theme: 1,
          drawings: 1,
          clock: 1,
          locale: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(drawings.repaintedLayerIds, ['drawing']);
    expect(
      drawings.invalidatedSlices['drawing'],
      {RenderSnapshotSlice.drawings},
    );

    final overlays = _paint(
      pipeline,
      _snapshot(
        versions: const RenderSnapshotVersions(
          data: 1,
          viewport: 1,
          selection: 1,
          history: 1,
          layout: 1,
          theme: 1,
          drawings: 1,
          overlays: 1,
          clock: 1,
          locale: 1,
        ),
        selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
      ),
    );
    expect(overlays.repaintedLayerIds, ['tradeOverlay']);
    expect(
      overlays.invalidatedSlices['tradeOverlay'],
      {RenderSnapshotSlice.overlays},
    );

    expect(pipeline.repaintStats.frameCount, 12);
    expect(pipeline.repaintStats.repaintCount('grid'), 5);
    expect(pipeline.repaintStats.repaintCount('main'), 5);
    expect(pipeline.repaintStats.repaintCount('marker'), 6);
    expect(pipeline.repaintStats.repaintCount('tradeOverlay'), 6);
    expect(pipeline.repaintStats.repaintCount('axis'), 6);
    expect(pipeline.repaintStats.repaintCount('crosshair'), 5);
    pipeline.dispose();
  });

  test('selection-only frame retains background while replacing crosshair',
      () async {
    final pipeline = StandardChartRenderPipeline<DefaultChartRenderStyle>();
    final style = DefaultChartRenderStyle();
    _paint(pipeline, _snapshot(style: style));

    final recorder = PictureRecorder();
    final report = pipeline.paint(
      RenderLayerContext(
        canvas: Canvas(recorder),
        snapshot: _snapshot(
          style: style,
          versions: const RenderSnapshotVersions(selection: 1),
          selection: RenderSelectionSnapshot.visible(localX: 50, localY: 60),
        ),
      ),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(120, 120);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);

    expect(report.repaintedLayerIds, ['crosshair']);
    expect(
      _argbAt(bytes!, image.width, 13, 13),
      style.backgroundColor.toARGB32(),
    );
    expect(
      _argbAt(bytes, image.width, 50, 13),
      isNot(style.backgroundColor.toARGB32()),
    );

    image.dispose();
    picture.dispose();
    pipeline.dispose();
  });

  test('failed Layer recording does not commit pictures or repaint stats', () {
    final first = _RecordingLayer('first');
    final second = _RecordingLayer('second');
    final compositor = RetainedRenderLayerCompositor<_Theme>(
      RenderLayerStack([first, second]),
    );
    _paintCompositor(compositor, _plainSnapshot());

    second.shouldThrow = true;
    expect(
      () => _paintCompositor(
        compositor,
        _plainSnapshot(versions: const RenderSnapshotVersions(data: 1)),
      ),
      throwsStateError,
    );
    expect(compositor.stats.frameCount, 1);
    expect(compositor.stats.repaintCount('first'), 1);
    expect(compositor.stats.repaintCount('second'), 1);

    second.shouldThrow = false;
    final retry = _paintCompositor(
      compositor,
      _plainSnapshot(versions: const RenderSnapshotVersions(data: 1)),
    );
    expect(retry.repaintedLayerIds, ['first', 'second']);
    expect(compositor.stats.repaintCount('first'), 2);
    expect(compositor.stats.repaintCount('second'), 2);
    expect(
      () => _paintCompositor(compositor, _plainSnapshot()),
      throwsStateError,
    );
    expect(compositor.stats.frameCount, 2);
    compositor.dispose();
  });

  test('clear retains diagnostics, dispose is isolated and idempotent', () {
    final layer = _RecordingLayer('only');
    final first = RetainedRenderLayerCompositor<_Theme>(
      RenderLayerStack([layer]),
    );
    final second = RetainedRenderLayerCompositor<_Theme>(
      RenderLayerStack([_RecordingLayer('only')]),
    );
    _paintCompositor(first, _plainSnapshot());
    expect(first.stats.repaintCount('only'), 1);
    expect(second.stats.repaintCount('only'), 0);

    first.clear();
    _paintCompositor(first, _plainSnapshot());
    expect(first.stats.frameCount, 2);
    expect(first.stats.repaintCount('only'), 2);
    expect(() => first.stats.repaintCounts.clear(), throwsUnsupportedError);

    first.dispose();
    first.dispose();
    expect(first.isDisposed, isTrue);
    expect(
      () => _paintCompositor(first, _plainSnapshot()),
      throwsStateError,
    );
    expect(second.isDisposed, isFalse);
    second.dispose();
  });

  test('同版本号但数据列表换仓库时数据图层重新录制', () {
    final compositor = RetainedRenderLayerCompositor<_Theme>(
      RenderLayerStack([_RecordingLayer('only')]),
    );
    addTearDown(compositor.dispose);
    final firstData = _StableData(UnmodifiableListView(const <Kline>[]));
    final secondData = _StableData(UnmodifiableListView(const <Kline>[]));
    expect(firstData.version, secondData.version);
    expect(identical(firstData.data, secondData.data), isFalse);
    expect(
      _paintCompositor(compositor, _plainSnapshot(data: firstData))
          .repaintedLayerIds,
      ['only'],
    );
    final second = _paintCompositor(
      compositor,
      _plainSnapshot(data: secondData),
    );
    expect(second.repaintedLayerIds, ['only']);
    expect(second.invalidatedSlices['only'], {RenderSnapshotSlice.data});
  });

  test('标准图层复用相同版本号时仍按新仓库重录 K 线', () {
    final pipeline = StandardChartRenderPipeline<DefaultChartRenderStyle>();
    addTearDown(pipeline.dispose);
    final firstCandle = Kline(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      openTime: 1704067200000,
      closeTime: 1704067259999,
      open: 100,
      high: 103,
      low: 99,
      close: 102,
      baseVolume: 10,
      quoteVolume: 1000,
      tradeCount: 20,
      isClosed: true,
    );
    final firstData = _StableData(UnmodifiableListView([firstCandle]));
    final secondCandle = firstCandle.copyWith(high: 901, close: 900);
    final secondData = _StableData(UnmodifiableListView([secondCandle]));
    final first = _snapshot(data: firstData);
    final second = _snapshot(data: secondData);
    expect(first.data.version, second.data.version);
    _paint(pipeline, first);
    final report = _paint(pipeline, second);
    expect(report.repaintedLayerIds, containsAll(['grid', 'main', 'marker']));
    expect(pipeline.cache.candlesFor(second).candles.single.close, 900);
    expect(report.invalidatedSlices['main'], {RenderSnapshotSlice.data});
  });
}

const _standardLayerIds = [
  'grid',
  'main',
  'secondary',
  'axis',
  'marker',
  'tradeOverlay',
  'drawing',
  'crosshair',
];

RenderLayerFrameReport _paint(
  StandardChartRenderPipeline<DefaultChartRenderStyle> pipeline,
  RenderSnapshot<DefaultChartRenderStyle> snapshot,
) {
  final recorder = PictureRecorder();
  final report = pipeline.paint(
    RenderLayerContext(canvas: Canvas(recorder), snapshot: snapshot),
  );
  recorder.endRecording().dispose();
  return report;
}

RenderLayerFrameReport _paintCompositor(
  RetainedRenderLayerCompositor<_Theme> compositor,
  RenderSnapshot<_Theme> snapshot,
) {
  final recorder = PictureRecorder();
  try {
    return compositor.paint(
      RenderLayerContext(canvas: Canvas(recorder), snapshot: snapshot),
    );
  } finally {
    recorder.endRecording().dispose();
  }
}

RenderSnapshot<DefaultChartRenderStyle> _snapshot({
  VersionedKlineData? data,
  DefaultChartRenderStyle? style,
  RenderSnapshotVersions versions = const RenderSnapshotVersions(),
  RenderSelectionSnapshot selection = const RenderSelectionSnapshot.hidden(),
  RenderHistorySnapshot history = const RenderHistorySnapshot(),
}) {
  final layout = ChartLayoutModel(width: 120, height: 120);
  final resolvedData = data ?? _emptyData;
  return RenderSnapshot(
    data: resolvedData,
    viewport: ChartViewport(
      itemCount: resolvedData.data.length,
      width: layout.drawingBounds.width,
    ),
    layout: layout,
    theme: style ?? DefaultChartRenderStyle(),
    versions: versions,
    selection: selection,
    history: history,
  );
}

RenderSnapshot<_Theme> _plainSnapshot({
  VersionedKlineData? data,
  RenderSnapshotVersions versions = const RenderSnapshotVersions(),
}) {
  final layout = ChartLayoutModel(width: 120, height: 120);
  return RenderSnapshot(
    data: data ?? _emptyData,
    viewport: ChartViewport(width: layout.drawingBounds.width),
    layout: layout,
    theme: const _Theme(),
    versions: versions,
  );
}

const _emptyData = _StableData(<Kline>[]);

int _argbAt(ByteData bytes, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  final red = bytes.getUint8(offset);
  final green = bytes.getUint8(offset + 1);
  final blue = bytes.getUint8(offset + 2);
  final alpha = bytes.getUint8(offset + 3);
  return alpha << 24 | red << 16 | green << 8 | blue;
}

final class _RecordingLayer extends ChartRenderLayer<_Theme> {
  _RecordingLayer(String id)
      : super(id: id, dependencies: const {RenderSnapshotSlice.data});

  bool shouldThrow = false;

  @override
  void paint(RenderLayerContext<_Theme> context) {
    if (shouldThrow) {
      throw StateError('recording failed');
    }
    context.canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xffffffff),
    );
  }
}

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
