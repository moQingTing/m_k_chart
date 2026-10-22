part of 'k_chart_data_coordinator.dart';

/// 面向宿主的只读状态候选 DTO，尚未进入正式公共 API。
///
/// 只能由协调器产生。私有构造复用已经冻结的行情/配置/覆盖物，避免每次选中、导航
/// 都复制整份 K 线。保留旧快照不会被后续提交改写；异常对象保留原引用供诊断。
final class KChartViewState {
  const KChartViewState._({
    required this.revision,
    required this.dataRevision,
    required this.session,
    required this.data,
    required this.options,
    required this.selection,
    required this.viewportInfo,
    required this.historyStatus,
    required this.issues,
    required this.overlays,
  });

  final int revision;
  final int dataRevision;
  final KChartDataSession session;
  final List<Kline> data;
  final KChartOptions options;
  final KChartSelection? selection;
  final KChartViewportInfo viewportInfo;
  final KChartHistoryPhase historyStatus;
  final List<KChartIssue> issues;
  final KChartOverlays overlays;
}

/// 数据身份与所选面板数值分离：副图命中值不是主图收盘价。
final class KChartSelection {
  const KChartSelection._({
    required this.candle,
    required this.previousCandle,
    required this.panelId,
    required this.value,
  });
  final Kline candle;
  final Kline? previousCandle;
  final String panelId;
  final double value;
}

/// 语义视口信息，不公开槽位、像素、变换对象或可变导航状态。
final class KChartViewportInfo {
  const KChartViewportInfo._({
    required this.isAttached,
    required this.hasLayout,
    required this.isAtLatest,
    required this.isAtOldest,
    required this.visibleStartTime,
    required this.visibleEndTime,
  });
  final bool isAttached;

  /// 表示已有非零宽度；解绑不抹掉最后一次布局，与 isAttached 分别判断。
  final bool hasLayout;

  /// 无布局或无行情时均为 false，不能据此误判空图已到历史末页。
  final bool isAtLatest;
  final bool isAtOldest;

  /// 可见槽位对应 K 线的开盘时间（含部分可见柱），不是虚拟留白时间。
  /// 无可见数据时成对为 null；毫秒值不因显示时区变化而改变。
  final int? visibleStartTime;
  final int? visibleEndTime;
}

enum KChartIssueKind { indicator, history }

/// 当前仍存在的问题，不是事件日志；修复/重试成功后从下一快照移除。
final class KChartIssue {
  const KChartIssue._({
    required this.kind,
    required this.instanceId,
    required this.error,
    required this.stackTrace,
  });
  final KChartIssueKind kind;
  final String? instanceId;
  final Object error;
  final StackTrace stackTrace;
}

/// 与内部状态共用同一监听器列表；此桥不提供 dispatch/notify/dispose 等写入口。
final class _ChartViewListenable implements ValueListenable<KChartViewState> {
  const _ChartViewListenable(this.owner);
  final KChartDataCoordinator owner;
  @override
  KChartViewState get value => owner._viewValue;
  @override
  void addListener(VoidCallback listener) => owner.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => owner.removeListener(listener);
}

KChartViewState _projectViewState(KChartRuntimeState state) {
  final range = state.viewport.visibleRange;
  final hasLayout = state.viewport.width > 0;
  final hasData = state.data.data.isNotEmpty && hasLayout;
  final candle = state.selectedCandle;
  return KChartViewState._(
    revision: state.revision,
    dataRevision: state.data.version.value,
    session: state.session,
    data: state.data.data,
    options: state.options,
    selection: candle == null
        ? null
        : KChartSelection._(
            candle: candle,
            previousCandle: state.previousSelectedCandle,
            panelId: state.selection!.panelId,
            value: state.selection!.price,
          ),
    viewportInfo: KChartViewportInfo._(
      isAttached: state.isAttached,
      hasLayout: hasLayout,
      isAtLatest: hasData && state.viewport.isAtLatest,
      isAtOldest: hasData && state.viewport.isAtOldest,
      visibleStartTime:
          range.isEmpty ? null : state.data.data[range.start].openTime,
      visibleEndTime:
          range.isEmpty ? null : state.data.data[range.end - 1].openTime,
    ),
    historyStatus: state.history.phase,
    issues: List.unmodifiable([
      for (final failure in state.indicatorBatch.failures.values)
        KChartIssue._(
          kind: KChartIssueKind.indicator,
          instanceId: failure.config.instanceId,
          error: failure.error,
          stackTrace: failure.stackTrace,
        ),
      if (state.history.phase == KChartHistoryPhase.failed)
        KChartIssue._(
          kind: KChartIssueKind.history,
          instanceId: null,
          error: state.history.error!,
          stackTrace: state.history.stackTrace!,
        ),
    ]),
    overlays: state.overlays,
  );
}
