import 'dart:collection';
import 'dart:ui';

import 'render_layer.dart';
import 'render_snapshot.dart';

final class RenderLayerVersionStamp {
  RenderLayerVersionStamp._({
    required this.data,
    required this.viewport,
    required this.selection,
    required this.history,
    required this.layout,
    required this.theme,
    required this.drawings,
    required this.overlays,
    required this.clock,
  });

  factory RenderLayerVersionStamp.capture({
    required Set<RenderSnapshotSlice> dependencies,
    required RenderSnapshotVersions versions,
  }) =>
      RenderLayerVersionStamp._(
        data: _versionFor(dependencies, versions, RenderSnapshotSlice.data),
        viewport:
            _versionFor(dependencies, versions, RenderSnapshotSlice.viewport),
        selection: _versionFor(
          dependencies,
          versions,
          RenderSnapshotSlice.selection,
        ),
        history:
            _versionFor(dependencies, versions, RenderSnapshotSlice.history),
        layout: _versionFor(dependencies, versions, RenderSnapshotSlice.layout),
        theme: _versionFor(dependencies, versions, RenderSnapshotSlice.theme),
        drawings: _versionFor(
          dependencies,
          versions,
          RenderSnapshotSlice.drawings,
        ),
        overlays: _versionFor(
          dependencies,
          versions,
          RenderSnapshotSlice.overlays,
        ),
        clock: _versionFor(dependencies, versions, RenderSnapshotSlice.clock),
      );

  final int? data;
  final int? viewport;
  final int? selection;
  final int? history;
  final int? layout;
  final int? theme;
  final int? drawings;
  final int? overlays;
  final int? clock;

  int? versionOf(RenderSnapshotSlice slice) => switch (slice) {
        RenderSnapshotSlice.data => data,
        RenderSnapshotSlice.viewport => viewport,
        RenderSnapshotSlice.selection => selection,
        RenderSnapshotSlice.history => history,
        RenderSnapshotSlice.layout => layout,
        RenderSnapshotSlice.theme => theme,
        RenderSnapshotSlice.drawings => drawings,
        RenderSnapshotSlice.overlays => overlays,
        RenderSnapshotSlice.clock => clock,
      };

  Set<RenderSnapshotSlice> changedSlicesSince(
    RenderLayerVersionStamp? previous,
  ) =>
      Set<RenderSnapshotSlice>.unmodifiable({
        for (final slice in RenderSnapshotSlice.values)
          if (versionOf(slice) != null &&
              (previous == null ||
                  versionOf(slice) != previous.versionOf(slice)))
            slice,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderLayerVersionStamp &&
          data == other.data &&
          viewport == other.viewport &&
          selection == other.selection &&
          history == other.history &&
          layout == other.layout &&
          theme == other.theme &&
          drawings == other.drawings &&
          overlays == other.overlays &&
          clock == other.clock;

  @override
  int get hashCode => Object.hash(
        data,
        viewport,
        selection,
        history,
        layout,
        theme,
        drawings,
        overlays,
        clock,
      );
}

final class RenderLayerFrameReport {
  RenderLayerFrameReport._({
    required this.frameNumber,
    required Iterable<String> repaintedLayerIds,
    required Iterable<String> reusedLayerIds,
    required Map<String, Set<RenderSnapshotSlice>> invalidatedSlices,
  })  : repaintedLayerIds = List.unmodifiable(repaintedLayerIds),
        reusedLayerIds = List.unmodifiable(reusedLayerIds),
        invalidatedSlices = UnmodifiableMapView(
          Map.unmodifiable(invalidatedSlices),
        );

  final int frameNumber;
  final List<String> repaintedLayerIds;
  final List<String> reusedLayerIds;
  final Map<String, Set<RenderSnapshotSlice>> invalidatedSlices;

  bool repainted(String layerId) => repaintedLayerIds.contains(layerId);
}

final class RenderLayerRepaintStats {
  RenderLayerRepaintStats._({
    required this.frameCount,
    required Map<String, int> repaintCounts,
    required Map<String, int> reuseCounts,
  })  : repaintCounts = Map.unmodifiable(repaintCounts),
        reuseCounts = Map.unmodifiable(reuseCounts);

  final int frameCount;
  final Map<String, int> repaintCounts;
  final Map<String, int> reuseCounts;

  int repaintCount(String layerId) => repaintCounts[layerId] ?? 0;
  int reuseCount(String layerId) => reuseCounts[layerId] ?? 0;
}

/// Records invalidated Layers and composites retained Pictures in stack order.
final class RetainedRenderLayerCompositor<TTheme extends Object> {
  RetainedRenderLayerCompositor(this.layers)
      : _states = {
          for (final layer in layers.layers)
            layer.id: _RetainedLayerState<TTheme>(layer),
        },
        _repaintCounts = {for (final layer in layers.layers) layer.id: 0},
        _reuseCounts = {for (final layer in layers.layers) layer.id: 0};

  final RenderLayerStack<TTheme> layers;
  final Map<String, _RetainedLayerState<TTheme>> _states;
  final Map<String, int> _repaintCounts;
  final Map<String, int> _reuseCounts;
  RenderSnapshotVersions? _lastVersions;
  int _frameCount = 0;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  RenderLayerRepaintStats get stats => RenderLayerRepaintStats._(
        frameCount: _frameCount,
        repaintCounts: _repaintCounts,
        reuseCounts: _reuseCounts,
      );

  RenderLayerFrameReport paint(RenderLayerContext<TTheme> context) {
    _ensureActive();
    _ensureMonotonic(context.snapshot.versions);
    final prepared = <_PreparedLayer<TTheme>>[];
    final reused = <String>[];
    try {
      for (final layer in layers.layers) {
        final state = _states[layer.id]!;
        final stamp = RenderLayerVersionStamp.capture(
          dependencies: layer.dependencies,
          versions: context.snapshot.versions,
        );
        if (state.picture != null && state.stamp == stamp) {
          reused.add(layer.id);
          continue;
        }
        prepared.add(
          _PreparedLayer(
            state: state,
            picture: _recordLayer(layer, context.snapshot),
            stamp: stamp,
            changedSlices: stamp.changedSlicesSince(state.stamp),
          ),
        );
      }
    } catch (_) {
      for (final item in prepared) {
        item.picture.dispose();
      }
      rethrow;
    }

    final preparedById = {
      for (final item in prepared) item.state.layer.id: item,
    };
    try {
      for (final layer in layers.layers) {
        context.canvas.drawPicture(
          preparedById[layer.id]?.picture ?? _states[layer.id]!.picture!,
        );
      }
    } catch (_) {
      for (final item in prepared) {
        item.picture.dispose();
      }
      rethrow;
    }
    for (final item in prepared) {
      item.state.picture?.dispose();
      item.state
        ..picture = item.picture
        ..stamp = item.stamp;
      final id = item.state.layer.id;
      _repaintCounts[id] = _repaintCounts[id]! + 1;
    }
    for (final id in reused) {
      _reuseCounts[id] = _reuseCounts[id]! + 1;
    }
    _lastVersions = context.snapshot.versions;
    _frameCount++;
    return RenderLayerFrameReport._(
      frameNumber: _frameCount,
      repaintedLayerIds: [
        for (final item in prepared) item.state.layer.id,
      ],
      reusedLayerIds: reused,
      invalidatedSlices: {
        for (final item in prepared) item.state.layer.id: item.changedSlices,
      },
    );
  }

  void clear() {
    _ensureActive();
    _clearPictures();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _clearPictures();
    _isDisposed = true;
  }

  void _clearPictures() {
    for (final state in _states.values) {
      state.picture?.dispose();
      state
        ..picture = null
        ..stamp = null;
    }
  }

  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('RetainedRenderLayerCompositor has been disposed.');
    }
  }

  void _ensureMonotonic(RenderSnapshotVersions current) {
    final previous = _lastVersions;
    if (previous == null) {
      return;
    }
    for (final slice in RenderSnapshotSlice.values) {
      if (current.versionOf(slice) < previous.versionOf(slice)) {
        throw StateError('Render version for $slice must not decrease.');
      }
    }
  }
}

int? _versionFor(
  Set<RenderSnapshotSlice> dependencies,
  RenderSnapshotVersions versions,
  RenderSnapshotSlice slice,
) =>
    dependencies.contains(slice) ? versions.versionOf(slice) : null;

Picture _recordLayer<TTheme extends Object>(
  ChartRenderLayer<TTheme> layer,
  RenderSnapshot<TTheme> snapshot,
) {
  final recorder = PictureRecorder();
  try {
    layer.paint(
      RenderLayerContext<TTheme>(
        canvas: Canvas(recorder),
        snapshot: snapshot,
      ),
    );
    return recorder.endRecording();
  } catch (_) {
    recorder.endRecording().dispose();
    rethrow;
  }
}

final class _RetainedLayerState<TTheme extends Object> {
  _RetainedLayerState(this.layer);

  final ChartRenderLayer<TTheme> layer;
  RenderLayerVersionStamp? stamp;
  Picture? picture;
}

final class _PreparedLayer<TTheme extends Object> {
  const _PreparedLayer({
    required this.state,
    required this.picture,
    required this.stamp,
    required this.changedSlices,
  });

  final _RetainedLayerState<TTheme> state;
  final Picture picture;
  final RenderLayerVersionStamp stamp;
  final Set<RenderSnapshotSlice> changedSlices;
}
