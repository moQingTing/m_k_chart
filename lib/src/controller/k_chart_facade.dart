import 'package:flutter/foundation.dart';

import '../drawing/chart_drawing.dart';
import '../indicator/indicator_catalog_entry.dart';
import '../indicator/indicator_definition.dart';
import '../indicator/indicator_parameter_spec.dart';
import '../model/model.dart';
import 'k_chart_data_contract.dart';
import 'k_chart_data_coordinator.dart';
import 'k_chart_data_session.dart';
import 'k_chart_history_contract.dart';
import 'k_chart_options.dart';

/// 面向宿主的 V2 控制器候选实现，尚未从 m_k_chart.dart 正式导出。
///
/// 宿主创建并销毁；Widget 只借用控制器，不代为销毁。所有状态与通知均委托给唯一
/// 协调器，不维护另一份数据、配置、视口或会话，也不公开 dispatch/notifyListeners。
/// 与旧内部事件控制器同名但库不同，旧 Demo 的导入和行为保持不变。
final class KChartController
    implements KChartDataCommands, ValueListenable<KChartViewState> {
  KChartController({
    required KlineSeries series,
    Iterable<Kline> initialData = const [],
    KChartOptions? options,
    KChartHistoryLoader? historyLoader,
    Iterable<IndicatorDefinition> indicatorDefinitions = const [],
  }) : _runtime = KChartDataCoordinator(
          series: series,
          initialData: initialData,
          options: options,
          historyLoader: historyLoader,
          indicatorDefinitions: indicatorDefinitions,
        );

  final KChartDataCoordinator _runtime;

  @override
  KChartViewState get value => _runtime.view.value;

  @override
  KChartDataSession get session => _runtime.session;

  bool get isDisposed => _runtime.isDisposed;

  /// 已注册指标的只读目录，用于设置界面；自定义定义在构造时注入。
  List<IndicatorCatalogEntry> get indicatorCatalog => _runtime.indicatorCatalog;

  /// 已注册定义声明的参数；无参数或未知定义返回空列表。
  List<IndicatorParameterSpec> indicatorParametersFor(String definitionId) =>
      _runtime.indicatorParametersFor(definitionId);

  @override
  void addListener(VoidCallback listener) => _runtime.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _runtime.removeListener(listener);

  /// 发起新请求前捕获返回的令牌；不要在异步回调执行时重新读取 session。
  @override
  KChartDataSession beginSeries(
    KlineSeries series, {
    Iterable<Kline> initialData = const [],
  }) =>
      _runtime.beginSeries(series, initialData: initialData);

  @override
  KChartDataUpdateResult replaceData(
    Iterable<Kline> data, {
    required KChartDataSession session,
    KChartDataViewportPolicy viewportPolicy = KChartDataViewportPolicy.preserve,
  }) =>
      _runtime.replaceData(
        data,
        session: session,
        viewportPolicy: viewportPolicy,
      );

  @override
  KChartDataUpdateResult appendData(
    Iterable<Kline> data, {
    required KChartDataSession session,
  }) =>
      _runtime.appendData(data, session: session);

  @override
  KChartDataUpdateResult prependHistory(
    Iterable<Kline> data, {
    required KChartDataSession session,
  }) =>
      _runtime.prependHistory(data, session: session);

  @override
  KChartDataUpdateResult updateKline(
    Kline candle, {
    required KChartDataSession session,
    bool allowClosedCorrection = false,
  }) =>
      _runtime.updateKline(
        candle,
        session: session,
        allowClosedCorrection: allowClosedCorrection,
      );

  void setOptions(KChartOptions options) => _runtime.setOptions(options);
  void clearSelection() => _runtime.clearSelection();
  void scrollToLatest() => _runtime.scrollToLatest();
  void resetViewport() => _runtime.resetViewport();

  /// UTC 毫秒定位；没有布局或行情时，最后一次定位在条件满足后执行。
  void scrollToTime({required int epochMilliseconds, double alignment = 0.5}) =>
      _runtime.scrollToTime(
        epochMilliseconds: epochMilliseconds,
        alignment: alignment,
      );

  Future<void> retryHistory() => _runtime.retryHistory();
  void retryIndicators() => _runtime.retryIndicators();

  /// 全量替换当前会话覆盖物；如只修改一类，显式携带其余需要保留的集合。
  KChartOverlayUpdateStatus setOverlays({
    required KChartDataSession session,
    Iterable<ChartPriceLine> priceLines = const [],
    Iterable<ChartEventOverlay> events = const [],
    Iterable<ChartValueMarker> valueMarkers = const [],
    Iterable<ChartDrawing> drawings = const [],
  }) =>
      _runtime.setOverlays(
        session: session,
        priceLines: priceLines,
        events: events,
        valueMarkers: valueMarkers,
        drawings: drawings,
      );

  /// 重复销毁安全；迟到的数据/覆盖物写入忽略，主动配置/导航命令则明确拒绝。
  void dispose() => _runtime.dispose();
}

/// Widget/仓库测试的内部接线口，候选入口使用 show 排除此符号。
/// 不把 runtime getter 放到控制器上，防止宿主经对象成员取得可变内部实现。
@internal
KChartDataCoordinator runtimeForKChartWidget(KChartController controller) =>
    controller._runtime;
