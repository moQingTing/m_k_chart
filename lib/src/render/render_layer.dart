import 'dart:collection';
import 'dart:ui';

import 'render_snapshot.dart';

/// 图层唯一可变的输出是当前 [canvas]。
final class RenderLayerContext<TTheme extends Object> {
  const RenderLayerContext({
    required this.canvas,
    required this.snapshot,
  });

  final Canvas canvas;
  final RenderSnapshot<TTheme> snapshot;
}

/// 显式声明快照切片依赖的纯绘制单元。
///
/// 实现可缓存绘制产物，但不得发布状态，也不得在 [paint] 返回后持有可变 [Canvas]。
/// 图层应只根据 [RenderLayerContext.snapshot] 绘制；交互、网络回调及 setState 必须留在
/// Controller/Widget 边界之外。
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

/// 不可变的绘制顺序注册表；图层 id 是稳定的缓存身份。
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
