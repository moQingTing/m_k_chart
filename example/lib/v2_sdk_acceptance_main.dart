import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';

import 'binance_market_data_client.dart';
import 'drawing/v2_demo_drawing_snapshot_store.dart';
import 'market/v2_demo_market_data_source.dart';
import 'v2_custom_indicator_example.dart';
import 'v2_sdk_chart_settings.dart';

/// 使用正式 V2 包入口的验收示例；默认 main.dart 与旧 Demo 保持不变。
/// 运行：flutter run -t lib/v2_sdk_acceptance_main.dart
void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: V2SdkAcceptancePage(),
    ));

/// 直接验证公开 Controller + KChart，而非用旧 Demo 的表现代替本轮重构验收。
/// 行情轮询和模拟时钟归验收宿主所有；KChart 管理显示时钟与帧后业务回调。
class V2SdkAcceptancePage extends StatefulWidget {
  const V2SdkAcceptancePage({
    this.client,
    this.nowMilliseconds,
    this.indicatorDefinitions = const [V2TypicalPriceIndicator()],
    this.drawingSnapshotStore,
    super.key,
  });

  final V2DemoMarketDataSource? client;
  final int Function()? nowMilliseconds;
  final Iterable<IndicatorDefinition> indicatorDefinitions;
  final V2DemoDrawingSnapshotStore? drawingSnapshotStore;

  @override
  State<V2SdkAcceptancePage> createState() => _V2SdkAcceptancePageState();
}

class _V2SdkAcceptancePageState extends State<V2SdkAcceptancePage>
    with WidgetsBindingObserver {
  static final V2DemoDrawingSnapshotStore _defaultDrawingSnapshotStore =
      V2MemoryDrawingSnapshotStore();

  late final KChartController _chart;
  late final V2DemoMarketDataSource _client;
  late final V2DemoDrawingSnapshotStore _drawingSnapshotStore;
  late int _simulationTime;
  Timer? _timer;
  bool _live = false;
  bool _paused = false;
  bool _foreground = true;
  int _tick = 0;
  int _replaced = 0;
  int _appended = 0;
  int _requestSerial = 0;
  int? _inFlight;
  V2DemoMarketRequest<List<Kline>>? _activeRequest;
  String? _error;
  ChartDrawingKind? _drawingTool;
  List<ChartDrawingAnchor> _drawingAnchors = const [];
  ChartDrawingAnchor? _previewAnchor;
  bool _drawingEditing = false;
  bool _drawingSnapToOhlc = false;
  String? _selectedDrawingId;
  int _drawingSerial = 0;
  ChartDrawingCommandHistory _drawingHistory = ChartDrawingCommandHistory();
  String? _savedDrawingJson;
  String? _drawingStorageError;
  bool _loadingDrawingSnapshot = false;
  bool _writingDrawingSnapshot = false;
  int _drawingStorageGeneration = 0;

  String get _drawingSourceId =>
      _live ? 'live:${_client.displayName}' : 'simulation';

  /// 时间周期不参与存储键：同币种/数据源切换周期时仍可按绝对时间恢复。
  String get _drawingSnapshotKey {
    final series = _chart.session.series;
    return 'chart-drawings:v1:$_drawingSourceId:${series.symbol}:${series.priceSource.name}';
  }

  String _newDrawingId() {
    final existing =
        _chart.value.overlays.drawings.map((drawing) => drawing.id);
    var id = '';
    do {
      id = 'acceptance-drawing-${++_drawingSerial}';
    } while (existing.contains(id));
    return id;
  }

  Future<void> _saveDrawings() async {
    final snapshot = ChartDrawingSnapshot(
      series: _chart.session.series,
      sourceId: _drawingSourceId,
      drawings: _chart.value.overlays.drawings,
    );
    final encoded = jsonEncode(snapshot.toJson());
    final key = _drawingSnapshotKey;
    setState(() {
      _writingDrawingSnapshot = true;
      _drawingStorageError = null;
    });
    try {
      await _drawingSnapshotStore.write(key, encoded);
      if (!mounted || key != _drawingSnapshotKey) return;
      setState(() => _savedDrawingJson = encoded);
    } catch (error) {
      if (mounted) setState(() => _drawingStorageError = '保存绘图失败：$error');
    } finally {
      if (mounted) setState(() => _writingDrawingSnapshot = false);
    }
  }

  Future<void> _loadSavedDrawings() async {
    final generation = ++_drawingStorageGeneration;
    final key = _drawingSnapshotKey;
    setState(() {
      _loadingDrawingSnapshot = true;
      _savedDrawingJson = null;
      _drawingStorageError = null;
    });
    try {
      final encoded = await _drawingSnapshotStore.read(key);
      if (!mounted || generation != _drawingStorageGeneration) return;
      setState(() => _savedDrawingJson = encoded);
    } catch (error) {
      if (mounted && generation == _drawingStorageGeneration) {
        setState(() => _drawingStorageError = '读取绘图失败：$error');
      }
    } finally {
      if (mounted && generation == _drawingStorageGeneration) {
        setState(() => _loadingDrawingSnapshot = false);
      }
    }
  }

  Future<void> _restoreDrawings() async {
    try {
      final encoded = _savedDrawingJson ??
          await _drawingSnapshotStore.read(_drawingSnapshotKey);
      if (encoded == null || !mounted) return;
      final json = jsonDecode(encoded);
      if (json is! Map) throw const FormatException('绘图快照必须是 JSON 对象');
      final snapshot = ChartDrawingSnapshot.fromJson(
        Map<String, Object?>.from(json),
      ).restoreFor(
        series: _chart.session.series,
        sourceId: _drawingSourceId,
        data: _chart.value.data,
      );
      final overlays = _chart.value.overlays;
      final result = _chart.setOverlays(
        session: _chart.session,
        priceLines: overlays.priceLines,
        events: overlays.events,
        valueMarkers: overlays.valueMarkers,
        drawings: snapshot.drawings,
      );
      if (result != KChartOverlayUpdateStatus.applied &&
          result != KChartOverlayUpdateStatus.unchanged) {
        throw StateError('绘图快照已过期，未恢复');
      }
      _drawingHistory = ChartDrawingCommandHistory(
        editor: ChartDrawingEditor(drawings: snapshot.drawings),
      );
      setState(() {
        _selectedDrawingId = null;
        _drawingStorageError = null;
      });
    } catch (error) {
      setState(() => _drawingStorageError = '恢复绘图失败：$error');
    }
  }

  ChartDrawing? get _selectedDrawing {
    final id = _selectedDrawingId;
    if (id == null) return null;
    for (final drawing in _chart.value.overlays.drawings) {
      if (drawing.id == id) return drawing;
    }
    return null;
  }

  void _applyDrawingEditor(ChartDrawingEditor editor) {
    final overlays = _chart.value.overlays;
    _chart.setOverlays(
      session: _chart.session,
      priceLines: overlays.priceLines,
      events: overlays.events,
      valueMarkers: overlays.valueMarkers,
      drawings: editor.drawings,
    );
    _selectedDrawingId = editor.selectedDrawingId;
    if (mounted) setState(() {});
  }

  void _undoDrawing() {
    if (!_drawingHistory.canUndo) return;
    _drawingHistory = _drawingHistory.undo();
    _applyDrawingEditor(_drawingHistory.editor);
  }

  void _redoDrawing() {
    if (!_drawingHistory.canRedo) return;
    _drawingHistory = _drawingHistory.redo();
    _applyDrawingEditor(_drawingHistory.editor);
  }

  void _setDrawingLocked(bool value) {
    final drawing = _selectedDrawing;
    if (drawing == null || drawing.isLocked == value) return;
    _drawingHistory = _drawingHistory.execute(
      value ? '锁定画线' : '解锁画线',
      (editor) => editor.setLocked(drawing.id, value),
    );
    _applyDrawingEditor(_drawingHistory.editor);
  }

  void _setDrawingVisible(bool value) {
    final drawing = _selectedDrawing;
    if (drawing == null || drawing.style.visible == value) return;
    _drawingHistory = _drawingHistory.execute(
      value ? '显示画线' : '隐藏画线',
      (editor) => editor.setVisible(drawing.id, value),
    );
    _applyDrawingEditor(_drawingHistory.editor);
  }

  void _selectDrawing(String? id) {
    _selectedDrawingId = id;
    _drawingHistory = _drawingHistory.select(id);
    setState(() {});
  }

  void _chooseDrawingTool(ChartDrawingKind? tool) {
    _chart.clearSelection();
    setState(() {
      _drawingTool = tool;
      _drawingAnchors = const [];
      _previewAnchor = null;
      _drawingEditing = false;
      _selectedDrawingId = null;
    });
  }

  void _addDrawingAnchor(ChartDrawingAnchor anchor) {
    final tool = _drawingTool;
    if (tool == null) return;
    final anchors = [..._drawingAnchors, anchor];
    if (anchors.length < _requiredDrawingAnchors(tool)) {
      setState(() {
        _drawingAnchors = anchors;
        _previewAnchor = anchor;
      });
      return;
    }
    final overlays = _chart.value.overlays;
    // setOverlays 是全量替换；提交新绘图时保留订单/事件等其他覆盖物。
    final drawing = ChartDrawing(
      id: _newDrawingId(),
      kind: tool,
      anchors: anchors,
      text: tool == ChartDrawingKind.text ? '注释' : null,
    );
    _drawingHistory = _drawingHistory.execute(
      '创建${_drawingToolLabel(tool)}',
      (editor) => editor.add(drawing),
    );
    if (_chart.setOverlays(
          session: _chart.session,
          priceLines: overlays.priceLines,
          events: overlays.events,
          valueMarkers: overlays.valueMarkers,
          drawings: _drawingHistory.editor.drawings,
        ) ==
        KChartOverlayUpdateStatus.applied) {
      setState(() {
        _drawingAnchors = const [];
        _previewAnchor = null;
        _drawingTool = null;
        _selectedDrawingId = drawing.id;
      });
    }
  }

  void _updateDrawingPreview(ChartDrawingAnchor? anchor) {
    if (_previewAnchor == anchor) return;
    setState(() => _previewAnchor = anchor);
  }

  ChartDrawing? get _drawingPreview {
    final tool = _drawingTool;
    final cursor = _previewAnchor;
    if (tool == null || cursor == null) return null;
    final anchors = [..._drawingAnchors, cursor];
    if (anchors.length < _requiredDrawingAnchors(tool)) return null;
    return ChartDrawing(
      id: 'acceptance-drawing-preview',
      kind: tool,
      anchors: anchors,
      text: tool == ChartDrawingKind.text ? '注释' : null,
      style: ChartDrawingStyle(colorKey: 'drawing.default', strokeWidth: 1),
    );
  }

  void _removeLastDrawing() {
    final overlays = _chart.value.overlays;
    if (overlays.drawings.isEmpty) return;
    final selectedId = _selectedDrawingId;
    final targetId = selectedId != null &&
            overlays.drawings.any((drawing) => drawing.id == selectedId)
        ? selectedId
        : overlays.drawings.last.id;
    _drawingHistory = _drawingHistory.execute(
      '删除画线',
      (editor) => editor.remove(targetId),
    );
    _applyDrawingEditor(_drawingHistory.editor);
  }

  int get _now =>
      widget.nowMilliseconds?.call() ?? DateTime.now().millisecondsSinceEpoch;
  int get _displayTime => _live ? _now : _simulationTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drawingSnapshotStore =
        widget.drawingSnapshotStore ?? _defaultDrawingSnapshotStore;
    _client = widget.client ?? AbortableBinanceMarketDataClient();
    _simulationTime = _now ~/ 60000 * 60000;
    final data = _initialCandles(_simulationTime);
    _chart = KChartController(
      series: KlineSeries.fromKline(data.first),
      initialData: data,
      indicatorDefinitions: widget.indicatorDefinitions,
      options: KChartOptions(
        mainPanel: KChartPanelOptions(minHeight: 180),
        mainTimeAxisHeight: 22,
        secondaryPanels: [
          KChartSecondaryPanelOptions(
              id: 'secondary-vol',
              layout: KChartPanelOptions(minHeight: 90, weight: 1))
        ],
        indicators: [
          KChartIndicatorBinding(
              panelId: 'main',
              config: IndicatorConfig(
                  instanceId: 'ema',
                  definitionId: 'legacy.ema',
                  parameters: {'period1': 7, 'period2': 25, 'period3': 99})),
          KChartIndicatorBinding(
              panelId: 'main',
              config: IndicatorConfig(
                  instanceId: 'super', definitionId: 'builtin.super')),
          KChartIndicatorBinding(
              panelId: 'secondary-vol',
              config: IndicatorConfig(
                  instanceId: 'vol', definitionId: 'legacy.vol')),
        ],
      ),
    );
    unawaited(_loadSavedDrawings());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_paused || !_foreground) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_live) {
        // 倒计时由 KChart 局部刷新；宿主只维持两秒一次的行情轮询。
        if (++_tick % 2 == 0) unawaited(_refresh());
      } else {
        // 明示 12 倍模拟时钟：每秒替换尾柱，每五秒跨过一分钟边界并追加。
        _simulationTime += 12000;
        _simulate(
            append: _simulationTime >= _chart.value.data.last.openTime + 60000);
      }
    });
  }

  void _simulate({required bool append}) {
    if (_live) return;
    final last = _chart.value.data.last;
    final session = _chart.session;
    if (append) {
      _chart.updateKline(last.copyWith(isClosed: true), session: session);
      _simulationTime = last.openTime + 60000;
      _chart.appendData([
        Kline(
          symbol: last.symbol,
          interval: last.interval,
          openTime: _simulationTime,
          closeTime: _simulationTime + 59999,
          open: last.close,
          high: last.close + 2,
          low: last.close - 2,
          close: last.close + 1,
          baseVolume: 1,
          quoteVolume: last.close + 1,
          tradeCount: 1,
          isClosed: false,
        )
      ], session: session);
      _appended++;
    } else {
      final close = last.close + (_replaced.isEven ? 3.0 : -2.0);
      _chart.updateKline(
          last.copyWith(
            high: math.max(last.high, close),
            low: math.min(last.low, close),
            close: close,
            baseVolume: last.baseVolume + 1,
            quoteVolume: last.quoteVolume + close,
          ),
          session: session);
      _replaced++;
    }
    setState(() {});
  }

  void _switchSource(bool live) {
    if (_live == live) return;
    _invalidateRequest();
    _simulationTime = _now ~/ 60000 * 60000;
    _chart.beginSeries(_chart.session.series,
        initialData: live ? const [] : _initialCandles(_simulationTime));
    _drawingHistory = ChartDrawingCommandHistory();
    setState(() {
      _drawingTool = null;
      _drawingAnchors = const [];
      _previewAnchor = null;
      _drawingEditing = false;
      _selectedDrawingId = null;
      _live = live;
      _error = null;
      _replaced = 0;
      _appended = 0;
      _tick = 0;
    });
    unawaited(_loadSavedDrawings());
    _startTimer();
    if (live && !_paused && _foreground) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!_live || _paused || !_foreground || _inFlight != null) return;
    final session = _chart.session; // 请求开始时捕获，禁止返回时重新读取会话令牌。
    final request = ++_requestSerial;
    _inFlight = request;
    V2DemoMarketRequest<List<Kline>>? cancellableRequest;
    try {
      final limit = _chart.value.data.isEmpty ? 180 : 2;
      final source = _client;
      cancellableRequest = source is V2DemoCancelableMarketDataSource
          ? source.requestCandles(
              symbol: session.series.symbol,
              interval: session.series.interval,
              limit: limit,
            )
          : null;
      _activeRequest = cancellableRequest;
      final data = await (cancellableRequest?.result ??
          source.candles(
            symbol: session.series.symbol,
            interval: session.series.interval,
            limit: limit,
          ));
      if (!mounted || request != _requestSerial || session != _chart.session) {
        return;
      }
      if (_chart.value.data.isEmpty) {
        _chart.replaceData(data, session: session);
      } else {
        for (final candle in data) {
          final isNew = candle.openTime > _chart.value.data.last.openTime;
          final receipt = _chart.updateKline(candle, session: session);
          if (receipt.changed) {
            if (isNew) {
              _appended++;
            } else {
              _replaced++;
            }
          }
        }
      }
      setState(() => _error = null);
    } on Object catch (error) {
      if (mounted && request == _requestSerial) {
        setState(
            () => _error = '${_client.displayName} 请求失败：$error（未自动切换为模拟数据）');
      }
    } finally {
      if (identical(_activeRequest, cancellableRequest)) {
        _activeRequest = null;
      }
      if (_inFlight == request) _inFlight = null;
    }
  }

  void _invalidateRequest() {
    _requestSerial++;
    _inFlight = null;
    final active = _activeRequest;
    _activeRequest = null;
    try {
      active?.cancel();
    } on Object {
      // 取消失败不允许阻断组件暂停或销毁，旧结果仍由请求序号挡住。
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    // 暂停不清除选中或滚动位置，只使在途响应失效。
    _invalidateRequest();
    _startTimer();
    if (!_paused && _live) unawaited(_refresh());
  }

  Future<void> _openSettings() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.68,
          child: V2SdkChartSettings(
            controller: _chart,
            onOptionsChanged: () {
              if (mounted) setState(() {}); // 副图数量变更时调整外层图表高度。
            },
          ),
        ),
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _invalidateRequest();
    }
    _startTimer();
    if (_foreground && _live && !_paused) unawaited(_refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _invalidateRequest();
    WidgetsBinding.instance.removeObserver(this);
    _chart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('新组件验收'), actions: [
          IconButton(
              key: const ValueKey('acceptance-settings'),
              tooltip: '图表设置',
              onPressed: _openSettings,
              icon: const Icon(Icons.tune)),
          IconButton(
              key: const ValueKey('acceptance-pause'),
              tooltip: _paused ? '继续刷新' : '暂停刷新',
              onPressed: _togglePause,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause)),
          IconButton(
              tooltip: '回到最新',
              onPressed: _chart.scrollToLatest,
              icon: const Icon(Icons.last_page)),
        ]),
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, constraints) => ListView(
                      children: [
                        Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                  key: const ValueKey('acceptance-simulation'),
                                  onPressed: () => _switchSource(false),
                                  child: const Text('模拟数据')),
                              TextButton(
                                  key: const ValueKey('acceptance-binance'),
                                  onPressed: () => _switchSource(true),
                                  child: Text('${_client.displayName} 实时')),
                              TextButton(
                                  key: const ValueKey('acceptance-replace'),
                                  onPressed: _live
                                      ? null
                                      : () => _simulate(append: false),
                                  child: const Text('替换尾柱')),
                              TextButton(
                                  key: const ValueKey('acceptance-append'),
                                  onPressed: _live
                                      ? null
                                      : () => _simulate(append: true),
                                  child: const Text('新增一根')),
                              TextButton(
                                  key: const ValueKey('acceptance-trend-line'),
                                  onPressed: () => _chooseDrawingTool(
                                      _drawingTool == ChartDrawingKind.trendLine
                                          ? null
                                          : ChartDrawingKind.trendLine),
                                  child: Text(
                                      _drawingTool == ChartDrawingKind.trendLine
                                          ? '取消趋势线'
                                          : '画趋势线')),
                              TextButton(
                                  key: const ValueKey(
                                      'acceptance-horizontal-line'),
                                  onPressed: () => _chooseDrawingTool(
                                      _drawingTool ==
                                              ChartDrawingKind.horizontalLine
                                          ? null
                                          : ChartDrawingKind.horizontalLine),
                                  child: Text(_drawingTool ==
                                          ChartDrawingKind.horizontalLine
                                      ? '取消水平线'
                                      : '画水平线')),
                              PopupMenuButton<ChartDrawingKind>(
                                key: const ValueKey('acceptance-drawing-tools'),
                                tooltip: '更多绘图工具',
                                onSelected: _chooseDrawingTool,
                                itemBuilder: (context) => [
                                  for (final kind in ChartDrawingKind.values)
                                    if (kind != ChartDrawingKind.trendLine &&
                                        kind != ChartDrawingKind.horizontalLine)
                                      PopupMenuItem(
                                        value: kind,
                                        child: Text(_drawingToolLabel(kind)),
                                      ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('更多画图工具'),
                                ),
                              ),
                              TextButton(
                                  key: const ValueKey(
                                      'acceptance-remove-drawing'),
                                  onPressed: _removeLastDrawing,
                                  child: Text(_selectedDrawingId == null
                                      ? '删除最后一条画线'
                                      : '删除所选画线')),
                              TextButton(
                                key: const ValueKey('acceptance-undo-drawing'),
                                onPressed: _drawingHistory.canUndo
                                    ? _undoDrawing
                                    : null,
                                child: const Text('撤销画线'),
                              ),
                              TextButton(
                                key: const ValueKey('acceptance-redo-drawing'),
                                onPressed: _drawingHistory.canRedo
                                    ? _redoDrawing
                                    : null,
                                child: const Text('重做画线'),
                              ),
                              TextButton(
                                key: const ValueKey('acceptance-save-drawings'),
                                onPressed: _writingDrawingSnapshot
                                    ? null
                                    : () => unawaited(_saveDrawings()),
                                child: Text(
                                    _writingDrawingSnapshot ? '保存中…' : '保存画线'),
                              ),
                              TextButton(
                                key: const ValueKey(
                                    'acceptance-restore-drawings'),
                                onPressed: _loadingDrawingSnapshot ||
                                        _savedDrawingJson == null
                                    ? null
                                    : () => unawaited(_restoreDrawings()),
                                child: Text(
                                    _loadingDrawingSnapshot ? '读取中…' : '恢复画线'),
                              ),
                              if (_drawingStorageError != null)
                                Text(
                                  _drawingStorageError!,
                                  key: const ValueKey(
                                      'acceptance-drawing-storage-error'),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              PopupMenuButton<String>(
                                key: const ValueKey('acceptance-drawing-list'),
                                tooltip: '选择绘图',
                                onSelected: _selectDrawing,
                                itemBuilder: (context) => [
                                  for (final drawing
                                      in _chart.value.overlays.drawings)
                                    PopupMenuItem(
                                      value: drawing.id,
                                      child: Text(
                                        '${_drawingToolLabel(drawing.kind)} · ${drawing.id}${drawing.style.visible ? '' : '（隐藏）'}${drawing.isLocked ? '（锁定）' : ''}',
                                      ),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(_selectedDrawing == null
                                      ? '选择画线'
                                      : '已选 ${_drawingToolLabel(_selectedDrawing!.kind)}'),
                                ),
                              ),
                              TextButton(
                                key: const ValueKey('acceptance-toggle-lock'),
                                onPressed: _selectedDrawing == null
                                    ? null
                                    : () => _setDrawingLocked(
                                          !_selectedDrawing!.isLocked,
                                        ),
                                child: Text(
                                    (_selectedDrawing?.isLocked ?? false)
                                        ? '解锁画线'
                                        : '锁定画线'),
                              ),
                              TextButton(
                                key:
                                    const ValueKey('acceptance-toggle-visible'),
                                onPressed: _selectedDrawing == null
                                    ? null
                                    : () => _setDrawingVisible(
                                          !_selectedDrawing!.style.visible,
                                        ),
                                child: Text(
                                  (_selectedDrawing?.style.visible ?? true)
                                      ? '隐藏画线'
                                      : '显示画线',
                                ),
                              ),
                              TextButton(
                                key: const ValueKey('acceptance-edit-drawings'),
                                onPressed: () {
                                  final editing = !_drawingEditing;
                                  if (editing) _chart.clearSelection();
                                  setState(() {
                                    _drawingEditing = editing;
                                    _drawingTool = null;
                                    _drawingAnchors = const [];
                                    _previewAnchor = null;
                                    if (!_drawingEditing) {
                                      _selectedDrawingId = null;
                                    }
                                  });
                                },
                                child:
                                    Text(_drawingEditing ? '退出画线编辑' : '编辑画线'),
                              ),
                              TextButton(
                                key: const ValueKey('acceptance-snap-drawing'),
                                onPressed: () => setState(() {
                                  _drawingSnapToOhlc = !_drawingSnapToOhlc;
                                }),
                                child: Text(_drawingSnapToOhlc
                                    ? '关闭OHLC吸附'
                                    : '开启OHLC吸附'),
                              ),
                            ]),
                        if (_drawingTool != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(_drawingAnchors.isEmpty
                                ? '正在绘制${_drawingToolLabel(_drawingTool!)}，请在主图依次点击 ${_requiredDrawingAnchors(_drawingTool!)} 个锚点；再次选工具可取消'
                                : '正在绘制${_drawingToolLabel(_drawingTool!)}：已选 ${_drawingAnchors.length}/${_requiredDrawingAnchors(_drawingTool!)} 个锚点，请继续点击主图；再次选工具可取消'),
                          ),
                        if (_drawingEditing)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(_selectedDrawingId == null
                                ? '编辑模式：点击绘图进行选择；拖动锚点可调整单点，拖动线条本体可整体移动'
                                : '已选择绘图 $_selectedDrawingId；拖动圆点调整锚点，拖动图形本体整体移动'),
                          ),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${_live ? '${_client.displayName} BTCUSDT · 1 分钟 · 两秒轮询' : '模拟 · 12 倍时钟 · 每五秒新增'}${_paused ? '（已暂停）' : ''}\n替换 $_replaced 次 · 新增 $_appended 根',
                              key: const ValueKey('acceptance-status'),
                              style: const TextStyle(fontSize: 11),
                            )),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red))),
                        ValueListenableBuilder<KChartViewState>(
                          valueListenable: _chart,
                          builder: (context, state, _) {
                            if (state.issues.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final issue = state.issues.first;
                            final kind = issue.kind == KChartIssueKind.indicator
                                ? '指标'
                                : '历史加载';
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '$kind问题 ${issue.instanceId ?? ''}：${issue.error}',
                                key: const ValueKey('acceptance-chart-issue'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          },
                        ),
                        SizedBox(
                            height: math.max(
                              math.max(380, constraints.maxHeight - 100),
                              260 +
                                  _chart.value.options.secondaryPanels.length *
                                      110,
                            ),
                            child: TickerMode(
                              enabled: !_paused,
                              child: KChart(
                                controller: _chart,
                                theme: KChartTheme.light()
                                    .copyWith(gridStrokeWidth: 0.4),
                                currentTimeMilliseconds: () => _displayTime,
                                onDrawingAnchor: _drawingTool == null
                                    ? null
                                    : _addDrawingAnchor,
                                onDrawingHover: _drawingTool == null
                                    ? null
                                    : _updateDrawingPreview,
                                drawingPreview: _drawingPreview,
                                drawingEditingEnabled: _drawingEditing,
                                drawingSnapToOhlc: _drawingSnapToOhlc,
                                selectedDrawingId: _selectedDrawingId,
                                onDrawingSelectionChanged: _selectDrawing,
                                onDrawingEditCommitted: (before, after) {
                                  _drawingHistory = _drawingHistory.execute(
                                    '移动绘图锚点',
                                    (editor) => ChartDrawingEditor(
                                      drawings: after,
                                      selectedDrawingId: _selectedDrawingId,
                                    ),
                                  );
                                  setState(() {});
                                },
                                emptyBuilder: (_) => const Center(
                                    child: Text('等待币安行情；网络不可用时请切回模拟数据')),
                              ),
                            )),
                      ],
                    ))),
      );
}

/// 确定性价格序列，只把最后一根开盘时间对齐到宿主时钟，完全不依赖网络。
List<Kline> _initialCandles(int latestOpenTime) => List.generate(180, (index) {
      final openTime = latestOpenTime - (179 - index) * 60000;
      final open = 60000.0 + index * 3 + math.sin(index / 7) * 60;
      final close = open + (index.isEven ? 8 : -5);
      return Kline(
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        openTime: openTime,
        closeTime: openTime + 59999,
        open: open,
        high: math.max(open, close) + 5,
        low: math.min(open, close) - 5,
        close: close,
        baseVolume: 20 + index.toDouble(),
        quoteVolume: (20 + index) * close,
        tradeCount: 20 + index,
        isClosed: index != 179,
      );
    }, growable: false);

int _requiredDrawingAnchors(ChartDrawingKind kind) => switch (kind) {
      ChartDrawingKind.horizontalLine ||
      ChartDrawingKind.verticalLine ||
      ChartDrawingKind.text ||
      ChartDrawingKind.priceMarker =>
        1,
      ChartDrawingKind.parallelChannel => 3,
      _ => 2,
    };

String _drawingToolLabel(ChartDrawingKind kind) => switch (kind) {
      ChartDrawingKind.trendLine => '趋势线',
      ChartDrawingKind.horizontalLine => '水平线',
      ChartDrawingKind.verticalLine => '垂直线',
      ChartDrawingKind.ray => '射线',
      ChartDrawingKind.rectangle => '矩形',
      ChartDrawingKind.parallelChannel => '平行通道',
      ChartDrawingKind.fibonacciRetracement => '斐波那契回撤',
      ChartDrawingKind.text => '文本标注',
      ChartDrawingKind.priceMarker => '价格标记',
    };
