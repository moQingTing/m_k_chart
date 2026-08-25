import 'dart:collection';
import 'dart:ui';

import 'render_snapshot.dart';

/// The only mutable output available to a Layer is its current [canvas].
final class RenderLayerContext<TTheme extends Object> {
  const RenderLayerContext({
    required this.canvas,
    required this.snapshot,
  });

  final Canvas canvas;
  final RenderSnapshot<TTheme> snapshot;
}

/// Pure drawing unit with explicit snapshot-slice dependencies.
///
/// Implementations may cache drawing artifacts, but must not publish state or
/// retain the mutable [Canvas] after [paint] returns.
abstract base class ChartRenderLayer<TTheme extends Object> {
  ChartRenderLayer({
    required String id,
    required Iterable<RenderSnapshotSlice> dependencies,
  })  : id = _validatedId(id),
        dependencies = Set<RenderSnapshotSlice>.unmodifiable(dependencies) {
    if (this.dependencies.isEmpty) {
      throw ArgumentError('A visible Layer must declare dependencies.');
    }
  }

  final String id;
  final Set<RenderSnapshotSlice> dependencies;

  void paint(RenderLayerContext<TTheme> context);
}

/// Immutable paint-order registry. Layer IDs are stable cache identities.
final class RenderLayerStack<TTheme extends Object> {
  factory RenderLayerStack(Iterable<ChartRenderLayer<TTheme>> layers) {
    final immutableLayers = List<ChartRenderLayer<TTheme>>.unmodifiable(layers);
    final layerById = <String, ChartRenderLayer<TTheme>>{};
    for (final layer in immutableLayers) {
      if (layerById.containsKey(layer.id)) {
        throw ArgumentError.value(layer.id, 'layers', 'Duplicate Layer id.');
      }
      layerById[layer.id] = layer;
    }
    return RenderLayerStack._(
      immutableLayers,
      UnmodifiableMapView(layerById),
    );
  }

  const RenderLayerStack._(this.layers, this.layerById);

  final List<ChartRenderLayer<TTheme>> layers;
  final Map<String, ChartRenderLayer<TTheme>> layerById;

  ChartRenderLayer<TTheme> layer(String id) {
    final result = layerById[id];
    if (result == null) {
      throw ArgumentError.value(id, 'id', 'Unknown Layer.');
    }
    return result;
  }
}

String _validatedId(String id) {
  if (id.trim().isEmpty) {
    throw ArgumentError.value(id, 'id', 'Must not be empty.');
  }
  return id;
}
