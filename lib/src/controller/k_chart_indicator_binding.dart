import '../indicator/indicator_config.dart';

/// 一个指标实例与主/副图面板的绑定，后续由 KChartOptions.indicators 承载。
///
/// 计算参数继续复用不可变 IndicatorConfig；面板位置不参与指标算法和缓存身份。
/// 当前为内部配置，不应从正式公共入口导出。
final class KChartIndicatorBinding {
  KChartIndicatorBinding({
    required this.panelId,
    required this.config,
    Iterable<String>? visibleSeriesIds,
  }) : visibleSeriesIds = visibleSeriesIds == null
            ? null
            : Set<String>.unmodifiable(visibleSeriesIds) {
    if (panelId.trim().isEmpty) {
      throw ArgumentError.value(panelId, 'panelId', 'Must not be blank.');
    }
    final visible = this.visibleSeriesIds;
    if (visible != null &&
        (visible.isEmpty || visible.any((id) => id.trim().isEmpty))) {
      throw ArgumentError.value(
        visible,
        'visibleSeriesIds',
        'Select at least one non-blank series id.',
      );
    }
  }

  final String panelId;
  final IndicatorConfig config;

  /// 仅影响显示，不参与指标计算缓存。null 表示展示描述符允许的全部序列。
  final Set<String>? visibleSeriesIds;

  KChartIndicatorBinding copyWith({
    String? panelId,
    IndicatorConfig? config,
    Iterable<String>? visibleSeriesIds,
    bool resetVisibleSeriesIds = false,
  }) =>
      KChartIndicatorBinding(
        panelId: panelId ?? this.panelId,
        config: config ?? this.config,
        visibleSeriesIds: resetVisibleSeriesIds
            ? null
            : visibleSeriesIds ?? this.visibleSeriesIds,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartIndicatorBinding &&
          panelId == other.panelId &&
          config == other.config &&
          _sameSet(visibleSeriesIds, other.visibleSeriesIds);

  @override
  int get hashCode => Object.hash(
        panelId,
        config,
        visibleSeriesIds == null
            ? null
            : Object.hashAllUnordered(visibleSeriesIds!),
      );
}

bool _sameSet(Set<String>? a, Set<String>? b) =>
    identical(a, b) ||
    (a != null && b != null && a.length == b.length && a.containsAll(b));

/// 内部共享配置校验：Options 与协调器使用同一规则，避免两条接入路径行为不同。
List<KChartIndicatorBinding> validateKChartIndicatorBindings(
  Iterable<KChartIndicatorBinding> input,
  Iterable<String> panels,
) {
  final bindings = List<KChartIndicatorBinding>.unmodifiable(input);
  final panelIds = panels.toSet();
  final ids = <String>{};
  for (final binding in bindings) {
    if (!panelIds.contains(binding.panelId)) {
      throw ArgumentError.value(binding.panelId, 'panelId', 'Unknown panel.');
    }
    if (!ids.add(binding.config.instanceId)) {
      throw ArgumentError.value(
        binding.config.instanceId,
        'instanceId',
        'Indicator instance ids must be unique across the chart.',
      );
    }
  }
  return bindings;
}
