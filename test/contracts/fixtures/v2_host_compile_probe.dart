import 'dart:async';

import 'package:m_k_chart/src/controller/k_chart_data_contract.dart';
import 'package:m_k_chart/src/model/model.dart';

/// 仅供仓库契约编译检查，不是已发布 SDK 示例，也不创建替身 KChart Widget。
/// OPT-03/04 实现后改由真正的公开 Controller 接入验收测试。
Future<KChartDataUpdateResult> loadSeries(
  KChartDataCommands chart,
  KlineSeries series,
  Future<List<Kline>> Function(KlineSeries) load,
) async {
  // 必须在发出请求前捕获，而不是 await 完成后使用 chart.session。
  final session = chart.beginSeries(series);
  final candles = await load(series);
  return chart.replaceData(candles, session: session);
}

/// 真实宿主必须取消订阅；令牌仅阻止旧数据写入，不代替释放网络资源。
StreamSubscription<Kline> subscribeRealtime(
  KChartDataCommands chart,
  Stream<Kline> stream,
  void Function(KChartDataUpdateResult) onResult,
  void Function(Object, StackTrace) onError,
) {
  final session = chart.session;
  return stream.listen(
    (candle) => onResult(chart.updateKline(candle, session: session)),
    onError: onError,
  );
}

/// 这些调用由 Dart 编译器检查数据命令参数，而不是依赖文档中的伪代码。
void verifyDataCommandSignatures(KChartDataCommands chart) {
  final session =
      chart.beginSeries(chart.session.series, initialData: const []);
  chart.replaceData(
    const [],
    session: session,
    viewportPolicy: KChartDataViewportPolicy.resetToLatest,
  );
  chart.appendData(const [], session: session);
  chart.prependHistory(const [], session: session);
}
