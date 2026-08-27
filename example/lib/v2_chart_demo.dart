import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'package:m_k_chart/v2_example_support.dart';

import 'okx_market_data_client.dart';

/// Runnable trading-chart example backed by OKX public market data.
///
/// The initial state remains useful offline: local candles render first, then
/// the latest successful public response replaces them. Set [loadOnStart] to
/// false in widget tests or an entirely offline host.
class V2TradingChartDemo extends StatefulWidget {
  const V2TradingChartDemo({super.key, this.loadOnStart = true});

  final bool loadOnStart;

  @override
  State<V2TradingChartDemo> createState() => _V2TradingChartDemoState();
}

class _V2TradingChartDemoState extends State<V2TradingChartDemo> {
  static final _intervals = <KlineInterval>[
    KlineInterval.oneMinute,
    KlineInterval.fiveMinutes,
    KlineInterval.fifteenMinutes,
    KlineInterval.oneHour,
    KlineInterval.fourHours,
    KlineInterval.oneDay,
  ];

  static const _modes = <ChartMainMode>[
    ChartMainMode.candlestick,
    ChartMainMode.hollowCandlestick,
    ChartMainMode.ohlc,
    ChartMainMode.heikinAshi,
    ChartMainMode.line,
    ChartMainMode.area,
  ];

  static const _indicators = <_IndicatorOption>[
    _IndicatorOption('ma', 'MA', 'legacy.ma', true),
    _IndicatorOption('ema', 'EMA', 'legacy.ema', true),
    _IndicatorOption('boll', 'BOLL', 'legacy.boll', true),
    _IndicatorOption('sar', 'SAR', 'legacy.sar', true),
    _IndicatorOption('vwap', 'VWAP', 'builtin.vwap', true),
    _IndicatorOption('vol', 'VOL', 'legacy.vol', false),
    _IndicatorOption('macd', 'MACD', 'legacy.macd', false),
    _IndicatorOption('kdj', 'KDJ', 'legacy.kdj', false),
    _IndicatorOption('rsi', 'RSI', 'legacy.rsi', false),
    _IndicatorOption('wr', 'WR', 'legacy.wr', false),
    _IndicatorOption('obv', 'OBV', 'legacy.obv', false),
    _IndicatorOption('atr', 'ATR', 'builtin.atr', false),
    _IndicatorOption('cci', 'CCI', 'builtin.cci', false),
    _IndicatorOption('dmi', 'DMI', 'builtin.dmi', false),
    _IndicatorOption('roc', 'ROC', 'builtin.roc', false),
    _IndicatorOption('stoch-rsi', 'Stoch RSI', 'builtin.stochRsi', false),
  ];

  late final StandardChartRenderPipeline<KChartTheme> _pipeline;
  late final ChartInteractionMachine _interactionMachine;
  late final ChartNavigationMachine _navigationMachine;
  late final OkxMarketDataClient _marketData;
  late final IndicatorEngine _indicatorEngine;
  final _instrumentController = TextEditingController(text: 'BTC-USDT');
  final KChartTheme _theme = KChartTheme.light(
    upColor: const Color(0xff0b9b69),
    downColor: const Color(0xffd93d56),
  );
  final Set<String> _mainIndicators = {'ma'};
  final List<String> _secondaryIndicators = ['vol', 'macd'];

  var _instrumentId = 'BTC-USDT';
  var _interval = KlineInterval.oneMinute;
  var _mode = ChartMainMode.candlestick;
  var _candleLimit = 180;
  var _visibleCandles = 90;
  var _secondaryPanelHeight = 108.0;
  var _overlaySecondaryIndicators = false;
  var _revision = 0;
  var _viewportRevision = 0;
  var _selectionRevision = 0;
  var _scrollOffsetItems = 0.0;
  double? _itemExtent;
  int? _selectedIndex;
  String? _selectedPanelId;
  double? _selectedPrice;
  var _selectedLocalY = 0.0;
  var _loadGeneration = 0;
  var _isLoading = false;
  String? _loadError;
  late _DemoData _data;

  @override
  void initState() {
    super.initState();
    _pipeline = StandardChartRenderPipeline<KChartTheme>();
    _interactionMachine = ChartInteractionMachine();
    _navigationMachine = ChartNavigationMachine();
    _marketData = OkxMarketDataClient();
    final registry = IndicatorRegistry();
    registerBuiltInIndicatorDefinitions(registry);
    _indicatorEngine = IndicatorEngine(registry: registry);
    _data = _createData(_interval, _revision);
    if (widget.loadOnStart) {
      _loadCandles();
    }
  }

  @override
  void dispose() {
    _instrumentController.dispose();
    _pipeline.dispose();
    super.dispose();
  }

  void _selectInterval(KlineInterval interval) {
    if (interval == _interval) return;
    setState(() {
      _interval = interval;
      _advanceRevision();
      _data = _createData(interval, _revision);
      _scrollOffsetItems = 0;
      _itemExtent = null;
      _clearSelection();
    });
    _loadCandles();
  }

  void _selectCandleLimit(int limit) {
    if (limit == _candleLimit) return;
    setState(() => _candleLimit = limit);
    _loadCandles();
  }

  void _submitInstrument() {
    final instrument = _instrumentController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]+-[A-Z0-9]+(?:-[A-Z0-9]+)?$').hasMatch(instrument)) {
      setState(() => _loadError = '请输入 OKX 交易对，例如 BTC-USDT。');
      return;
    }
    setState(() {
      _instrumentId = instrument;
      _instrumentController.text = instrument;
    });
    _loadCandles();
  }

  Future<void> _loadCandles() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final candles = await _marketData.candles(
        instId: _instrumentId,
        interval: _interval,
        limit: _candleLimit,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _advanceRevision();
        _data = _DemoData(
            UnmodifiableListView(candles), KlineDataVersion(_revision));
        _scrollOffsetItems = 0;
        _itemExtent = null;
        _clearSelection();
      });
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loadError = '$error');
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectMode(ChartMainMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _advanceRevision();
    });
  }

  void _toggleMainIndicator(String id, bool enabled) => setState(() {
        enabled ? _mainIndicators.add(id) : _mainIndicators.remove(id);
        _advanceRevision();
      });

  void _toggleSecondaryIndicator(String id, bool enabled) => setState(() {
        if (enabled) {
          _secondaryIndicators.add(id);
        } else {
          _secondaryIndicators.remove(id);
        }
        _advanceRevision();
      });

  void _moveSecondaryIndicator(String id, int direction) {
    final from = _secondaryIndicators.indexOf(id);
    final to = from + direction;
    if (from < 0 || to < 0 || to >= _secondaryIndicators.length) return;
    setState(() {
      final item = _secondaryIndicators.removeAt(from);
      _secondaryIndicators.insert(to, item);
      _advanceRevision();
    });
  }

  void _advanceRevision() => _revision++;

  void _clearSelection() {
    _selectedIndex = null;
    _selectedPanelId = null;
    _selectedPrice = null;
    _selectionRevision++;
  }

  void _handleChartIntent(
    ChartInteractionIntent intent,
    RenderSnapshot<KChartTheme> snapshot,
  ) {
    switch (intent) {
      case ChartViewportIntent(:final viewport):
        setState(() {
          _scrollOffsetItems = viewport.scrollOffsetItems;
          _itemExtent = viewport.itemExtent;
          _viewportRevision++;
          _clearSelection();
        });
      case ChartCrosshairIntent(:final isActive, :final localX, :final localY):
        if (isActive) {
          _selectChartPosition(Offset(localX, localY), snapshot);
        } else {
          setState(_clearSelection);
        }
      case ChartHistoryPagingIntent():
        break;
    }
  }

  void _selectChartPosition(
    Offset localPosition,
    RenderSnapshot<KChartTheme> snapshot,
  ) {
    final bounds = snapshot.layout.drawingBounds;
    if (!bounds.contains(x: localPosition.dx, y: localPosition.dy) ||
        snapshot.data.data.isEmpty) {
      return;
    }
    final index = ChartXTransform(
      viewport: snapshot.viewport,
      data: snapshot.data,
    ).localXToNearestIndex(localPosition.dx);
    String? panelId;
    for (final panel in snapshot.layout.panels) {
      if (panel.bounds.contains(x: localPosition.dx, y: localPosition.dy)) {
        panelId = panel.spec.id;
        break;
      }
    }
    double? price;
    if (panelId != null) {
      price = ChartLayerGeometry.rangeFor(snapshot, panelId)
          .transform(snapshot.layout.panel(panelId).bounds)
          .localYToPrice(localPosition.dy);
    }
    setState(() {
      _selectedIndex = index;
      _selectedPanelId = panelId;
      _selectedPrice = price;
      _selectedLocalY = localPosition.dy;
      _selectionRevision++;
    });
  }

  RenderSelectionSnapshot _selectionFor(RenderSnapshot<KChartTheme> snapshot) {
    final index = _selectedIndex;
    if (index == null || index >= snapshot.data.data.length) {
      return const RenderSelectionSnapshot.hidden();
    }
    final bounds = snapshot.layout.drawingBounds;
    final localX = ChartXTransform(
      viewport: snapshot.viewport,
      data: snapshot.data,
    ).indexToLocalX(index);
    final selectedPrice = _selectedPrice;
    final selectedPanelId = _selectedPanelId;
    final isSnapped = selectedPrice != null && selectedPanelId != null;
    final double localY;
    if (selectedPrice == null || selectedPanelId == null) {
      localY = _selectedLocalY.clamp(bounds.top, bounds.bottom).toDouble();
    } else {
      localY = ChartLayerGeometry.rangeFor(snapshot, selectedPanelId)
          .transform(snapshot.layout.panel(selectedPanelId).bounds)
          .priceToLocalY(selectedPrice)
          .clamp(bounds.top, bounds.bottom)
          .toDouble();
    }
    return RenderSelectionSnapshot.visible(
      localX: localX.clamp(bounds.left, bounds.right).toDouble(),
      localY: localY,
      dataIndex: isSnapped ? index : null,
      price: isSnapped ? selectedPrice : null,
      valueKind: isSnapped ? RenderSelectionValueKind.close : null,
    );
  }

  _IndicatorOption _indicator(String id) =>
      _indicators.singleWhere((option) => option.id == id);

  String _secondaryPanelId(String id) =>
      _overlaySecondaryIndicators ? 'secondary-overlay' : 'secondary-$id';

  List<RenderIndicatorSnapshot> _indicatorSnapshots() {
    final options = [
      for (final id in _mainIndicators) _indicator(id),
      for (final id in _secondaryIndicators) _indicator(id),
    ];
    final configs = [
      for (final option in options)
        IndicatorConfig(
          instanceId: 'demo-${option.id}',
          definitionId: option.definitionId,
        ),
    ];
    final batch = _indicatorEngine.resolveAll(_data, configs);
    return [
      for (final option in options)
        if (batch.results['demo-${option.id}'] case final result?)
          RenderIndicatorSnapshot.fromResult(
            result: result,
            descriptor: _indicatorEngine.registry
                .find(option.definitionId)!
                .rendererDescriptor,
            panelId: option.isMain ? 'main' : _secondaryPanelId(option.id),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final secondaryPanels = _secondaryIndicators.isEmpty
        ? const <ChartPanelSpec>[]
        : _overlaySecondaryIndicators
            ? [
                ChartPanelSpec.secondary(
                    id: 'secondary-overlay',
                    minHeight: _secondaryPanelHeight,
                    gridRows: 3)
              ]
            : [
                for (final id in _secondaryIndicators)
                  ChartPanelSpec.secondary(
                    id: _secondaryPanelId(id),
                    minHeight: _secondaryPanelHeight,
                    gridRows: 3,
                  ),
              ];
    final chartHeight = math.max(
      390.0,
      260 + secondaryPanels.length * (_secondaryPanelHeight + 8),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 交易图表'),
        backgroundColor: const Color(0xff075985),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '刷新 OKX 行情',
            onPressed: _isLoading ? null : _loadCandles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xfff8fafc),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$_instrumentId · ${_interval.code}',
              style: const TextStyle(
                  color: Color(0xff0f172a),
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _isLoading
                  ? '正在加载 OKX 行情…'
                  : _loadError == null
                      ? 'OKX 公共行情 · ${_data.data.length} 根 K 线'
                      : '已使用离线数据 · $_loadError',
              style: const TextStyle(color: Color(0xff475569)),
            ),
            const SizedBox(height: 16),
            _ToolbarSection(
              title: '交易对与数据范围',
              children: [
                SizedBox(
                  width: 210,
                  child: TextField(
                    key: const ValueKey('instrument-input'),
                    controller: _instrumentController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Color(0xff0f172a)),
                    decoration: const InputDecoration(
                        labelText: 'OKX 交易对',
                        hintText: 'BTC-USDT',
                        isDense: true),
                    onSubmitted: (_) => _submitInstrument(),
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('load-instrument'),
                  onPressed: _isLoading ? null : _submitInstrument,
                  child: const Text('加载'),
                ),
                DropdownButton<int>(
                  key: const ValueKey('candle-limit'),
                  value: _candleLimit,
                  dropdownColor: Colors.white,
                  items: const [100, 180, 300]
                      .map((limit) => DropdownMenuItem(
                          value: limit, child: Text('$limit 根 K 线')))
                      .toList(growable: false),
                  onChanged: (limit) {
                    if (limit != null) _selectCandleLimit(limit);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ToolbarSection(
              title: '周期',
              children: [
                for (final interval in _intervals)
                  ChoiceChip(
                    key: ValueKey('period-${interval.code}'),
                    label: Text(interval.code),
                    selected: interval == _interval,
                    onSelected: (_) => _selectInterval(interval),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ToolbarSection(
              title: '主图类型',
              children: [
                for (final mode in _modes)
                  ChoiceChip(
                    key: ValueKey('mode-${mode.name}'),
                    label: Text(_modeLabel(mode)),
                    selected: mode == _mode,
                    onSelected: (_) => _selectMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ToolbarSection(
              title: '主图叠加指标',
              children: [
                for (final option in _indicators.where((item) => item.isMain))
                  FilterChip(
                    key: ValueKey('main-indicator-${option.id}'),
                    label: Text(option.label),
                    selected: _mainIndicators.contains(option.id),
                    onSelected: (enabled) =>
                        _toggleMainIndicator(option.id, enabled),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ToolbarSection(
              title: '副图指标',
              children: [
                for (final option in _indicators.where((item) => !item.isMain))
                  FilterChip(
                    key: ValueKey('secondary-indicator-${option.id}'),
                    label: Text(option.label),
                    selected: _secondaryIndicators.contains(option.id),
                    onSelected: (enabled) =>
                        _toggleSecondaryIndicator(option.id, enabled),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('将选中的副图指标叠加到同一面板',
                  style: TextStyle(color: Color(0xff0f172a))),
              subtitle: const Text('关闭后，每个指标都拥有可调整高度的独立面板。',
                  style: TextStyle(color: Color(0xff475569))),
              value: _overlaySecondaryIndicators,
              onChanged: (value) => setState(() {
                _overlaySecondaryIndicators = value;
                _advanceRevision();
              }),
            ),
            if (!_overlaySecondaryIndicators &&
                _secondaryIndicators.length > 1) ...[
              const SizedBox(height: 4),
              const Text('副图面板顺序',
                  style: TextStyle(
                      color: Color(0xff0f172a), fontWeight: FontWeight.w600)),
              for (var index = 0; index < _secondaryIndicators.length; index++)
                _PanelOrderRow(
                  label: _indicator(_secondaryIndicators[index]).label,
                  canMoveUp: index > 0,
                  canMoveDown: index < _secondaryIndicators.length - 1,
                  onMoveUp: () =>
                      _moveSecondaryIndicator(_secondaryIndicators[index], -1),
                  onMoveDown: () =>
                      _moveSecondaryIndicator(_secondaryIndicators[index], 1),
                ),
            ],
            const SizedBox(height: 12),
            _SliderSetting(
              label: '可见 K 线数量',
              value: _visibleCandles.toDouble(),
              min: 20,
              max: 300,
              divisions: 28,
              valueLabel: '$_visibleCandles',
              onChanged: (value) => setState(() {
                _visibleCandles = value.round();
                _itemExtent = null;
                _advanceRevision();
              }),
            ),
            _SliderSetting(
              label: '副图面板最小高度',
              value: _secondaryPanelHeight,
              min: 72,
              max: 180,
              divisions: 9,
              valueLabel: '${_secondaryPanelHeight.round()} px',
              onChanged: (value) => setState(() {
                _secondaryPanelHeight = value;
                _advanceRevision();
              }),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'V2 图表 ${_interval.code} ${_modeLabel(_mode)}',
              child: SizedBox(
                height: chartHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.max(1.0, constraints.maxWidth);
                    final layout = ChartLayoutModel(
                      width: width,
                      height: chartHeight,
                      leftPadding: 8,
                      rightPadding: 8,
                      bottomAxisHeight: 24,
                      panelSpacing: 8,
                      mainPanel: const ChartPanelSpec.main(
                          minHeight: 220, gridRows: 5),
                      secondaryPanels: secondaryPanels,
                    );
                    final viewport = ChartViewport(
                      itemCount: _data.data.length,
                      width: layout.drawingBounds.width,
                      itemExtent: _itemExtent ??
                          layout.drawingBounds.width / _visibleCandles,
                      scrollOffsetItems: _scrollOffsetItems,
                    );
                    final baseSnapshot = RenderSnapshot<KChartTheme>(
                      data: _data,
                      viewport: viewport,
                      layout: layout,
                      theme: _theme,
                      versions: RenderSnapshotVersions(
                        data: _data.version.value,
                        viewport: _viewportRevision,
                        selection: _selectionRevision,
                        theme: _revision,
                        layout: _revision,
                      ),
                      indicators: _indicatorSnapshots(),
                      mainMode: _mode,
                    );
                    final snapshot = RenderSnapshot<KChartTheme>(
                      data: _data,
                      viewport: viewport,
                      layout: layout,
                      theme: _theme,
                      versions: RenderSnapshotVersions(
                        data: _data.version.value,
                        viewport: _viewportRevision,
                        selection: _selectionRevision,
                        theme: _revision,
                        layout: _revision,
                      ),
                      indicators: baseSnapshot.indicators,
                      selection: _selectionFor(baseSnapshot),
                      mainMode: _mode,
                    );
                    final selectedIndex = _selectedIndex;
                    final selectedCandle = selectedIndex != null &&
                            selectedIndex < _data.data.length
                        ? _data.data[selectedIndex]
                        : null;
                    return ChartGestureRegion(
                      machine: _interactionMachine,
                      navigationMachine: _navigationMachine,
                      viewport: () => viewport,
                      onIntent: (intent) =>
                          _handleChartIntent(intent, baseSnapshot),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _selectChartPosition(
                            details.localPosition, baseSnapshot),
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                key: const ValueKey('v2-chart-canvas'),
                                painter: _DemoPainter(
                                    pipeline: _pipeline, snapshot: snapshot),
                                size: Size(width, chartHeight),
                              ),
                            ),
                            const Positioned(
                              left: 12,
                              bottom: 30,
                              child: IgnorePointer(
                                child: Text(
                                  '左右滑动查看历史 · 点击或长按查看详情',
                                  style: TextStyle(
                                    color: Color(0xff334155),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (selectedCandle != null)
                              Positioned(
                                left: 12,
                                top: 12,
                                child: IgnorePointer(
                                  child: _CrosshairDetails(
                                    candle: selectedCandle,
                                    selectedPrice: _selectedPrice,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'OKX 行情接口无需认证；网络不可用时，Demo 会继续展示本地确定性数据。',
              style: TextStyle(color: Color(0xff475569)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarSection extends StatelessWidget {
  const _ToolbarSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xff0f172a), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      );
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.divisions,
      required this.valueLabel,
      required this.onChanged});
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · $valueLabel',
              style: const TextStyle(color: Color(0xff334155))),
          Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged),
        ],
      );
}

class _PanelOrderRow extends StatelessWidget {
  const _PanelOrderRow(
      {required this.label,
      required this.canMoveUp,
      required this.canMoveDown,
      required this.onMoveUp,
      required this.onMoveDown});
  final String label;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child:
                Text(label, style: const TextStyle(color: Color(0xff0f172a))),
          ),
          IconButton(
              tooltip: '上移 $label 面板',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward)),
          IconButton(
              tooltip: '下移 $label 面板',
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.arrow_downward))
        ],
      );
}

class _CrosshairDetails extends StatelessWidget {
  const _CrosshairDetails({required this.candle, required this.selectedPrice});

  final Kline candle;
  final double? selectedPrice;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('crosshair-details'),
        width: 214,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xf2ffffff),
          border: Border.all(color: const Color(0xff94a3b8)),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x1f0f172a), blurRadius: 8),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Color(0xff0f172a), fontSize: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('K 线详情',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text('横坐标：${_formatTime(candle.openTime)}'),
              if (selectedPrice != null)
                Text('纵坐标：${selectedPrice!.toStringAsFixed(2)}'),
              Text(
                  '开 ${_formatPrice(candle.open)}  高 ${_formatPrice(candle.high)}'),
              Text(
                  '低 ${_formatPrice(candle.low)}  收 ${_formatPrice(candle.close)}'),
              Text('成交量：${_formatVolume(candle.baseVolume)}'),
            ],
          ),
        ),
      );
}

String _formatTime(int epochMilliseconds) {
  final time = DateTime.fromMillisecondsSinceEpoch(epochMilliseconds).toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${twoDigits(time.month)}-${twoDigits(time.day)} '
      '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
}

String _formatPrice(double value) => value.toStringAsFixed(2);

String _formatVolume(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
  return value.toStringAsFixed(2);
}

class _DemoPainter extends CustomPainter {
  const _DemoPainter({required this.pipeline, required this.snapshot});
  final StandardChartRenderPipeline<KChartTheme> pipeline;
  final RenderSnapshot<KChartTheme> snapshot;
  @override
  void paint(Canvas canvas, Size size) =>
      pipeline.paint(RenderLayerContext(canvas: canvas, snapshot: snapshot));
  @override
  bool shouldRepaint(covariant _DemoPainter oldDelegate) => true;
}

_DemoData _createData(KlineInterval interval, int revision) {
  final step = interval.duration!.inMilliseconds;
  final seed =
      interval.code.codeUnits.fold<int>(0, (sum, value) => sum + value);
  final values = List<Kline>.generate(180, (index) {
    final trend = index * (0.36 + seed % 5 * .02);
    final wave = ((index + seed) % 19 - 9) * .48;
    final open = 1000 + trend + wave;
    final close = open + ((index + seed) % 7 - 3) * .32;
    final openTime = 1704067200000 + index * step;
    return Kline(
        symbol: 'BTC-USDT',
        interval: interval,
        openTime: openTime,
        closeTime: openTime + step - 1,
        open: open,
        high: math.max(open, close) + 1.25 + index % 4 * .1,
        low: math.min(open, close) - 1.15 - index % 3 * .1,
        close: close,
        baseVolume: 800 + index % 17 * 53,
        quoteVolume: 1000,
        tradeCount: 20 + index % 30,
        isClosed: index != 179);
  });
  return _DemoData(UnmodifiableListView(values), KlineDataVersion(revision));
}

String _modeLabel(ChartMainMode mode) => switch (mode) {
      ChartMainMode.candlestick => '蜡烛图',
      ChartMainMode.hollowCandlestick => '空心蜡烛',
      ChartMainMode.ohlc => 'OHLC',
      ChartMainMode.heikinAshi => '平均 K 线',
      ChartMainMode.line => '折线图',
      ChartMainMode.area => '面积图',
    };

final class _IndicatorOption {
  const _IndicatorOption(this.id, this.label, this.definitionId, this.isMain);
  final String id;
  final String label;
  final String definitionId;
  final bool isMain;
}

final class _DemoData implements VersionedKlineData {
  const _DemoData(this.data, this.version);
  @override
  final List<Kline> data;
  @override
  final KlineDataVersion version;
}
