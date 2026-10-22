import 'dart:math' as math;

import '../viewport/viewport.dart';
import 'k_chart_options.dart';

/// 仅供协调器与 Widget 使用；候选公共入口不导出这些扩展。
/// 把像素几何移出配置对象，宿主只描述意图，不负责布局与留白换算。
extension KChartViewportGeometry on KChartViewportOptions {
  /// 将策略换算为虚拟槽位，绘图区宽度不扣除右侧留白。
  ///
  /// 换算逐项对应 LegacyChartViewportMetrics 的 marginRight/minTranslateX，
  /// 包括数据不足一屏时的左对齐；不能简单用 width * fraction 替代。
  /// 先夹取实际槽宽再计算边界，避免缩放极限时留白与蜡烛使用不同的比例。
  ChartViewport resolveViewport(
    ChartViewport current, {
    int? itemCount,
    double? width,
    bool resetZoom = false,
  }) {
    final size = width ?? current.width;
    final next = current.copyWith(
      itemCount: itemCount,
      width: size,
      minItemExtent: minItemExtent,
      maxItemExtent: maxItemExtent,
      itemExtent: resetZoom && size > 0
          ? size / initialVisibleCandles
          : current.itemExtent,
    );
    if (next.itemCount == 0 || size == 0) {
      return next.copyWith(trailingPaddingItems: 0, futurePaddingItems: 0);
    }
    const pointWidth = ChartViewport.defaultItemExtent;
    final scale = next.itemExtent / pointWidth;
    var margin = (size * rightPaddingFraction - pointWidth) / scale;
    var translate = math.min(
      0.0,
      -next.itemCount * pointWidth + size / scale - pointWidth / 2,
    );
    final lastCenter = next.itemCount * pointWidth + pointWidth / 2;
    if (translate >= 0) {
      if (size / scale - lastCenter < margin) {
        translate -= margin - size / scale + lastCenter;
      } else {
        margin = size / scale - lastCenter;
      }
    } else {
      translate -= margin;
    }
    final trailing = math.max(
      0.0,
      math.min(0.0, translate).abs() / pointWidth +
          next.visibleItemCapacity -
          next.itemCount,
    );
    return next.copyWith(
      trailingPaddingItems: trailing,
      futurePaddingItems: allowLatestAtLeft
          ? math.max(0.0, next.visibleItemCapacity - trailing - 1)
          : 0,
      // 中间的 copyWith 可能按旧留白夹取偏移，最终只按新边界夹取一次。
      scrollOffsetItems: current.scrollOffsetItems,
    );
  }
}

extension KChartLayoutGeometry on KChartOptions {
  /// Widget 测量文字后提供参数栏高度；至少保留配置最小高度，固定高度模式不自动扩大。
  /// 无副图时时间轴位于底部；有副图时位于主副图之间，与 Demo 相同。
  ChartLayoutModel createLayout({
    required double width,
    required double height,
    double? measuredMainHeaderHeight,
    Map<String, double> measuredSecondaryHeaderHeights = const {},
  }) {
    final ids = secondaryPanels.map((panel) => panel.id).toSet();
    if (measuredSecondaryHeaderHeights.keys.any((id) => !ids.contains(id))) {
      throw ArgumentError(
        'Measured header belongs to an unknown secondary panel.',
      );
    }
    return ChartLayoutModel(
      width: width,
      height: height,
      gridColumns: gridColumns,
      panelSpacing: panelSpacing,
      bottomAxisHeight: secondaryPanels.isEmpty ? mainTimeAxisHeight : 0,
      mainTimeAxisHeight: secondaryPanels.isEmpty ? 0 : mainTimeAxisHeight,
      mainPanel: ChartPanelSpec.main(
        minHeight: mainPanel.minHeight,
        weight: mainPanel.weight,
        headerHeight: mainPanel._header(measuredMainHeaderHeight),
        gridRows: mainPanel.gridRows,
        showHorizontalGrid: mainPanel.showHorizontalGrid,
      ),
      secondaryPanels: [
        for (final panel in secondaryPanels)
          ChartPanelSpec.secondary(
            id: panel.id,
            minHeight: panel.layout.minHeight,
            weight: panel.layout.weight,
            headerHeight:
                panel.layout._header(measuredSecondaryHeaderHeights[panel.id]),
            gridRows: panel.layout.gridRows,
            showHorizontalGrid: panel.layout.showHorizontalGrid,
          ),
      ],
    );
  }
}

extension _PanelHeaderGeometry on KChartPanelOptions {
  double _header(double? measured) {
    if (measured != null) _finiteNonNegative(measured, 'measuredHeaderHeight');
    return autoHeaderHeight
        ? math.max(headerHeight, measured ?? 0)
        : headerHeight;
  }
}

void _finiteNonNegative(double value, String name) {
  if (!value.isFinite || value < 0) throw ArgumentError.value(value, name);
}
