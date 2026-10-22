import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/data.dart';
import '../drawing/chart_drawing.dart';
import '../indicator/indicator.dart';
import '../interaction/interaction.dart';
import '../model/model.dart';
import '../viewport/viewport.dart';
import 'k_chart_data_contract.dart';
import 'k_chart_data_session.dart';
import 'k_chart_history_contract.dart';
import 'k_chart_indicator_binding.dart';
import 'k_chart_options.dart';
import 'k_chart_options_geometry.dart';

part 'k_chart_history_coordinator.dart';
part 'k_chart_indicator_coordinator.dart';
part 'k_chart_options_coordinator.dart';
part 'k_chart_overlay_state.dart';
part 'k_chart_view_state.dart';

/// 数据、视口和选中态的一次完整内部快照，不属于正式公共 API。
///
/// 所有字段在提交前完成组装；旧快照引用的数据和面板列表不会随下一次命令变化。
/// 对宿主的候选只读快照由 view 投射，不把 ChartViewport 暴露给接入方。
final class KChartRuntimeState {
  const KChartRuntimeState._({
    required this.revision,
    required this.session,
    required this.data,
    required this.viewport,
    required this.panelIds,
    required this.selection,
    required this.selectedIndex,
    required this.isAttached,
    required this.history,
    required this.indicators,
    required this.indicatorBatch,
    required this.options,
    required this.overlays,
  });

  final int revision;
  final KChartDataSession session;
  final KlineSnapshot data;
  final ChartViewport viewport;
  final List<String> panelIds;
  final ChartSelectionAnchor? selection;
  final int? selectedIndex;
  final bool isAttached;
  final KChartHistoryState history;

  /// 配置的唯一所有者；面板与指标字段是该配置的只读投射。
  final KChartOptions options;

  /// 当前行情会话的覆盖物，窗口裁剪不删除，换会话清空。
  final KChartOverlays overlays;

  /// 显示顺序及面板归属；算法输出以 instanceId 与此列表关联。
  final List<KChartIndicatorBinding> indicators;

  /// 同一数据版本的成功结果及失败，不向上层泄露可变引擎/注册表/缓存。
  final IndicatorCalculationBatch indicatorBatch;

  Kline? get selectedCandle =>
      selectedIndex == null ? null : data.data[selectedIndex!];

  Kline? get previousSelectedCandle =>
      selectedIndex == null || selectedIndex == 0
          ? null
          : data.data[selectedIndex! - 1];
}

/// 单图表数据事务协调器：真正实现 OPT-02 的数据命令，而不是测试替身。
///
/// 此阶段接通行情、导航、选中、历史分页、配置和指标装配。尚不负责
/// Widget 装配，因此既不替代旧 KChartController，也不宣称正式 SDK 已经可接入。
///
/// 每次命令在暂存 Store 中校验/合并，再原子替换完整快照。暂存是当前的安全边界，
/// 后续 OPT-11 测量后再决定是否减少复制；不能为性能绕过失败回滚和快照不可变性。
final class KChartDataCoordinator
    implements KChartDataCommands, ValueListenable<KChartRuntimeState> {
  factory KChartDataCoordinator({
    required KlineSeries series,
    Iterable<Kline> initialData = const [],
    ChartViewport? initialViewport,
    Iterable<String>? panelIds,
    int? maxOutOfOrderCandles,
    KChartHistoryLoader? historyLoader,
    double? historyThresholdItems,
    Iterable<KChartIndicatorBinding>? indicators,
    KChartOptions? options,
    Iterable<IndicatorDefinition> indicatorDefinitions = const [],
  }) {
    if (options != null &&
        (panelIds != null ||
            maxOutOfOrderCandles != null ||
            historyThresholdItems != null ||
            indicators != null)) {
      throw ArgumentError(
        'Use options or the transitional flat arguments, not both.',
      );
    }
    final suppliedPanels = _validatePanels(panelIds ?? const ['main']);
    final config = options ??
        KChartOptions(
          secondaryPanels: [
            for (final id in suppliedPanels)
              if (id != 'main') KChartSecondaryPanelOptions(id: id),
          ],
          indicators: indicators ?? const [],
          maxOutOfOrderCandles: maxOutOfOrderCandles ?? 2,
          historyThresholdItems: historyThresholdItems ?? 2,
        );
    final registry = IndicatorRegistry();
    registerBuiltInIndicatorDefinitions(registry);
    for (final definition in indicatorDefinitions) {
      registry.register(definition);
    }
    _validateVisibleSeriesBindings(config.indicators, registry);
    final catalog = List<IndicatorCatalogEntry>.unmodifiable(
      registry.definitions.values.map(IndicatorCatalogEntry.fromDefinition),
    );
    final engine = IndicatorEngine(registry: registry);
    final store = KlineStore()..replace(_validateSeries(initialData, series));
    var viewport = (initialViewport ?? const ChartViewport.initial())
        .copyWith(itemCount: store.snapshot.length);
    // 显式 options 或默认构造由协调器管理几何。旧内部调用传入完整视口时，
    // 暂时保留其边界；首次 setOptions 后移交所有权，不再混用两套策略。
    final managed = options != null || initialViewport == null;
    if (managed) {
      viewport = config.viewport.resolveViewport(
        viewport,
        resetZoom: initialViewport == null,
      );
    }
    return KChartDataCoordinator._(
      series,
      store.snapshot,
      viewport,
      config,
      managed,
      historyLoader,
      engine,
      catalog,
    );
  }

  KChartDataCoordinator._(
    KlineSeries series,
    KlineSnapshot data,
    ChartViewport viewport,
    KChartOptions options,
    this._managesViewport,
    this._historyLoader,
    this._indicatorEngine,
    this._indicatorCatalog,
  )   : _sessions = KChartSessionGate(series),
        _initialItemExtent = viewport.itemExtent {
    _needsInitialFit = _managesViewport && viewport.width == 0;
    _value = KChartRuntimeState._(
      revision: 0,
      session: _sessions.current,
      data: data,
      viewport: viewport,
      panelIds: _optionPanelIds(options),
      selection: null,
      selectedIndex: null,
      isAttached: false,
      history: const KChartHistoryState.idle(),
      indicators: options.indicators,
      indicatorBatch: _resolveIndicators(data, options.indicators),
      options: options,
      overlays: const KChartOverlays._empty(),
    );
    _viewValue = _projectViewState(_value);
  }

  int get maxOutOfOrderCandles => _value.options.maxOutOfOrderCandles;
  final KChartHistoryLoader? _historyLoader;

  /// 距最旧边缘多少个 K 线槽位内开始预加载，修改配置后下一次检查立即采用新值。
  double get historyThresholdItems => _value.options.historyThresholdItems;
  bool _managesViewport;
  bool _needsInitialFit = false;
  int _historyRequestSerial = 0;
  _HistoryOperation? _activeHistory;
  bool _historyCheckScheduled = false;
  final KChartSessionGate _sessions;
  final IndicatorEngine _indicatorEngine;
  final List<IndicatorCatalogEntry> _indicatorCatalog;
  bool _calculatingIndicators = false;
  final KChartAttachmentGuard _attachment = KChartAttachmentGuard();
  final _StateNotifier _notifier = _StateNotifier();
  final double _initialItemExtent;
  late KChartRuntimeState _value;
  late KChartViewState _viewValue;
  late final ValueListenable<KChartViewState> _view =
      _ChartViewListenable(this);
  bool _disposed = false;
  bool _notifying = false;
  bool _notificationPending = false;
  ({int time, double alignment})? _pendingTime;

  @override
  KChartRuntimeState get value => _value;

  /// 与内部状态共用同一通知事务，不维护第二个 ChangeNotifier。
  /// 只暴露数据和语义信息；正式 facade 在后续接线，当前仍不从公共入口导出。
  ValueListenable<KChartViewState> get view => _view;

  @override
  KChartDataSession get session => _value.session;

  bool get isDisposed => _disposed;

  /// Widget 只读取不可变绘制描述，不取得引擎或注册表，也不在 build 中重新计算指标。
  /// 此方法不经候选 Controller 暴露；面板绑定仍以当前 options 为准。
  IndicatorRendererDescriptor? rendererDescriptorFor(String definitionId) =>
      _indicatorEngine.registry.find(definitionId)?.rendererDescriptor;

  /// 按注册顺序返回不可变目录；内建定义与宿主注册的自定义定义均在其中。
  List<IndicatorCatalogEntry> get indicatorCatalog => _indicatorCatalog;

  /// 只读取定义声明的参数，不把可变注册表交给宿主。
  List<IndicatorParameterSpec> indicatorParametersFor(String definitionId) {
    for (final entry in _indicatorCatalog) {
      if (entry.definitionId == definitionId) return entry.parameters;
    }
    return const [];
  }

  @override
  void addListener(VoidCallback listener) {
    _ensureActive();
    _notifier.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (!_disposed) _notifier.removeListener(listener);
  }

  @override
  KChartDataSession beginSeries(
    KlineSeries series, {
    Iterable<Kline> initialData = const [],
  }) {
    _ensureActive();
    // 先校验完整候选窗口，再切换令牌；不能因一个错误批次使当前订阅永久失效。
    final store = KlineStore()..replace(_validateSeries(initialData, series));
    final data = _versioned(store.snapshot);
    final viewport = _resetGeometry(data.data.length);
    final nextSession = _sessions.begin(series);
    _invalidateHistory();
    _pendingTime = null;
    _commit(
      data: data,
      viewport: viewport,
      selection: null,
      session: nextSession,
      history: const KChartHistoryState.idle(),
    );
    return nextSession;
  }

  @override
  KChartDataUpdateResult replaceData(
    Iterable<Kline> data, {
    required KChartDataSession session,
    KChartDataViewportPolicy viewportPolicy = KChartDataViewportPolicy.preserve,
  }) {
    if (!_sessions.accepts(session)) {
      return _receipt(KChartDataUpdateStatus.ignoredStaleSession);
    }
    _ensureActive();
    final store = KlineStore()..replace(_validateSeries(data, session.series));
    return _finishData(
      store.snapshot,
      reset: viewportPolicy == KChartDataViewportPolicy.resetToLatest,
      resetHistory: true,
    );
  }

  @override
  KChartDataUpdateResult appendData(
    Iterable<Kline> data, {
    required KChartDataSession session,
  }) {
    if (!_sessions.accepts(session)) {
      return _receipt(KChartDataUpdateStatus.ignoredStaleSession);
    }
    _ensureActive();
    final incoming = _validateSeries(data, session.series);
    if (incoming.isEmpty) {
      return _receipt(KChartDataUpdateStatus.unchanged);
    }
    final store = KlineStore.stagedFromVerifiedSnapshot(_value.data);
    return _finishData(store.append(incoming), dataChangeKnown: true);
  }

  @override
  KChartDataUpdateResult prependHistory(
    Iterable<Kline> data, {
    required KChartDataSession session,
  }) {
    if (!_sessions.accepts(session)) {
      return _receipt(KChartDataUpdateStatus.ignoredStaleSession);
    }
    _ensureActive();
    final incoming = _validateSeries(data, session.series);
    if (incoming.isEmpty) {
      return _receipt(KChartDataUpdateStatus.unchanged);
    }
    final store = KlineStore.stagedFromVerifiedSnapshot(_value.data);
    return _finishData(store.prepend(incoming), dataChangeKnown: true);
  }

  @override
  KChartDataUpdateResult updateKline(
    Kline candle, {
    required KChartDataSession session,
    bool allowClosedCorrection = false,
  }) {
    if (!_sessions.accepts(session)) {
      return _receipt(KChartDataUpdateStatus.ignoredStaleSession);
    }
    _ensureActive();
    if (!session.series.contains(candle)) {
      throw ArgumentError('Kline does not belong to the current series.');
    }
    final store = KlineStore.stagedFromVerifiedSnapshot(_value.data);
    final merger = KlineRealtimeCoordinator(
      store: store,
      maxOutOfOrderCandles: maxOutOfOrderCandles,
    );
    final result = merger.apply(
      candle,
      generation: merger.generation,
      allowClosedCorrection: allowClosedCorrection,
    );
    return switch (result.outcome) {
      KlineMergeOutcome.rejectedClosedCorrection =>
        _receipt(KChartDataUpdateStatus.rejectedClosedCorrection),
      KlineMergeOutcome.rejectedOutsideWindow =>
        _receipt(KChartDataUpdateStatus.rejectedOutsideWindow),
      KlineMergeOutcome.ignoredDuplicate =>
        _receipt(KChartDataUpdateStatus.unchanged),
      KlineMergeOutcome.appended ||
      KlineMergeOutcome.updated ||
      KlineMergeOutcome.insertedOutOfOrder =>
        _finishData(result.snapshot, dataChangeKnown: true),
      // 会话和序列在进入暂存合并器之前已验证，这两项不应出现。
      _ =>
        throw StateError('Unexpected staged merge outcome: ${result.outcome}'),
    };
  }

  /// 由 Widget 适配层调用，不属于面向宿主的公共命令。
  void applyViewport(
    ChartViewport viewport, {
    ChartViewportChangeSource source = ChartViewportChangeSource.programmatic,
  }) {
    _ensureActive();
    if (viewport.itemCount != _value.data.data.length) {
      throw ArgumentError('Viewport itemCount must match the current data.');
    }
    final browsing = source == ChartViewportChangeSource.pan ||
        source == ChartViewportChangeSource.inertia;
    // 真实用户输入优先于尚未执行的程序定位，布局回调则负责完成延迟定位。
    if (source != ChartViewportChangeSource.programmatic) _pendingTime = null;
    var next = viewport;
    if (_managesViewport) {
      next = _value.options.viewport.resolveViewport(viewport);
      // 导航器已经按命中焦点计算了左边缘；重新换算留白不能把焦点再次移走。
      if (next != viewport) {
        next = _alignLeft(next, viewport.visibleLeftDataPosition);
      }
    }
    _commit(
      data: _value.data,
      viewport: _applyPendingTime(next, _value.data),
      selection: browsing ? null : _value.selection,
    );
  }

  void scrollToLatest() {
    _ensureActive();
    _pendingTime = null;
    _commit(
      data: _value.data,
      viewport: ChartViewportNavigator.toLatest(_value.viewport),
      selection: null,
    );
  }

  void resetViewport() {
    _ensureActive();
    _pendingTime = null;
    _commit(
      data: _value.data,
      viewport: _resetGeometry(_value.data.data.length),
      selection: null,
    );
  }

  void scrollToTime({required int epochMilliseconds, double alignment = 0.5}) {
    _ensureActive();
    if (epochMilliseconds < 0 ||
        !alignment.isFinite ||
        alignment < 0 ||
        alignment > 1) {
      throw ArgumentError(
        'Time must be non-negative and alignment within 0..1.',
      );
    }
    _pendingTime = (time: epochMilliseconds, alignment: alignment);
    _commit(
      data: _value.data,
      viewport: _applyPendingTime(_value.viewport, _value.data),
      selection: null,
    );
  }

  /// 命中计算留在 Widget/坐标层，协调层只接收稳定时间与所选面板数值。
  void select({
    required int openTime,
    required String panelId,
    required double price,
  }) {
    _ensureActive();
    if (!_value.panelIds.contains(panelId)) {
      throw ArgumentError.value(panelId, 'panelId');
    }
    final index = _value.data.indexOfOpenTime(openTime);
    if (index < 0) throw ArgumentError.value(openTime, 'openTime');
    final anchor = ChartSelectionAnchor(
      candle: _value.data.data[index],
      panelId: panelId,
      price: price,
    );
    final old = _value.selection;
    if (old != null &&
        old.openTime == openTime &&
        old.panelId == panelId &&
        old.price == price) {
      return;
    }
    _commit(data: _value.data, viewport: _value.viewport, selection: anchor);
  }

  void clearSelection() {
    _ensureActive();
    _commit(data: _value.data, viewport: _value.viewport, selection: null);
  }

  /// 原子替换当前会话全部覆盖物。部分更新请显式带上要保留的集合。
  /// 先验证令牌再遍历输入，迟到/跨实例/销毁后的回调不能恢复旧覆盖物。
  /// 本方法只管理运行时值，不发送交易、不写入宿主持久化存储。
  KChartOverlayUpdateStatus setOverlays({
    required KChartDataSession session,
    Iterable<ChartPriceLine> priceLines = const [],
    Iterable<ChartEventOverlay> events = const [],
    Iterable<ChartValueMarker> valueMarkers = const [],
    Iterable<ChartDrawing> drawings = const [],
  }) {
    if (!_sessions.accepts(session)) {
      return KChartOverlayUpdateStatus.ignoredStaleSession;
    }
    _ensureActive();
    final overlays = KChartOverlays(
      priceLines: priceLines,
      events: events,
      valueMarkers: valueMarkers,
      drawings: drawings,
    );
    if (overlays == _value.overlays) return KChartOverlayUpdateStatus.unchanged;
    _commit(
      data: _value.data,
      viewport: _value.viewport,
      selection: _value.selection,
      overlays: overlays,
    );
    return KChartOverlayUpdateStatus.applied;
  }

  /// 原子替换完整配置，不切换行情会话、不清空数据或有效选中。
  /// 改首屏根数会重新适配缩放；其他布局设置不改变当前缩放/浏览位置。
  /// 旧内部完整视口入口首次调用此方法后，由 options 统一管理边界。
  void setOptions(KChartOptions options) {
    _ensureActive();
    _validateVisibleSeriesBindings(
      options.indicators,
      _indicatorEngine.registry,
    );
    final changedPolicy = options.viewport != _value.options.viewport;
    final takeOwnership = !_managesViewport;
    var viewport = _value.viewport;
    if (changedPolicy || takeOwnership) {
      final fit = options.viewport.initialVisibleCandles !=
          _value.options.viewport.initialVisibleCandles;
      viewport = options.viewport.resolveViewport(viewport, resetZoom: fit);
      viewport = _retainTimeAnchor(_value.data, viewport);
      if (fit && viewport.width == 0) _needsInitialFit = true;
    }
    _managesViewport = true;
    if (takeOwnership && viewport.width == 0) _needsInitialFit = true;
    _commit(
      data: _value.data,
      viewport: _applyPendingTime(viewport, _value.data),
      selection: _value.selection,
      options: options,
    );
  }

  /// Widget 仅上报可用宽度，不再计算留白；首次非零布局才适配首屏根数。
  /// 后续尺寸变化保留用户缩放与左侧时间锚，最新态则继续贴最新边缘。
  void setViewportSize(double width) {
    _ensureActive();
    var next = _managesViewport
        ? _value.options.viewport.resolveViewport(
            _value.viewport,
            width: width,
            resetZoom: _needsInitialFit,
          )
        : _value.viewport.copyWith(width: width);
    if (next == _value.viewport && !_needsInitialFit) return;
    if (width > 0) _needsInitialFit = false;
    next = _retainTimeAnchor(_value.data, next);
    _commit(
      data: _value.data,
      viewport: _applyPendingTime(next, _value.data),
      selection: _value.selection,
    );
  }

  /// 删除面板时同时移除其指标绑定；保留仍存在面板的尺寸和参数区设置。
  void setPanels(Iterable<String> panelIds) {
    _ensureActive();
    final panels = _validatePanels(panelIds);
    _commit(
      data: _value.data,
      viewport: _value.viewport,
      selection: _value.selection,
      options: _withPanels(
        panels,
        _value.indicators.where((binding) => panels.contains(binding.panelId)),
      ),
    );
  }

  /// 原子替换指标配置，可同时增删/重排面板。重复实例 id 或未知面板在提交前拒绝。
  /// 算法级参数错误/未知定义则隔离到 indicatorBatch.failures，保留其他成功实例。
  void setIndicators(
    Iterable<KChartIndicatorBinding> indicators, {
    Iterable<String>? panelIds,
  }) {
    _ensureActive();
    final panels =
        panelIds == null ? _value.panelIds : _validatePanels(panelIds);
    final bindings = validateKChartIndicatorBindings(indicators, panels);
    _validateVisibleSeriesBindings(bindings, _indicatorEngine.registry);
    _commit(
      data: _value.data,
      viewport: _value.viewport,
      selection: _value.selection,
      options: _withPanels(panels, bindings),
    );
  }

  /// 显式重试失败指标；未失败的结果由引擎缓存复用，不依赖视口操作触发重试。
  void retryIndicators() {
    _ensureActive();
    if (!_value.indicatorBatch.hasFailures) return;
    _commit(
      data: _value.data,
      viewport: _value.viewport,
      selection: _value.selection,
      retryIndicators: true,
    );
  }

  void attach(Object owner) {
    _ensureActive();
    _attachment.attach(owner);
    _commit(
      data: _value.data,
      viewport: _value.viewport,
      selection: _value.selection,
    );
  }

  void detach(Object owner) {
    _ensureNotCalculating();
    _attachment.detach(owner);
    if (_disposed) return;
    // 旧 Widget 的迟到解绑不能取消当前 Widget 的请求。
    final cancelled = !_attachment.isAttached && _activeHistory != null;
    if (cancelled) _invalidateHistory();
    _commit(
      data: _value.data,
      viewport: _value.viewport,
      selection: _value.selection,
      history: cancelled ? const KChartHistoryState.idle() : null,
    );
  }

  /// 显式重试绕过距离阈值，但仍要求挂载、有布局、非空数据且未到末页。
  /// 同一在途请求共享 Future；失败存入 history，避免自动重试造成请求风暴。
  Future<void> retryHistory() {
    _ensureActive();
    return _startHistory();
  }

  KChartDataUpdateResult _finishData(
    KlineSnapshot snapshot, {
    bool reset = false,
    bool resetHistory = false,
    KChartHistoryState? history,
    bool? dataChangeKnown,
  }) {
    final data = _versioned(snapshot, changeKnown: dataChangeKnown);
    final changed = !identical(data, _value.data);
    if (reset) _pendingTime = null;
    final viewport = reset
        ? _geometryForData(snapshot.length).copyWith(scrollOffsetItems: 0)
        : _preserveViewport(data);
    // 权威替换即使数据相同也取消旧分页；前插/乱序改变首条时，请求游标也已过期。
    // 自动历史成功时显式传入完成态，让前插与分页状态只发布一次。
    if (history == null &&
        (resetHistory ||
            _value.data.data.firstOrNull?.openTime !=
                snapshot.firstOrNull?.openTime)) {
      _invalidateHistory();
      history = const KChartHistoryState.idle();
    }
    // 回执在通知前固定；监听器可同步提交下一事务，但不能改写本次命令的版本回执。
    final receipt = KChartDataUpdateResult(
      status: changed
          ? KChartDataUpdateStatus.applied
          : KChartDataUpdateStatus.unchanged,
      dataRevision: data.version.value,
    );
    _commit(
      data: data,
      viewport: _applyPendingTime(viewport, data),
      selection: reset ? null : _value.selection,
      history: history,
    );
    return receipt;
  }

  KlineSnapshot _versioned(
    KlineSnapshot snapshot, {
    bool? changeKnown,
  }) {
    // 非空追加/前插及实时合并成功时，Store 已证明发生变化；空历史页则明确未变化。
    // 权威替换和切换序列可能内容相同，继续做结构比较以保留旧快照身份与版本。
    if (changeKnown == false) return _value.data;
    if (changeKnown == null && listEquals(snapshot.data, _value.data.data)) {
      return _value.data;
    }
    return KlineSnapshot.withVersion(snapshot, _value.data.version.next());
  }

  ChartViewport _preserveViewport(KlineSnapshot nextData) {
    final old = _value.viewport;
    // 无数据变化时不重新换算浮点坐标，避免空批次/重复数据产生微小偏移及多余通知。
    if (identical(nextData, _value.data)) return old;
    return _retainTimeAnchor(nextData, _geometryForData(nextData.data.length));
  }

  ChartViewport _retainTimeAnchor(
    KlineSnapshot nextData,
    ChartViewport next,
  ) {
    final old = _value.viewport;
    if (old.isAtLatest || _value.data.data.isEmpty || nextData.data.isEmpty) {
      return next.copyWith(scrollOffsetItems: 0);
    }
    // 使用可见时间锚而不是追加数量，兼容前插、裁剪、整窗替换和乱序插入。
    final index = old.visibleLeftDataPosition
        .floor()
        .clamp(0, _value.data.data.length - 1);
    final localX = (index + 0.5 - old.visibleLeftDataPosition) * old.itemExtent;
    final position = ChartXTransform(viewport: next, data: nextData)
        .timeToDataPosition(_value.data.data[index].openTime);
    final desiredLeft = position - localX / next.itemExtent;
    return _alignLeft(next, desiredLeft);
  }

  ChartViewport _applyPendingTime(
    ChartViewport viewport,
    KlineSnapshot data,
  ) {
    final target = _pendingTime;
    if (target == null || viewport.width == 0 || data.data.isEmpty) {
      return viewport;
    }
    final next = ChartViewportNavigator.locateTime(
      viewport: viewport,
      data: data,
      epochMilliseconds: target.time,
      alignment: target.alignment,
    );
    _pendingTime = null;
    return next;
  }

  void _commit({
    required KlineSnapshot data,
    required ChartViewport viewport,
    required ChartSelectionAnchor? selection,
    KChartDataSession? session,
    KChartHistoryState? history,
    KChartOptions? options,
    KChartOverlays? overlays,
    bool retryIndicators = false,
  }) {
    final config =
        options == null || options == _value.options ? _value.options : options;
    final panels = identical(config, _value.options)
        ? _value.panelIds
        : _optionPanelIds(config);
    // 纯视口/时钟等事务既未换行情也未换选中或面板，沿用上次已解析索引。
    // 变更窗口时才从可信有序快照二分恢复，避免每次手势帧线性扫描整表。
    final selectedIndex = identical(data, _value.data) &&
            identical(selection, _value.selection) &&
            identical(panels, _value.panelIds)
        ? _value.selectedIndex
        : selection?.resolveIndexInSnapshot(data, panelIds: panels);
    final retainedSelection = selectedIndex == null ? null : selection;
    final nextSession = session ?? _value.session;
    final nextHistory = history ?? _value.history;
    final nextIndicators = listEquals(config.indicators, _value.indicators)
        ? _value.indicators
        : config.indicators;
    final sessionChanged = !identical(nextSession, _value.session);
    final nextOverlays = sessionChanged
        ? const KChartOverlays._empty()
        : overlays ?? _value.overlays;
    // 只有数据/算法配置/会话变化或显式重试才进入引擎；面板移动和导航保留同一批结果。
    final needsIndicators = sessionChanged ||
        !identical(data, _value.data) ||
        !_sameIndicatorConfigs(nextIndicators, _value.indicators) ||
        retryIndicators;
    if (identical(data, _value.data) &&
        viewport == _value.viewport &&
        identical(retainedSelection, _value.selection) &&
        selectedIndex == _value.selectedIndex &&
        identical(nextSession, _value.session) &&
        listEquals(panels, _value.panelIds) &&
        _attachment.isAttached == _value.isAttached &&
        identical(nextHistory, _value.history) &&
        identical(nextIndicators, _value.indicators) &&
        identical(config, _value.options) &&
        nextOverlays == _value.overlays &&
        !retryIndicators) {
      return;
    }
    if (sessionChanged) _indicatorEngine.clear();
    final batch = needsIndicators
        ? _resolveIndicators(data, nextIndicators)
        : _value.indicatorBatch;
    _value = KChartRuntimeState._(
      revision: _value.revision + 1,
      session: nextSession,
      data: data,
      viewport: viewport,
      panelIds: panels,
      selection: retainedSelection,
      selectedIndex: selectedIndex,
      isAttached: _attachment.isAttached,
      history: nextHistory,
      indicators: nextIndicators,
      indicatorBatch: batch,
      options: config,
      overlays: nextOverlays,
    );
    // 两种视图均先完成提交再通知；监听器重入时也不会看到不同 revision 的拼接状态。
    _viewValue = _projectViewState(_value);
    _notifyCommittedState();
    _scheduleHistoryCheck();
  }

  void _notifyCommittedState() {
    // 监听器内的新命令先提交下一份完整状态，再延后其通知，避免通知栈递归。
    // ValueListenable 表达“当前值已变”，不是逐事件日志：本轮后续监听器可能读到更新的
    // 完整快照；需要保留某次状态时应捕获 value，而不是在回调末尾重新读取。
    if (_notifying) {
      _notificationPending = true;
      return;
    }
    _notifying = true;
    try {
      do {
        _notificationPending = false;
        _notifier.publish();
      } while (_notificationPending && !_disposed);
    } finally {
      _notifying = false;
      // ChangeNotifier 不能在自身通知栈中 dispose；先失效会话，再在通知返回后释放。
      if (_disposed) _notifier.dispose();
    }
  }

  KChartDataUpdateResult _receipt(KChartDataUpdateStatus status) =>
      KChartDataUpdateResult(
        status: status,
        dataRevision: _value.data.version.value,
      );

  void _ensureActive() {
    if (_disposed) throw StateError('KChartDataCoordinator has been disposed.');
    _ensureNotCalculating();
  }

  void dispose() {
    if (_disposed) return;
    _ensureNotCalculating();
    _disposed = true;
    _invalidateHistory();
    _pendingTime = null;
    _sessions.dispose();
    _attachment.dispose();
    _indicatorEngine.clear();
    if (!_notifying) _notifier.dispose();
  }
}

/// 只在内部桥接 ChangeNotifier 的受保护通知方法，协调器不对宿主暴露通知入口。
final class _StateNotifier extends ChangeNotifier {
  void publish() => notifyListeners();
}

List<Kline> _validateSeries(Iterable<Kline> input, KlineSeries series) {
  final data = List<Kline>.of(input, growable: false);
  if (data.any((candle) => !series.contains(candle))) {
    throw ArgumentError('All Klines must belong to the requested series.');
  }
  return data;
}

List<String> _validatePanels(Iterable<String> input) {
  final panels = List<String>.unmodifiable(input);
  if (!panels.contains('main') ||
      panels.toSet().length != panels.length ||
      panels.any((id) => id.trim().isEmpty)) {
    throw ArgumentError(
      'Panel ids must be unique, non-empty and include main.',
    );
  }
  return panels;
}

/// 显示选择只校验已注册定义；未知定义仍由指标批次按原有失败隔离语义处理。
void _validateVisibleSeriesBindings(
  Iterable<KChartIndicatorBinding> bindings,
  IndicatorRegistry registry,
) {
  for (final binding in bindings) {
    final selected = binding.visibleSeriesIds;
    if (selected == null) continue;
    final definition = registry.find(binding.config.definitionId);
    if (definition == null) continue;
    final available = definition.rendererDescriptor.series
        .where((series) => series.showInChart)
        .map((series) => series.id)
        .toSet();
    if (!available.containsAll(selected)) {
      throw ArgumentError.value(
        selected,
        'visibleSeriesIds',
        'Unknown or hidden series for ${binding.config.definitionId}.',
      );
    }
  }
}
