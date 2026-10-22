import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controller/k_chart_data_coordinator.dart';
import '../controller/k_chart_history_contract.dart';
import '../controller/k_chart_options_geometry.dart';
import '../indicator/indicator.dart';
import '../model/model.dart';
import '../render/chart_layer_geometry.dart';
import '../render/render_snapshot.dart';
import '../theme/theme.dart';
import '../viewport/viewport.dart';
import 'k_chart_legend.dart';

/// 内部组件的一帧只读投射：布局、绘制和命中共享同一个状态版本。
///
/// 不持有另一份行情，不调用指标算法，不发送通知。未来公共 Widget 在此帧上叠加
/// 参数栏和信息面板；宿主不需要组装此对象或了解 RenderSnapshot。
final class KChartFrame {
  factory KChartFrame.project({
    required KChartDataCoordinator runtime,
    required Size size,
    required ChartRenderStyle style,
    required RenderSnapshotVersions versions,
    required int currentTime,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final state = runtime.value;
    final indicators = <RenderIndicatorSnapshot>[];
    for (final binding in state.indicators) {
      var result = state.indicatorBatch.results[binding.config.instanceId];
      // 失败实例已记入只读 issues，不让它阻断其他指标或蜡烛绘制。
      if (result == null) continue;
      var descriptor = runtime.rendererDescriptorFor(result.definitionId)!;
      // 显示选择只投射可见结果；原计算批次完整保留，切换线条无需重算。
      final shown = descriptor.series
          .where(
            (series) =>
                series.showInChart &&
                (binding.visibleSeriesIds == null ||
                    binding.visibleSeriesIds!.contains(series.id)),
          )
          .map((series) => series.id)
          .toSet();
      if (shown.length != descriptor.series.length) {
        result = IndicatorResult(
          instanceId: result.instanceId,
          definitionId: result.definitionId,
          dataVersion: result.dataVersion,
          length: result.length,
          series: result.series.where((series) => shown.contains(series.id)),
        );
        descriptor = IndicatorRendererDescriptor(
          placement: descriptor.placement,
          series:
              descriptor.series.where((series) => shown.contains(series.id)),
          includeZeroInRange: descriptor.includeZeroInRange,
          legend: IndicatorLegendDescriptor(
            display: descriptor.legend.display,
            labelTemplates: {
              for (final entry in descriptor.legend.labelTemplates.entries)
                if (shown.contains(entry.key)) entry.key: entry.value,
            },
            separator: descriptor.legend.separator,
            neutralLabel: descriptor.legend.neutralLabel,
          ),
        );
      }
      final placement = binding.panelId == 'main'
          ? IndicatorPlacement.mainChart
          : IndicatorPlacement.separatePanel;
      indicators.add(
        RenderIndicatorSnapshot.fromResult(
          result: result,
          panelId: binding.panelId,
          // 配置允许移动指标到另一面板；只改变呈现归属，不能改变算法或缓存身份。
          descriptor: placement == descriptor.placement
              ? descriptor
              : IndicatorRendererDescriptor(
                  placement: placement,
                  series: descriptor.series,
                  includeZeroInRange: descriptor.includeZeroInRange,
                  legend: descriptor.legend,
                ),
        ),
      );
    }

    final legends = <String, KChartLegendLayout>{
      for (final panelId in state.panelIds)
        panelId: KChartLegendLayout.measure(
          entries: kChartLegendEntries(
            state: state,
            indicators: indicators,
            panelId: panelId,
            style: style,
            parametersFor: runtime.indicatorParametersFor,
          ),
          width: math.max(0, size.width - 16),
          formatValue: panelId == 'main'
              ? style.formatMainValue
              : style.formatSecondaryValue,
          textScaler: textScaler,
        ),
    };
    final panels = {
      'main': state.options.mainPanel,
      for (final panel in state.options.secondaryPanels) panel.id: panel.layout,
    };
    // 很多指标或系统大字体不能把 K 线区挤没。先保留所有面板的最小内容/参数高度，
    // 再按比例分配可用的自动增长空间；固定高度及不足部分由参数栏等比缩小兜底。
    final extras = {
      for (final panel in panels.entries)
        panel.key: panel.value.autoHeaderHeight
            ? math.max(
                0.0,
                legends[panel.key]!.height - panel.value.headerHeight,
              )
            : 0.0,
    };
    final remaining = math.max(
      0.0,
      size.height -
          state.options.mainTimeAxisHeight -
          state.options.panelSpacing * (panels.length - 1) -
          panels.values.fold(
            0.0,
            (sum, panel) => sum + panel.minHeight + panel.headerHeight,
          ) -
          0.000001,
    );
    final requested = extras.values.fold(0.0, (sum, extra) => sum + extra);
    final fraction =
        requested == 0 ? 1.0 : math.min(1.0, remaining / requested);
    final measured = {
      for (final panel in panels.entries)
        panel.key: panel.value.headerHeight + extras[panel.key]! * fraction,
    };
    final layout = state.options.createLayout(
      width: size.width,
      height: size.height,
      measuredMainHeaderHeight: measured['main'],
      measuredSecondaryHeaderHeights: {
        for (final panel in state.options.secondaryPanels)
          panel.id: measured[panel.id]!,
      },
    );

    RenderSnapshot<ChartRenderStyle> snapshot(
      RenderSelectionSnapshot selection,
    ) =>
        RenderSnapshot(
          data: state.data,
          viewport: state.viewport,
          layout: layout,
          theme: style,
          versions: versions,
          indicators: indicators,
          selection: selection,
          history: RenderHistorySnapshot(
            phase: switch (state.history.phase) {
              KChartHistoryPhase.idle => RenderHistoryPhase.idle,
              KChartHistoryPhase.loading => RenderHistoryPhase.loading,
              KChartHistoryPhase.exhausted => RenderHistoryPhase.noMore,
              KChartHistoryPhase.failed => RenderHistoryPhase.failure,
            },
          ),
          anchoredDrawings: state.overlays.drawings,
          priceLines: state.overlays.priceLines,
          eventOverlays: state.overlays.events,
          valueMarkers: state.overlays.valueMarkers,
          mainMode: state.options.mainMode,
          timeZoneOffset: state.options.timeZoneOffset,
          currentTime: currentTime,
          showIntermediateTimeAxis: true,
          axisTimeFormatter: (time, offset) => formatKChartTime(
            time,
            state.session.series.interval,
            offset,
          ),
          crosshairTimeFormatter: (time, _, offset) => formatKChartTime(
            time,
            state.session.series.interval,
            offset,
          ),
        );

    final base = snapshot(const RenderSelectionSnapshot.hidden());
    final anchor = state.selection;
    final index = state.selectedIndex;
    if (anchor == null || index == null) {
      return KChartFrame._(state, base, legends);
    }
    final panel = layout.panel(anchor.panelId);
    final x = ChartXTransform(viewport: state.viewport, data: state.data)
        .indexToLocalX(index);
    final y = ChartLayerGeometry.rangeFor(base, anchor.panelId)
        .transform(panel.bounds)
        .priceToLocalY(anchor.price);
    return KChartFrame._(
      state,
      snapshot(
        RenderSelectionSnapshot.visible(
          // 面板命中是左闭右开/上闭下开；夹到右/下边界本身会丢失副图身份，
          // 导致缩放后越界的副图选中值误用主图格式。保持在边界内一个极小量。
          localX: x.clamp(
            panel.bounds.left,
            panel.bounds.right - math.min(0.000001, panel.bounds.width / 2),
          ),
          localY: y.clamp(
            panel.bounds.top,
            panel.bounds.bottom - math.min(0.000001, panel.bounds.height / 2),
          ),
          dataIndex: index,
          price: anchor.price,
          valueKind: RenderSelectionValueKind.close,
        ),
      ),
      legends,
    );
  }

  KChartFrame._(
    this.state,
    this.snapshot,
    Map<String, KChartLegendLayout> legends,
  ) : legends = Map.unmodifiable(legends);

  KChartFrame._reuse(this.state, this.snapshot, this.legends);

  /// 非视觉控制器事务只更新状态身份，不更换已投射的像素输入。
  /// 调用方必须先确认数据、选中、布局和其他可见输入完全相同。
  KChartFrame withRuntimeState(KChartRuntimeState state) =>
      KChartFrame._reuse(state, snapshot, legends);

  /// 倒计时变化不重做指标投射、图例测量和面板布局。
  /// 调用前由 Surface 确认控制器状态与非时钟版本均未改变。
  KChartFrame withClock({
    required int currentTime,
    required RenderSnapshotVersions versions,
  }) =>
      KChartFrame._reuse(
        state,
        snapshot.withClock(currentTime: currentTime, versions: versions),
        legends,
      );

  final KChartRuntimeState state;
  final RenderSnapshot<ChartRenderStyle> snapshot;
  final Map<String, KChartLegendLayout> legends;

  /// 参数栏、时间轴和面板间距不参与数据命中；副图用自身量程而不是主图价格。
  ({int openTime, String panelId, double price})? hitTest(Offset position) {
    if (state.data.data.isEmpty) return null;
    for (final panel in snapshot.layout.panels) {
      if (!panel.bounds.contains(x: position.dx, y: position.dy)) continue;
      final index = ChartXTransform(viewport: state.viewport, data: state.data)
          .localXToNearestIndex(position.dx);
      final price = ChartLayerGeometry.rangeFor(snapshot, panel.spec.id)
          .transform(panel.bounds)
          .localYToPrice(position.dy);
      return (
        openTime: state.data.data[index].openTime,
        panelId: panel.spec.id,
        price: price,
      );
    }
    return null;
  }
}

/// 按周期本身确定精度，不从 code 猜测；因此自定义周期也遵守同一规则。
/// 原始时间为 UTC 毫秒，显示偏移只应用一次。
String formatKChartTime(int time, KlineInterval interval, Duration offset) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    time + offset.inMilliseconds,
    isUtc: true,
  );
  String two(int value) => value.toString().padLeft(2, '0');
  final month = '${date.year}-${two(date.month)}';
  if (interval.kind == KlineIntervalKind.calendarMonth) return month;
  final day = '$month-${two(date.day)}';
  if (interval.duration! >= const Duration(days: 1)) return day;
  final hour = '$day ${two(date.hour)}';
  if (interval.duration! >= const Duration(hours: 1)) return '$hour:00';
  final minute = '$hour:${two(date.minute)}';
  if (interval.duration! >= const Duration(minutes: 1)) return minute;
  return '$minute:${two(date.second)}';
}
