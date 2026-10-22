import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/k_chart_data_coordinator.dart';
import '../controller/k_chart_options.dart';
import '../render/render_snapshot.dart';
import '../theme/theme.dart';

/// 将候选 Widget 的实际输入变化映射到渲染图层的失效切片。
///
/// Controller 的聚合 revision 不能直接作为所有图层的版本：时钟每秒变化时，
/// K 线、网格和坐标轴的输入并未变化。此对象只属于单个 Surface，换 Controller 时重建，
/// 防止两个图表的缓存版本串用。
final class KChartRenderVersionTracker {
  KChartRuntimeState? _previous;
  Size? _size;
  ChartRenderStyle? _style;
  TextScaler? _textScaler;
  int? _currentTime;
  RenderSnapshotVersions _versions = const RenderSnapshotVersions();

  RenderSnapshotVersions advance({
    required KChartRuntimeState state,
    required Size size,
    required ChartRenderStyle style,
    required TextScaler textScaler,
    required int currentTime,
  }) {
    final old = _previous;
    if (old == null) {
      _remember(state, size, style, textScaler, currentTime);
      return _versions;
    }

    final dataChanged = !identical(old.data, state.data) ||
        !identical(old.indicatorBatch, state.indicatorBatch) ||
        !identical(old.session, state.session);
    final viewportChanged = old.viewport != state.viewport;
    final layoutChanged =
        !kChartSameVisualOptions(old.options, state.options) ||
            _size != size ||
            _textScaler != textScaler;
    final selectionChanged = old.selection != state.selection ||
        old.selectedIndex != state.selectedIndex ||
        // 十字线的坐标会随选中柱的量程、位置变化，即使锚点身份不变。
        (state.selection != null &&
            (dataChanged || viewportChanged || layoutChanged));
    final drawingsChanged =
        !listEquals(old.overlays.drawings, state.overlays.drawings);
    final overlaysChanged =
        !listEquals(old.overlays.priceLines, state.overlays.priceLines) ||
            !listEquals(old.overlays.events, state.overlays.events) ||
            !listEquals(old.overlays.valueMarkers, state.overlays.valueMarkers);
    final localeChanged =
        old.session.series.interval != state.session.series.interval ||
            old.options.timeZoneOffset != state.options.timeZoneOffset;

    _versions = RenderSnapshotVersions(
      data: _versions.data + (dataChanged ? 1 : 0),
      viewport: _versions.viewport + (viewportChanged ? 1 : 0),
      selection: _versions.selection + (selectionChanged ? 1 : 0),
      history: _versions.history +
          (old.history.phase != state.history.phase ? 1 : 0),
      layout: _versions.layout + (layoutChanged ? 1 : 0),
      theme: _versions.theme + (!identical(_style, style) ? 1 : 0),
      drawings: _versions.drawings + (drawingsChanged ? 1 : 0),
      overlays: _versions.overlays + (overlaysChanged ? 1 : 0),
      clock: _versions.clock + (_currentTime != currentTime ? 1 : 0),
      locale: _versions.locale + (localeChanged ? 1 : 0),
    );
    _remember(state, size, style, textScaler, currentTime);
    return _versions;
  }

  void _remember(
    KChartRuntimeState state,
    Size size,
    ChartRenderStyle style,
    TextScaler textScaler,
    int currentTime,
  ) {
    _previous = state;
    _size = size;
    _style = style;
    _textScaler = textScaler;
    _currentTime = currentTime;
  }
}

/// 仅比较会改变图表像素/图例的配置；请求阈值和导航策略由后续命令生效。
/// Surface 的无效通知判断与版本推进共用此规则，避免一处跳过、另一处却失效缓存。
bool kChartSameVisualOptions(KChartOptions a, KChartOptions b) =>
    a.mainMode == b.mainMode &&
    a.mainPanel == b.mainPanel &&
    listEquals(a.secondaryPanels, b.secondaryPanels) &&
    listEquals(a.indicators, b.indicators) &&
    a.timeZoneOffset == b.timeZoneOffset &&
    a.mainTimeAxisHeight == b.mainTimeAxisHeight &&
    a.panelSpacing == b.panelSpacing &&
    a.gridColumns == b.gridColumns;
