import '../model/model.dart';
import 'k_chart_data_session.dart';

/// 同一序列全量同步后的视口策略，不代表切换交易对。
enum KChartDataViewportPolicy { preserve, resetToLatest }

/// 数据写入结果；非法参数抛 ArgumentError，不与可预期的在途结果失效混淆。
enum KChartDataUpdateStatus {
  applied,
  unchanged,
  ignoredStaleSession,
  rejectedClosedCorrection,
  rejectedOutsideWindow,
}

/// 数据事务的只读回执，不暴露 Store 或渲染快照。
final class KChartDataUpdateResult {
  KChartDataUpdateResult({required this.status, required this.dataRevision}) {
    if (dataRevision < 0) {
      throw ArgumentError.value(dataRevision, 'dataRevision', 'Must be >= 0.');
    }
  }

  final KChartDataUpdateStatus status;

  /// 事务结束后的数据版本；被忽略/拒绝或数据未变时，版本不递增。
  final int dataRevision;

  bool get changed => status == KChartDataUpdateStatus.applied;
  bool get requiresReload =>
      status == KChartDataUpdateStatus.rejectedOutsideWindow;
}

/// OPT-02 冻结的数据命令签名；候选 KChartController 已实现此接口，尚未正式公开。
///
/// 内部 KChartDataCoordinator 实现事务，新 facade 委托给它；Widget 仍待组装。
/// 不能用此接口替代现有内部 KChartController，也不能从 m_k_chart.dart 接入 V2 图表。
///
/// 所有输入集合由实现复制，要求同一序列、开盘时间严格升序且唯一。校验/计算成功后
/// 一次性更新数据、选中和视口，至多通知一次；失败不能留下部分状态。
/// 带 session 的命令必须先检查令牌，过期（含跨实例、已销毁）的结果在遍历输入前返回
/// ignoredStaleSession。导航/配置/开始会话等主动命令在销毁后抛 StateError。
abstract interface class KChartDataCommands {
  KChartDataSession get session;

  /// 立即切换序列并使旧请求失效；initialData 可为空。即使 series 未变也建立新会话。
  /// 校验失败保留旧会话；成功时重置视口、选中、历史分页及序列相关覆盖物。
  KChartDataSession beginSeries(
    KlineSeries series, {
    Iterable<Kline> initialData = const [],
  });

  /// 权威窗口替换，可裁剪/清空窗口，但不能隐式换交易对或周期。
  /// preserve 以原可见时间锚定，锚点不再存在则夹取边界；仍在最新位置时继续跟随最新。
  KChartDataUpdateResult replaceData(
    Iterable<Kline> data, {
    required KChartDataSession session,
    KChartDataViewportPolicy viewportPolicy = KChartDataViewportPolicy.preserve,
  });

  /// 严格追加：首条必须晚于现有末条。重复或重叠请由宿主整理，不静默去重。
  KChartDataUpdateResult appendData(
    Iterable<Kline> data, {
    required KChartDataSession session,
  });

  /// 严格前插：末条必须早于现有首条。保留当前可见 K 线位置和有效选中。
  KChartDataUpdateResult prependHistory(
    Iterable<Kline> data, {
    required KChartDataSession session,
  });

  /// 合并实时单条：替换同身份、新增最新或在配置的乱序窗口内插入。
  /// 已收盘柱默认拒绝修正；明确开启 allowClosedCorrection 后才可覆盖。
  /// 过旧的新柱返回 rejectedOutsideWindow，宿主可据 requiresReload 重新同步。
  KChartDataUpdateResult updateKline(
    Kline candle, {
    required KChartDataSession session,
    bool allowClosedCorrection = false,
  });
}
