import 'package:flutter/foundation.dart';

import '../interaction/interaction.dart';
import '../model/model.dart';
import 'k_chart_event.dart';
import 'k_chart_state.dart';

/// 管理单个图表实例的状态与通知生命周期。
///
/// 公开包暂未导出该内部入口。所有输入均经 [dispatch] 或 [dispatchBatch] 归约，使状态变更
/// 保持原子性；业务层不应直接修改 [KChartState] 的局部字段。
final class KChartController extends ChangeNotifier
    implements ValueListenable<KChartState> {
  KChartController({KChartState initialState = const KChartState()})
      : _value = initialState;

  KChartState _value;
  bool _isDisposed = false;

  @override
  KChartState get value => _value;

  bool get isDisposed => _isDisposed;

  void scrollToLatest() {
    dispatch(
      ChartViewportChanged(ChartViewportNavigator.toLatest(_value.viewport)),
    );
  }

  void scrollToTime({
    required VersionedKlineData data,
    required int epochMilliseconds,
    double alignment = 0.5,
  }) {
    dispatch(
      ChartViewportChanged(
        ChartViewportNavigator.locateTime(
          viewport: _value.viewport,
          data: data,
          epochMilliseconds: epochMilliseconds,
          alignment: alignment,
        ),
      ),
    );
  }

  void preserveViewportAfterPrepend({required int prependedItemCount}) {
    dispatch(
      ChartViewportChanged(
        ChartViewportNavigator.preserveAfterPrepend(
          _value.viewport,
          prependedItemCount: prependedItemCount,
        ),
      ),
    );
  }

  /// 为实时追加、最新 K 线替换或滚动窗口刷新更新视口。
  void preserveViewportAfterRealtimeDataChange({
    required int nextItemCount,
    required int appendedItemCount,
    bool followLatest = true,
  }) {
    dispatch(
      ChartViewportChanged(
        ChartViewportNavigator.preserveAfterRealtimeDataChange(
          _value.viewport,
          nextItemCount: nextItemCount,
          appendedItemCount: appendedItemCount,
          followLatest: followLatest,
        ),
      ),
    );
  }

  bool requestHistoryIfNeeded({double thresholdItems = 2}) {
    _ensureActive();
    final next = _value.historyPaging.requestIfNeeded(
      _value.viewport,
      thresholdItems: thresholdItems,
    );
    if (identical(next, _value.historyPaging)) {
      return false;
    }
    dispatch(ChartHistoryPagingChanged(next));
    return true;
  }

  void completeHistoryRequest({required bool hasMore}) {
    dispatch(
      ChartHistoryPagingChanged(
        _value.historyPaging.complete(hasMore: hasMore),
      ),
    );
  }

  void failHistoryRequest() {
    dispatch(ChartHistoryPagingChanged(_value.historyPaging.fail()));
  }

  void resetHistoryPaging() {
    dispatch(ChartHistoryPagingChanged(_value.historyPaging.reset()));
  }

  /// 将一个强类型事件归约为一次不可变状态事务。
  void dispatch(KChartEvent event) {
    dispatchBatch([event]);
  }

  /// 将交互层意图转换为所属的强类型事件。
  void dispatchInteraction(ChartInteractionIntent intent) {
    switch (intent) {
      case ChartViewportIntent(:final viewport):
        dispatch(ChartViewportChanged(viewport));
      case ChartCrosshairIntent(:final state):
        dispatch(ChartSelectionChanged(state));
      case ChartHistoryPagingIntent(:final state):
        dispatch(ChartHistoryPagingChanged(state));
    }
  }

  /// 原子地归约多个事件，最多发布一次通知。
  ///
  /// 批处理收集受影响状态切片的并集；空批处理保持状态身份且不会通知监听器。
  void dispatchBatch(Iterable<KChartEvent> events) {
    _ensureActive();
    final changedSlices = <StateSlice>{};
    var viewport = _value.viewport;
    var layout = _value.layout;
    var crosshair = _value.crosshair;
    var historyPaging = _value.historyPaging;
    for (final event in events) {
      if (event case ChartViewportChanged(viewport: final next)) {
        viewport = next;
        continue;
      }
      if (event case ChartLayoutChanged(layout: final next)) {
        layout = next;
        continue;
      }
      if (event case ChartSelectionChanged(crosshair: final next)) {
        crosshair = next;
        continue;
      }
      if (event case ChartHistoryPagingChanged(state: final next)) {
        historyPaging = next;
        continue;
      }
      changedSlices.addAll(event.changedSlices);
    }
    if (layout != null) {
      viewport = layout.applyTo(viewport);
    }
    if (viewport != _value.viewport) {
      changedSlices.add(StateSlice.viewport);
    }
    if (layout != _value.layout) {
      changedSlices.add(StateSlice.layout);
    }
    if (crosshair != _value.crosshair) {
      changedSlices.add(StateSlice.selection);
    }
    if (historyPaging != _value.historyPaging) {
      changedSlices.add(StateSlice.history);
    }
    _commit(
      _value.bump(
        changedSlices,
        viewport: viewport,
        layout: layout,
        crosshair: crosshair,
        historyPaging: historyPaging,
      ),
    );
  }

  void _commit(KChartState next) {
    if (identical(next, _value)) {
      return;
    }

    _value = next;
    notifyListeners();
  }

  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('KChartController has been disposed.');
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    super.dispose();
  }
}
