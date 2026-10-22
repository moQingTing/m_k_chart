import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  test('Layer freezes identity and explicit input dependencies', () {
    final dependencies = <RenderSnapshotSlice>{
      RenderSnapshotSlice.layout,
      RenderSnapshotSlice.theme,
    };
    final layer = _RecordingLayer('grid', dependencies);
    dependencies.clear();

    expect(layer.id, 'grid');
    expect(
      layer.dependencies,
      {RenderSnapshotSlice.layout, RenderSnapshotSlice.theme},
    );
    expect(
      () => layer.dependencies.add(RenderSnapshotSlice.data),
      throwsUnsupportedError,
    );
    expect(
      () => _RecordingLayer(' ', {RenderSnapshotSlice.data}),
      throwsArgumentError,
    );
    expect(() => _RecordingLayer('empty', const {}), throwsArgumentError);
  });

  test('Layer stack preserves paint order and rejects duplicate identities',
      () {
    final grid = _RecordingLayer('grid', {RenderSnapshotSlice.layout});
    final candle = _RecordingLayer('candle', {
      RenderSnapshotSlice.data,
      RenderSnapshotSlice.viewport,
    });
    final source = <ChartRenderLayer<_Theme>>[grid, candle];
    final stack = RenderLayerStack<_Theme>(source);
    source.clear();

    expect(stack.layers, [grid, candle]);
    expect(stack.layer('candle'), same(candle));
    expect(() => stack.layers.clear(), throwsUnsupportedError);
    expect(() => stack.layerById.clear(), throwsUnsupportedError);
    expect(
      () => RenderLayerStack<_Theme>([
        grid,
        _RecordingLayer('grid', {RenderSnapshotSlice.theme}),
      ]),
      throwsArgumentError,
    );
    expect(() => stack.layer('missing'), throwsArgumentError);
  });

  test('Layer receives only Canvas and a read-only RenderSnapshot', () {
    final snapshot = _snapshot();
    final layer = _RecordingLayer('grid', {
      RenderSnapshotSlice.layout,
      RenderSnapshotSlice.theme,
    });
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    layer.paint(RenderLayerContext(canvas: canvas, snapshot: snapshot));
    final picture = recorder.endRecording();

    expect(layer.paintCount, 1);
    expect(layer.lastSnapshot, same(snapshot));
    picture.dispose();
  });
}

RenderSnapshot<_Theme> _snapshot() {
  final data = _StableData(
    UnmodifiableListView(buildV2KlineFixture(3)),
  );
  final layout = ChartLayoutModel(width: 300, height: 240);
  return RenderSnapshot<_Theme>(
    data: data,
    viewport: ChartViewport(
      itemCount: data.data.length,
      width: layout.drawingBounds.width,
      itemExtent: 8,
    ),
    layout: layout,
    theme: const _Theme(),
    versions: const RenderSnapshotVersions(),
  );
}

final class _RecordingLayer extends ChartRenderLayer<_Theme> {
  _RecordingLayer(
    String id,
    Iterable<RenderSnapshotSlice> dependencies,
  ) : super(id: id, dependencies: dependencies);

  int paintCount = 0;
  RenderSnapshot<_Theme>? lastSnapshot;

  @override
  void paint(RenderLayerContext<_Theme> context) {
    paintCount++;
    lastSnapshot = context.snapshot;
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
