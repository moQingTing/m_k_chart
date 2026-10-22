part of 'k_chart_data_coordinator.dart';

/// 指标装配与数据事务共用提交边界，计算器只能读取输入，不能在计算中修改图表。
extension _IndicatorCoordination on KChartDataCoordinator {
  IndicatorCalculationBatch _resolveIndicators(
    VersionedKlineData data,
    List<KChartIndicatorBinding> bindings,
  ) {
    _calculatingIndicators = true;
    try {
      return _indicatorEngine.resolveAll(
        data,
        bindings.map((binding) => binding.config),
      );
    } finally {
      _calculatingIndicators = false;
    }
  }

  void _ensureNotCalculating() {
    if (_calculatingIndicators) {
      throw StateError('Indicator calculations must not mutate the chart.');
    }
  }
}

/// 显示排序/面板归属不影响数值。仅比较以实例 id 标识的配置集合，避免移动面板时重算。
bool _sameIndicatorConfigs(
  List<KChartIndicatorBinding> next,
  List<KChartIndicatorBinding> previous,
) {
  if (identical(next, previous)) return true;
  if (next.length != previous.length) return false;
  final configs = {
    for (final binding in previous) binding.config.instanceId: binding.config,
  };
  return next
      .every((binding) => configs[binding.config.instanceId] == binding.config);
}
