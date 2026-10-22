import '../model/model.dart';
import 'k_chart_data_session.dart';

/// 宿主负责实际网络请求及取消；SDK 只接受仍有效的请求结果。
/// 当前为内部契约，尚未从正式公共入口导出。
typedef KChartHistoryLoader = Future<KChartHistoryPage> Function(
  KChartHistoryRequest request,
);

/// 一次向左分页的边界；所有返回 K 线必须严格早于 [beforeOpenTime]。
final class KChartHistoryRequest {
  const KChartHistoryRequest({
    required this.session,
    required this.requestId,
    required this.beforeOpenTime,
  });

  final KChartDataSession session;

  /// 单个协调器内单调递增，换序列也不重置；不能跨实例单独用此数字判断有效性。
  final int requestId;

  /// UTC epoch 毫秒，不是列表下标或本地时区时间。
  final int beforeOpenTime;
}

/// 历史响应冻结宿主集合；排序、序列与请求边界在提交前统一校验。
final class KChartHistoryPage {
  KChartHistoryPage({required Iterable<Kline> candles, required this.hasMore})
      : candles = List<Kline>.unmodifiable(candles);

  final List<Kline> candles;
  final bool hasMore;
}

enum KChartHistoryPhase { idle, loading, exhausted, failed }

/// 内部只读分页快照，与数据、视口和选中状态一并提交。
/// 失败保留 request/error/stackTrace 供上层显示和诊断，不清空现有行情。
final class KChartHistoryState {
  const KChartHistoryState.idle()
      : phase = KChartHistoryPhase.idle,
        request = null,
        error = null,
        stackTrace = null;

  const KChartHistoryState.loading(KChartHistoryRequest this.request)
      : phase = KChartHistoryPhase.loading,
        error = null,
        stackTrace = null;

  const KChartHistoryState.exhausted()
      : phase = KChartHistoryPhase.exhausted,
        request = null,
        error = null,
        stackTrace = null;

  const KChartHistoryState.failed({
    required KChartHistoryRequest this.request,
    required Object this.error,
    required StackTrace this.stackTrace,
  }) : phase = KChartHistoryPhase.failed;

  final KChartHistoryPhase phase;
  final KChartHistoryRequest? request;
  final Object? error;
  final StackTrace? stackTrace;
}
