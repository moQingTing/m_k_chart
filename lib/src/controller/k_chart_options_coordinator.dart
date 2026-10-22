part of 'k_chart_data_coordinator.dart';

/// 配置与视口的内部桥接，不持有第二份 options，也不改变数据版本。
extension _OptionsCoordination on KChartDataCoordinator {
  KChartOptions _withPanels(
    List<String> panels,
    Iterable<KChartIndicatorBinding> bindings,
  ) {
    final previous = {
      for (final panel in _value.options.secondaryPanels) panel.id: panel,
    };
    return _value.options.copyWith(
      secondaryPanels: [
        for (final id in panels)
          if (id != 'main') previous[id] ?? KChartSecondaryPanelOptions(id: id),
      ],
      indicators: bindings,
    );
  }

  ChartViewport _geometryForData(int count) => _managesViewport
      ? _value.options.viewport
          .resolveViewport(_value.viewport, itemCount: count)
      : _value.viewport.copyWith(itemCount: count);

  ChartViewport _resetGeometry(int count) {
    _needsInitialFit = _managesViewport && _value.viewport.width == 0;
    final next = _managesViewport
        ? _value.options.viewport.resolveViewport(
            _value.viewport,
            itemCount: count,
            resetZoom: true,
          )
        : _value.viewport
            .copyWith(itemCount: count, itemExtent: _initialItemExtent);
    return next.copyWith(scrollOffsetItems: 0);
  }
}

List<String> _optionPanelIds(KChartOptions options) => List.unmodifiable([
      'main',
      for (final panel in options.secondaryPanels) panel.id,
    ]);

ChartViewport _alignLeft(ChartViewport viewport, double left) =>
    viewport.copyWith(
      scrollOffsetItems: viewport.itemCount +
          viewport.trailingPaddingItems -
          left -
          viewport.visibleItemCapacity,
    );
