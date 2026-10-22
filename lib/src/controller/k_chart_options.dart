import 'package:flutter/foundation.dart';

import '../model/chart_main_mode.dart';
import '../viewport/chart_viewport.dart' show ChartViewport;
import 'k_chart_indicator_binding.dart';

/// 面板几何配置，尺寸均为逻辑像素；headerHeight 不包含在 minHeight 中。
/// 主图默认与 Demo 一致，副图默认值由 KChartSecondaryPanelOptions 提供。
final class KChartPanelOptions {
  KChartPanelOptions({
    this.minHeight = 220,
    this.headerHeight = 18,
    this.autoHeaderHeight = true,
    this.weight = 3,
    this.gridRows = 4,
    this.showHorizontalGrid = true,
  }) {
    _finiteNonNegative(minHeight, 'minHeight');
    if (minHeight == 0) throw ArgumentError.value(minHeight, 'minHeight');
    _finiteNonNegative(headerHeight, 'headerHeight');
    if (!weight.isFinite || weight <= 0) {
      throw ArgumentError.value(weight, 'weight');
    }
    if (gridRows < 1) throw ArgumentError.value(gridRows, 'gridRows');
  }

  final double minHeight;
  final double headerHeight;
  final bool autoHeaderHeight;
  final double weight;

  /// 网格分段数；4 段即 5 条含上下边缘的横线。
  final int gridRows;
  final bool showHorizontalGrid;

  KChartPanelOptions copyWith({
    double? minHeight,
    double? headerHeight,
    bool? autoHeaderHeight,
    double? weight,
    int? gridRows,
    bool? showHorizontalGrid,
  }) =>
      KChartPanelOptions(
        minHeight: minHeight ?? this.minHeight,
        headerHeight: headerHeight ?? this.headerHeight,
        autoHeaderHeight: autoHeaderHeight ?? this.autoHeaderHeight,
        weight: weight ?? this.weight,
        gridRows: gridRows ?? this.gridRows,
        showHorizontalGrid: showHorizontalGrid ?? this.showHorizontalGrid,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartPanelOptions &&
          minHeight == other.minHeight &&
          headerHeight == other.headerHeight &&
          autoHeaderHeight == other.autoHeaderHeight &&
          weight == other.weight &&
          gridRows == other.gridRows &&
          showHorizontalGrid == other.showHorizontalGrid;

  @override
  int get hashCode => Object.hash(
        minHeight,
        headerHeight,
        autoHeaderHeight,
        weight,
        gridRows,
        showHorizontalGrid,
      );
}

/// 稳定面板身份与几何分离；同一副图可以绑定多个指标实例。
final class KChartSecondaryPanelOptions {
  KChartSecondaryPanelOptions({required this.id, KChartPanelOptions? layout})
      : layout = layout ??
            KChartPanelOptions(
              minHeight: 108,
              weight: 1,
              gridRows: 2,
              autoHeaderHeight: false,
            ) {
    if (id.trim().isEmpty || id == 'main') throw ArgumentError.value(id, 'id');
  }

  final String id;
  final KChartPanelOptions layout;

  KChartSecondaryPanelOptions copyWith({
    String? id,
    KChartPanelOptions? layout,
  }) =>
      KChartSecondaryPanelOptions(
        id: id ?? this.id,
        layout: layout ?? this.layout,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartSecondaryPanelOptions &&
          id == other.id &&
          layout == other.layout;
  @override
  int get hashCode => Object.hash(id, layout);
}

/// 视口策略值对象，不包含像素位置或正在使用的缩放状态。
/// 协调器负责应用策略；平移/缩放仍由既有导航算法生成候选视口。
final class KChartViewportOptions {
  KChartViewportOptions({
    this.initialVisibleCandles = 90,
    this.minItemExtent = ChartViewport.defaultMinItemExtent,
    this.maxItemExtent = ChartViewport.defaultMaxItemExtent,
    this.rightPaddingFraction = 0.2,
    this.allowLatestAtLeft = true,
  }) {
    if (initialVisibleCandles < 1) {
      throw ArgumentError.value(initialVisibleCandles, 'initialVisibleCandles');
    }
    if (!minItemExtent.isFinite ||
        !maxItemExtent.isFinite ||
        minItemExtent <= 0 ||
        maxItemExtent < minItemExtent) {
      throw ArgumentError('Item extents must be finite, positive and ordered.');
    }
    if (!rightPaddingFraction.isFinite ||
        rightPaddingFraction < 0 ||
        rightPaddingFraction >= 1) {
      throw ArgumentError.value(rightPaddingFraction, 'rightPaddingFraction');
    }
  }

  final int initialVisibleCandles;
  final double minItemExtent;
  final double maxItemExtent;

  /// 旧版默认以宽度的 1/5 推导右侧虚拟空隙，不是裁掉绘图区的物理 padding。
  final double rightPaddingFraction;
  final bool allowLatestAtLeft;

  KChartViewportOptions copyWith({
    int? initialVisibleCandles,
    double? minItemExtent,
    double? maxItemExtent,
    double? rightPaddingFraction,
    bool? allowLatestAtLeft,
  }) =>
      KChartViewportOptions(
        initialVisibleCandles:
            initialVisibleCandles ?? this.initialVisibleCandles,
        minItemExtent: minItemExtent ?? this.minItemExtent,
        maxItemExtent: maxItemExtent ?? this.maxItemExtent,
        rightPaddingFraction: rightPaddingFraction ?? this.rightPaddingFraction,
        allowLatestAtLeft: allowLatestAtLeft ?? this.allowLatestAtLeft,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartViewportOptions &&
          initialVisibleCandles == other.initialVisibleCandles &&
          minItemExtent == other.minItemExtent &&
          maxItemExtent == other.maxItemExtent &&
          rightPaddingFraction == other.rightPaddingFraction &&
          allowLatestAtLeft == other.allowLatestAtLeft;
  @override
  int get hashCode => Object.hash(
        initialVisibleCandles,
        minItemExtent,
        maxItemExtent,
        rightPaddingFraction,
        allowLatestAtLeft,
      );
}

/// V2 运行时配置的内部候选值对象，不是 JSON 偏好，也未正式公开。
///
/// 样式/格式化留在 KChartTheme；序列身份留在 session；网络与存储仍由宿主负责。
/// 已接入协调器与候选 Controller；几何换算在内部扩展中，Widget 与正式准入仍待完成。
final class KChartOptions {
  factory KChartOptions({
    ChartMainMode mainMode = ChartMainMode.candlestick,
    KChartPanelOptions? mainPanel,
    Iterable<KChartSecondaryPanelOptions> secondaryPanels = const [],
    Iterable<KChartIndicatorBinding> indicators = const [],
    KChartViewportOptions? viewport,
    Duration timeZoneOffset = const Duration(hours: 8),
    double mainTimeAxisHeight = 18,
    double panelSpacing = 0,
    int gridColumns = 2,
    int maxOutOfOrderCandles = 2,
    double historyThresholdItems = 2,
  }) {
    final panels =
        List<KChartSecondaryPanelOptions>.unmodifiable(secondaryPanels);
    final ids = <String>{'main'};
    for (final panel in panels) {
      if (!ids.add(panel.id)) {
        throw ArgumentError('Duplicate panel id: ${panel.id}');
      }
    }
    final bindings = validateKChartIndicatorBindings(indicators, ids);
    if (timeZoneOffset < const Duration(hours: -12) ||
        timeZoneOffset > const Duration(hours: 14) ||
        timeZoneOffset.inMicroseconds % Duration.microsecondsPerMinute != 0) {
      throw ArgumentError.value(timeZoneOffset, 'timeZoneOffset');
    }
    _finiteNonNegative(mainTimeAxisHeight, 'mainTimeAxisHeight');
    _finiteNonNegative(panelSpacing, 'panelSpacing');
    _finiteNonNegative(historyThresholdItems, 'historyThresholdItems');
    if (gridColumns < 1) throw ArgumentError.value(gridColumns, 'gridColumns');
    if (maxOutOfOrderCandles < 0) {
      throw ArgumentError.value(maxOutOfOrderCandles, 'maxOutOfOrderCandles');
    }
    return KChartOptions._(
      mainMode,
      mainPanel ?? KChartPanelOptions(),
      panels,
      bindings,
      viewport ?? KChartViewportOptions(),
      timeZoneOffset,
      mainTimeAxisHeight,
      panelSpacing,
      gridColumns,
      maxOutOfOrderCandles,
      historyThresholdItems,
    );
  }

  const KChartOptions._(
    this.mainMode,
    this.mainPanel,
    this.secondaryPanels,
    this.indicators,
    this.viewport,
    this.timeZoneOffset,
    this.mainTimeAxisHeight,
    this.panelSpacing,
    this.gridColumns,
    this.maxOutOfOrderCandles,
    this.historyThresholdItems,
  );

  final ChartMainMode mainMode;
  final KChartPanelOptions mainPanel;
  final List<KChartSecondaryPanelOptions> secondaryPanels;
  final List<KChartIndicatorBinding> indicators;
  final KChartViewportOptions viewport;
  final Duration timeZoneOffset;
  final double mainTimeAxisHeight;
  final double panelSpacing;
  final int gridColumns;
  final int maxOutOfOrderCandles;
  final double historyThresholdItems;

  KChartOptions copyWith({
    ChartMainMode? mainMode,
    KChartPanelOptions? mainPanel,
    Iterable<KChartSecondaryPanelOptions>? secondaryPanels,
    Iterable<KChartIndicatorBinding>? indicators,
    KChartViewportOptions? viewport,
    Duration? timeZoneOffset,
    double? mainTimeAxisHeight,
    double? panelSpacing,
    int? gridColumns,
    int? maxOutOfOrderCandles,
    double? historyThresholdItems,
  }) =>
      KChartOptions(
        mainMode: mainMode ?? this.mainMode,
        mainPanel: mainPanel ?? this.mainPanel,
        secondaryPanels: secondaryPanels ?? this.secondaryPanels,
        indicators: indicators ?? this.indicators,
        viewport: viewport ?? this.viewport,
        timeZoneOffset: timeZoneOffset ?? this.timeZoneOffset,
        mainTimeAxisHeight: mainTimeAxisHeight ?? this.mainTimeAxisHeight,
        panelSpacing: panelSpacing ?? this.panelSpacing,
        gridColumns: gridColumns ?? this.gridColumns,
        maxOutOfOrderCandles: maxOutOfOrderCandles ?? this.maxOutOfOrderCandles,
        historyThresholdItems:
            historyThresholdItems ?? this.historyThresholdItems,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartOptions &&
          mainMode == other.mainMode &&
          mainPanel == other.mainPanel &&
          listEquals(secondaryPanels, other.secondaryPanels) &&
          listEquals(indicators, other.indicators) &&
          viewport == other.viewport &&
          timeZoneOffset == other.timeZoneOffset &&
          mainTimeAxisHeight == other.mainTimeAxisHeight &&
          panelSpacing == other.panelSpacing &&
          gridColumns == other.gridColumns &&
          maxOutOfOrderCandles == other.maxOutOfOrderCandles &&
          historyThresholdItems == other.historyThresholdItems;
  @override
  int get hashCode => Object.hash(
        mainMode,
        mainPanel,
        Object.hashAll(secondaryPanels),
        Object.hashAll(indicators),
        viewport,
        timeZoneOffset,
        mainTimeAxisHeight,
        panelSpacing,
        gridColumns,
        maxOutOfOrderCandles,
        historyThresholdItems,
      );
}

void _finiteNonNegative(double value, String name) {
  if (!value.isFinite || value < 0) throw ArgumentError.value(value, name);
}
