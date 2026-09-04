import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'package:m_k_chart/renderer/legacy_chart_viewport.dart';
import 'package:m_k_chart/v2_example_support.dart';

import 'binance_market_data_client.dart';
import 'v2_depth_chart_demo.dart';
import 'v2_trade_overlay_examples.dart';

/// Runnable trading-chart example backed by Binance public market data.
///
/// The initial state remains useful offline: local candles render first, then
/// the latest successful public response replaces them. Set [loadOnStart] to
/// false in widget tests or an entirely offline host.
class V2TradingChartDemo extends StatefulWidget {
  const V2TradingChartDemo({
    super.key,
    this.loadOnStart = true,
    this.fullscreen = false,
  });

  final bool loadOnStart;
  final bool fullscreen;

  @override
  State<V2TradingChartDemo> createState() => _V2TradingChartDemoState();
}

class _V2TradingChartDemoState extends State<V2TradingChartDemo> {
  static const _panelSpacing = 0.0;

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
    _IndicatorOption('ma', 'MA', 'legacy.ma', true, '周期 5 / 10 / 20 / 30'),
    _IndicatorOption('ema', 'EMA', 'legacy.ema', true, '周期 5 / 10 / 30'),
    _IndicatorOption(
      'boll',
      'BOLL',
      'legacy.boll',
      true,
      '周期 20 · 倍数 2',
      parameters: {'period': 20, 'multiplier': 2},
    ),
    _IndicatorOption(
      'sar',
      'SAR',
      'legacy.sar',
      true,
      '起始 0.02 · 步长 0.02 · 最大 0.20',
      parameters: {'afStart': 0.02, 'afIncrement': 0.02, 'afMax': 0.2},
    ),
    _IndicatorOption(
        'vwap', 'VWAP', 'builtin.vwap', true, '典型价 (高 + 低 + 收) / 3'),
    _IndicatorOption(
      'avl',
      'AVL',
      'builtin.avl',
      true,
      '每根 K 线成交额 / 成交量',
    ),
    _IndicatorOption(
      'super',
      'SUPER',
      'builtin.super',
      true,
      'ATR 周期 10 · 倍数 3',
      parameters: {'period': 10, 'multiplier': 3},
    ),
    _IndicatorOption('vol', 'VOL', 'legacy.vol', false, '均量周期 5 / 10'),
    _IndicatorOption(
        'macd', 'MACD', 'legacy.macd', false, '快速 12 · 慢速 26 · 信号 9'),
    _IndicatorOption(
      'kdj',
      'KDJ',
      'legacy.kdj',
      false,
      '周期 14 · 平滑 3 / 3',
      parameters: {'period': 14},
    ),
    _IndicatorOption(
      'rsi',
      'RSI',
      'legacy.rsi',
      false,
      '周期 14',
      parameters: {'period': 14},
    ),
    _IndicatorOption(
      'wr',
      'WR',
      'legacy.wr',
      false,
      '周期 14',
      parameters: {'period': 14},
    ),
    _IndicatorOption(
      'obv',
      'OBV',
      'legacy.obv',
      false,
      '均线周期 30',
      parameters: {'period': 30},
    ),
    _IndicatorOption(
      'atr',
      'ATR',
      'builtin.atr',
      false,
      '周期 14',
      parameters: {'period': 14},
    ),
    _IndicatorOption(
      'cci',
      'CCI',
      'builtin.cci',
      false,
      '周期 20 · 常数 0.015',
      parameters: {'period': 20, 'constant': 0.015},
    ),
    _IndicatorOption(
      'dmi',
      'DMI',
      'builtin.dmi',
      false,
      'DI 周期 14 · ADX 周期 14',
      parameters: {'period': 14, 'adxPeriod': 14},
    ),
    _IndicatorOption(
      'roc',
      'ROC',
      'builtin.roc',
      false,
      '周期 12',
      parameters: {'period': 12},
    ),
    _IndicatorOption(
      'stoch-rsi',
      'Stoch RSI',
      'builtin.stochRsi',
      false,
      'RSI 14 · 随机 14 · K 3 · D 3',
      parameters: {
        'rsiPeriod': 14,
        'stochPeriod': 14,
        'kPeriod': 3,
        'dPeriod': 3,
      },
    ),
  ];

  late final StandardChartRenderPipeline<KChartTheme> _pipeline;
  late final ChartInteractionMachine _interactionMachine;
  late final ChartNavigationMachine _navigationMachine;
  late final BinanceMarketDataClient _marketData;
  late final IndicatorEngine _indicatorEngine;
  Timer? _clockTimer;
  Timer? _marketTimer;
  final _instrumentController = TextEditingController(text: 'BTCUSDT');
  KChartTheme _theme = KChartTheme.light(
    upColor: const Color(0xff0b9b69),
    downColor: const Color(0xffd93d56),
  ).copyWith(
    indicatorColors: const {
      'demo-super:up': Color(0xff0b9b69),
      'demo-super:down': Color(0xffd93d56),
    },
    indicatorLineWidths: const {
      'demo-super:up': 0.8,
      'demo-super:down': 0.8,
    },
    indicatorAreaFillOpacities: const {
      'demo-super:up': 0.1,
      'demo-super:down': 0.1,
    },
    gridStrokeWidth: 0.5,
    dataStrokeWidth: 0.8,
    mainLineStrokeWidth: 1,
    indicatorStrokeWidth: 1,
    overlayStrokeWidth: 0.8,
  );
  final Set<String> _mainIndicators = {'ma'};
  final List<String> _secondaryIndicators = ['vol', 'macd'];

  var _instrumentId = 'BTCUSDT';
  var _interval = KlineInterval.oneMinute;
  var _mode = ChartMainMode.candlestick;
  var _candleLimit = 180;
  var _visibleCandles = 90;
  var _secondaryPanelHeight = 108.0;
  var _mainIndicatorHeaderHeight = 18.0;
  var _secondaryIndicatorHeaderHeight = 18.0;
  var _mainTimeAxisHeight = 18.0;
  var _superLineWidth = 0.8;
  var _superAreaOpacity = 0.1;
  var _timeZoneOffsetMinutes = 8 * 60;
  var _localeRevision = 0;
  var _overlaySecondaryIndicators = false;
  var _showTradeOverlayExamples = true;
  var _revision = 0;
  var _viewportRevision = 0;
  var _selectionRevision = 0;
  var _clockRevision = 0;
  var _overlayRevision = 0;
  final Map<String, double> _tradeOverlayPriceOverrides = {};
  final Set<String> _hiddenTradeOverlayIds = {};
  ChartTradeOverlayHit? _selectedTradeOverlay;
  ChartTradeOverlayInteraction? _lastTradeOverlayInteraction;
  String? _tradeOverlayStatus;
  var _currentTime = DateTime.now().millisecondsSinceEpoch;
  var _scrollOffsetItems = 0.0;
  double? _itemExtent;
  ChartViewport? _latestViewport;
  var _simulatedTick = 0;
  String? _simulationMessage;
  int? _selectedIndex;
  String? _selectedPanelId;
  double? _selectedPrice;
  var _selectedLocalY = 0.0;
  var _loadGeneration = 0;
  var _isLoading = false;
  String? _loadError;
  BinanceTicker? _ticker;
  var _isRefreshingLatest = false;
  String? _realtimeStatus;
  late _DemoData _data;

  @override
  void initState() {
    super.initState();
    if (widget.fullscreen) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
    _pipeline = StandardChartRenderPipeline<KChartTheme>();
    _interactionMachine = ChartInteractionMachine();
    _navigationMachine = ChartNavigationMachine();
    _marketData = BinanceMarketDataClient();
    final registry = IndicatorRegistry();
    registerBuiltInIndicatorDefinitions(registry);
    _indicatorEngine = IndicatorEngine(registry: registry);
    _data = _createData(_interval, _revision);
    if (widget.loadOnStart) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _currentTime = DateTime.now().millisecondsSinceEpoch;
          _clockRevision++;
        });
      });
      _marketTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_refreshLatestCandles());
      });
      _loadCandles();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _marketTimer?.cancel();
    if (widget.fullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
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
      _clearTradeOverlayInteraction();
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
    if (!RegExp(r'^[A-Z0-9]{5,20}$').hasMatch(instrument)) {
      setState(() => _loadError = '请输入 Binance 现货交易对，例如 BTCUSDT。');
      return;
    }
    setState(() {
      _instrumentId = instrument;
      _instrumentController.text = instrument;
      _ticker = null;
      _realtimeStatus = null;
      _clearTradeOverlayInteraction();
    });
    _loadCandles();
  }

  Future<void> _openFullscreenDemo() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => V2TradingChartDemo(
            loadOnStart: widget.loadOnStart,
            fullscreen: true,
          ),
        ),
      );

  Future<BinanceTicker?> _loadTickerSafely(String instrumentId) async {
    try {
      return await _marketData.ticker(symbol: instrumentId);
    } on Object {
      // A ticker failure must never hide valid candles. The summary falls back
      // to the loaded K-line range until the next successful refresh.
      return null;
    }
  }

  Future<void> _loadCandles() async {
    final generation = ++_loadGeneration;
    final instrumentId = _instrumentId;
    final tickerFuture = _loadTickerSafely(instrumentId);
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final candles = await _marketData.candles(
        symbol: instrumentId,
        interval: _interval,
        limit: _candleLimit,
      );
      final ticker = await tickerFuture;
      if (!mounted || generation != _loadGeneration) return;
      final oldCandles = _data.data;
      final oldLatestIndex = oldCandles.isEmpty || candles.isEmpty
          ? -1
          : candles.indexWhere(
              (candle) => candle.hasSameIdentity(oldCandles.last),
            );
      final preserveViewport = oldLatestIndex >= 0;
      _applyDataWindow(
        candles,
        appendedItemCount:
            preserveViewport ? candles.length - oldLatestIndex - 1 : 0,
        preserveViewport: preserveViewport,
        ticker: ticker,
        realtimeStatus: 'Binance 历史数据已加载 · ${candles.length} 根 K 线',
      );
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loadError = '$error');
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Polls the two newest Binance candles. The most recent entry is normally
  /// still forming, so it replaces the existing last candle every two seconds;
  /// when its open time advances, the window appends the new candle instead.
  Future<void> _refreshLatestCandles() async {
    if (_isLoading || _isRefreshingLatest || _data.data.isEmpty) return;
    _isRefreshingLatest = true;
    final generation = _loadGeneration;
    final instrumentId = _instrumentId;
    final interval = _interval;
    try {
      final tickerFuture = _loadTickerSafely(instrumentId);
      final recent = await _marketData.candles(
        symbol: instrumentId,
        interval: interval,
        limit: 2,
      );
      final ticker = await tickerFuture;
      if (!mounted ||
          generation != _loadGeneration ||
          instrumentId != _instrumentId ||
          interval != _interval) {
        return;
      }
      final merged = mergeLatestBinanceCandles(
        existing: _data.data,
        updates: recent,
        maxLength: _candleLimit,
      );
      final status = merged.changed
          ? 'Binance 实时更新 · 替换 ${merged.replacedCount} 根 · '
              '新增 ${merged.appendedCount} 根'
          : 'Binance 实时已同步 · 当前 K 线持续更新中';
      if (merged.changed) {
        _applyDataWindow(
          merged.candles,
          appendedItemCount: merged.appendedCount,
          preserveViewport: true,
          ticker: ticker,
          realtimeStatus: status,
        );
      } else {
        setState(() {
          _ticker = ticker ?? _ticker;
          _realtimeStatus = status;
        });
      }
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _realtimeStatus = 'Binance 实时更新失败：$error');
      }
    } finally {
      _isRefreshingLatest = false;
    }
  }

  void _applyDataWindow(
    List<Kline> candles, {
    required int appendedItemCount,
    required bool preserveViewport,
    String? simulationMessage,
    BinanceTicker? ticker,
    String? realtimeStatus,
  }) {
    final previousViewport = _latestViewport;
    final nextViewport = preserveViewport && previousViewport != null
        ? ChartViewportNavigator.preserveAfterRealtimeDataChange(
            previousViewport,
            nextItemCount: candles.length,
            appendedItemCount: appendedItemCount,
          )
        : null;
    setState(() {
      _advanceRevision();
      _data = _DemoData(
        UnmodifiableListView(candles),
        KlineDataVersion(_revision),
      );
      if (nextViewport != null) {
        _scrollOffsetItems = nextViewport.scrollOffsetItems;
        _itemExtent = nextViewport.itemExtent;
        _latestViewport = nextViewport;
      } else if (preserveViewport) {
        if (_scrollOffsetItems != 0) {
          _scrollOffsetItems += appendedItemCount;
        }
      } else {
        _scrollOffsetItems = 0;
        _itemExtent = null;
        _latestViewport = null;
        _clearTradeOverlayInteraction();
      }
      _simulationMessage = simulationMessage;
      _ticker = ticker ?? _ticker;
      _realtimeStatus = realtimeStatus ?? _realtimeStatus;
      _viewportRevision++;
      _clearSelection();
    });
  }

  void _simulateUpdateLatest() {
    if (_data.data.isEmpty) return;
    final candles = _data.data.toList(growable: true);
    final latest = candles.last;
    _simulatedTick++;
    final delta = math.max(latest.close.abs() * .001, .01);
    final direction = _simulatedTick.isEven ? -1.0 : 1.0;
    final close = math.max(0.0, latest.close + direction * delta);
    candles[candles.length - 1] = latest.copyWith(
      high: math.max(latest.high, math.max(latest.open, close) + delta * .4),
      low: math.min(
          latest.low, math.max(0, math.min(latest.open, close) - delta * .4)),
      close: close,
      baseVolume: latest.baseVolume + 12 + _simulatedTick,
      quoteVolume: latest.quoteVolume + (12 + _simulatedTick) * close,
      tradeCount: latest.tradeCount + 1,
      isClosed: false,
    );
    _applyDataWindow(
      candles,
      appendedItemCount: 0,
      preserveViewport: true,
      simulationMessage: '已模拟更新最新 K 线（视口保持不动）',
    );
  }

  void _simulateAppendLatest() {
    if (_data.data.isEmpty) return;
    final candles = _data.data.toList(growable: true);
    final latest = candles.last;
    final observedStep = candles.length < 2
        ? 0
        : latest.openTime - candles[candles.length - 2].openTime;
    final step = observedStep > 0
        ? observedStep
        : (_interval.duration?.inMilliseconds ?? 60000);
    _simulatedTick++;
    final delta = math.max(latest.close.abs() * .001, .01);
    final direction = _simulatedTick.isEven ? -1.0 : 1.0;
    final open = latest.close;
    final close = math.max(0.0, open + direction * delta);
    candles[candles.length - 1] = latest.copyWith(isClosed: true);
    candles.add(
      Kline(
        symbol: latest.symbol,
        interval: latest.interval,
        openTime: latest.openTime + step,
        closeTime: latest.openTime + step * 2 - 1,
        open: open,
        high: math.max(open, close) + delta * .7,
        low: math.max(0, math.min(open, close) - delta * .7),
        close: close,
        baseVolume: 15 + _simulatedTick.toDouble(),
        quoteVolume: (15 + _simulatedTick) * close,
        tradeCount: 1,
        isClosed: false,
        timeZoneOffset: latest.timeZoneOffset,
        priceSource: latest.priceSource,
      ),
    );
    _applyDataWindow(
      candles,
      appendedItemCount: 1,
      preserveViewport: true,
      simulationMessage: '已模拟新增 K 线（非最新视图保持原蜡烛位置）',
    );
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

  void _applySuperStyle() {
    _theme = _theme.copyWith(
      indicatorLineWidths: {
        'demo-super:up': _superLineWidth,
        'demo-super:down': _superLineWidth,
      },
      indicatorAreaFillOpacities: {
        'demo-super:up': _superAreaOpacity,
        'demo-super:down': _superAreaOpacity,
      },
    );
    _advanceRevision();
  }

  double _effectiveMainIndicatorHeaderHeight(double availableWidth) {
    if (_mainIndicatorHeaderHeight == 0) return 0;
    final estimatedLegendWidth = _mainIndicators.fold<double>(
      0,
      (total, id) =>
          total +
          switch (id) {
            'ma' => 380,
            'ema' => 285,
            'boll' => 300,
            'sar' => 120,
            'vwap' => 120,
            'avl' => 110,
            'super' => 190,
            _ => 110,
          },
    );
    final rows = math.max(
      1,
      (estimatedLegendWidth / math.max(1, availableWidth - 16)).ceil(),
    );
    return math.max(_mainIndicatorHeaderHeight, rows * 16.0);
  }

  void _clearSelection() {
    _selectedIndex = null;
    _selectedPanelId = null;
    _selectedPrice = null;
    _selectionRevision++;
  }

  void _clearTradeOverlayInteraction() {
    _tradeOverlayPriceOverrides.clear();
    _hiddenTradeOverlayIds.clear();
    _selectedTradeOverlay = null;
    _lastTradeOverlayInteraction = null;
    _tradeOverlayStatus = null;
    _overlayRevision++;
  }

  DemoTradeOverlaySet _tradeOverlays() {
    if (!_showTradeOverlayExamples) {
      return DemoTradeOverlaySet(priceLines: const []);
    }
    final source = buildDemoTradeOverlays(_data.data);
    return DemoTradeOverlaySet(
      priceLines: [
        for (final line in source.priceLines)
          line.copyWith(
            price: _tradeOverlayPriceOverrides[line.id],
            visible: !_hiddenTradeOverlayIds.contains(line.id),
          ),
      ],
    );
  }

  String _tradeOverlayLabel(String id) => switch (id) {
        'demo-position-long-average' => '多仓均价',
        'demo-position-long-liquidation' => '强平价',
        'demo-order-buy-limit' => '买入挂单',
        'demo-order-long-take-profit' => '止盈',
        'demo-order-long-stop-loss' => '止损',
        _ => id,
      };

  ChartTradeOverlayHit _tradeOverlayHitAtPrice(
    ChartTradeOverlayHit hit,
    double price,
  ) =>
      ChartTradeOverlayHit(
        id: hit.id,
        kind: hit.kind,
        side: hit.side,
        price: price,
        distance: 0,
        epochMilliseconds: hit.epochMilliseconds,
      );

  void _handleTradeOverlayTap(ChartTradeOverlayHit hit) {
    final interaction = ChartTradeOverlayInteraction(
      hit: hit,
      type: ChartTradeOverlayInteractionType.tap,
    );
    setState(() {
      _clearSelection();
      _selectedTradeOverlay = hit;
      _lastTradeOverlayInteraction = interaction;
      _tradeOverlayStatus = '已选中 ${_tradeOverlayLabel(hit.id)}';
    });
  }

  void _handleTradeOverlayDragStart(
    ChartTradeOverlayHit hit,
    Offset localPosition,
  ) {
    final interaction = ChartTradeOverlayInteraction(
      hit: hit,
      type: ChartTradeOverlayInteractionType.dragStart,
    );
    setState(() {
      _clearSelection();
      _selectedTradeOverlay = hit;
      _lastTradeOverlayInteraction = interaction;
      _tradeOverlayStatus = '开始调整 ${_tradeOverlayLabel(hit.id)}';
    });
  }

  void _handleTradeOverlayDragUpdate(
    ChartTradeOverlayHit hit,
    Offset localPosition,
    RenderSnapshot<KChartTheme> snapshot,
  ) {
    final panel = snapshot.layout.mainPanel.bounds;
    final localY = localPosition.dy.clamp(panel.top, panel.bottom).toDouble();
    final price = ChartLayerGeometry.rangeFor(snapshot, 'main')
        .transform(panel)
        .localYToPrice(localY);
    final updatedHit = _tradeOverlayHitAtPrice(hit, price);
    final interaction = ChartTradeOverlayInteraction(
      hit: updatedHit,
      type: ChartTradeOverlayInteractionType.dragUpdate,
      price: price,
    );
    setState(() {
      _tradeOverlayPriceOverrides[hit.id] = price;
      _selectedTradeOverlay = updatedHit;
      _lastTradeOverlayInteraction = interaction;
      _tradeOverlayStatus =
          '正在调整 ${_tradeOverlayLabel(hit.id)}：${_theme.formatMainValue(price)}';
      _overlayRevision++;
    });
  }

  void _handleTradeOverlayDragEnd(ChartTradeOverlayHit hit) {
    final price = _tradeOverlayPriceOverrides[hit.id] ?? hit.price;
    final updatedHit = _tradeOverlayHitAtPrice(hit, price);
    final interaction = ChartTradeOverlayInteraction(
      hit: updatedHit,
      type: ChartTradeOverlayInteractionType.dragEnd,
      price: price,
    );
    setState(() {
      _selectedTradeOverlay = updatedHit;
      _lastTradeOverlayInteraction = interaction;
      _tradeOverlayStatus =
          '已调整 ${_tradeOverlayLabel(hit.id)}：${_theme.formatMainValue(price)}';
    });
  }

  void _cancelTradeOverlayDrag(ChartTradeOverlayHit hit) {
    if (_lastTradeOverlayInteraction?.type !=
        ChartTradeOverlayInteractionType.dragUpdate) {
      return;
    }
    setState(() => _tradeOverlayStatus = '调整已中断');
  }

  void _cancelSelectedTradeOverlay() {
    final hit = _selectedTradeOverlay;
    if (hit == null) return;
    final interaction = ChartTradeOverlayInteraction(
      hit: hit,
      type: ChartTradeOverlayInteractionType.action,
      actionId: 'cancel',
    );
    setState(() {
      _hiddenTradeOverlayIds.add(hit.id);
      _selectedTradeOverlay = null;
      _lastTradeOverlayInteraction = interaction;
      _tradeOverlayStatus = '已取消 ${_tradeOverlayLabel(hit.id)}';
      _overlayRevision++;
    });
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
          _selectedTradeOverlay = null;
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

  void _returnToLatest(ChartViewport viewport) {
    _navigationMachine.cancelInertia();
    final latest = ChartViewportNavigator.toLatest(viewport);
    setState(() {
      _scrollOffsetItems = latest.scrollOffsetItems;
      _itemExtent = latest.itemExtent;
      _latestViewport = latest;
      _viewportRevision++;
      _clearSelection();
      _selectedTradeOverlay = null;
    });
  }

  void _semanticZoom(
    ChartViewport viewport,
    RenderSnapshot<KChartTheme> snapshot, {
    required double scale,
  }) {
    if (!_interactionMachine.beginScale(
      viewport: viewport,
      focalLocalX: viewport.width / 2,
    )) {
      return;
    }
    final intent = _interactionMachine.updateScale(
      scale: scale,
      focalLocalX: viewport.width / 2,
    );
    _interactionMachine.endScale();
    if (intent != null) _handleChartIntent(intent, snapshot);
  }

  String _chartSemanticValue(Kline? selectedCandle) {
    if (_data.data.isEmpty) return '暂无行情数据';
    final candle = selectedCandle ?? _data.data.last;
    final prefix = selectedCandle == null ? '最新' : '已选中';
    final offset = Duration(minutes: _timeZoneOffsetMinutes);
    return '$prefix ${_formatCrosshairSelectionTime(candle, offset)}，'
        '开 ${_theme.formatMainValue(candle.open)}，'
        '高 ${_theme.formatMainValue(candle.high)}，'
        '低 ${_theme.formatMainValue(candle.low)}，'
        '收 ${_theme.formatMainValue(candle.close)}';
  }

  void _selectChartPosition(
    Offset localPosition,
    RenderSnapshot<KChartTheme> snapshot,
  ) {
    if (snapshot.data.data.isEmpty) return;
    ChartPanelLayout? selectedPanel;
    for (final panel in snapshot.layout.panels) {
      if (panel.bounds.contains(
        x: localPosition.dx,
        y: localPosition.dy,
      )) {
        selectedPanel = panel;
        break;
      }
    }
    if (selectedPanel == null) return;
    final panelBounds = selectedPanel.bounds;
    final index = ChartXTransform(
      viewport: snapshot.viewport,
      data: snapshot.data,
    ).localXToNearestIndex(localPosition.dx - panelBounds.left);
    final panelId = selectedPanel.spec.id;
    final price = ChartLayerGeometry.rangeFor(snapshot, panelId)
        .transform(panelBounds)
        .localYToPrice(localPosition.dy);
    setState(() {
      _selectedTradeOverlay = null;
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
        ).indexToLocalX(index) +
        bounds.left;
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
          parameters: option.parameters,
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

  int _indicatorLegendIndex(ChartViewport viewport) {
    final selected = _selectedIndex;
    if (selected != null && selected < _data.data.length) {
      return selected;
    }
    final visible = viewport.visibleRange;
    return (visible.end - 1).clamp(0, _data.data.length - 1);
  }

  List<_IndicatorLegendEntry> _indicatorLegendEntries(
    RenderSnapshot<KChartTheme> snapshot, {
    required String panelId,
    required int dataIndex,
  }) {
    final entries = <_IndicatorLegendEntry>[];
    for (final indicator in snapshot.indicators) {
      if (indicator.panelId != panelId) continue;
      if (indicator.definitionId ==
          SuperTrendIndicatorDefinition.definitionId) {
        final option = _indicatorOptionForInstance(indicator.instanceId);
        final period = option?.parameters['period'] ?? 10;
        final multiplier = option?.parameters['multiplier'] ?? 3;
        final activeDescriptor = indicator.descriptor.series.firstWhere(
          (descriptor) =>
              indicator.seriesById(descriptor.id)!.values[dataIndex] != null,
          orElse: () => indicator.descriptor.series.first,
        );
        final value =
            indicator.seriesById(activeDescriptor.id)!.values[dataIndex];
        entries.add(
          _IndicatorLegendEntry(
            label:
                'SUPERTREND(${_formatIndicatorParameter(period)},${_formatIndicatorParameter(multiplier)})',
            value: value,
            color: _indicatorLegendColor(
              snapshot,
              indicator: indicator,
              descriptor: activeDescriptor,
              dataIndex: dataIndex,
              value: value,
            ),
            labelColor: snapshot.theme.axisTextColor,
            valueSeparator: ' ',
          ),
        );
        continue;
      }
      for (final descriptor in indicator.descriptor.series) {
        final value = indicator.seriesById(descriptor.id)!.values[dataIndex];
        entries.add(
          _IndicatorLegendEntry(
            label: descriptor.label,
            value: value,
            color: _indicatorLegendColor(
              snapshot,
              indicator: indicator,
              descriptor: descriptor,
              dataIndex: dataIndex,
              value: value,
            ),
          ),
        );
      }
    }
    return entries;
  }

  _IndicatorOption? _indicatorOptionForInstance(String instanceId) {
    for (final option in _indicators) {
      if (instanceId == 'demo-${option.id}') return option;
    }
    return null;
  }

  Color _indicatorLegendColor(
    RenderSnapshot<KChartTheme> snapshot, {
    required RenderIndicatorSnapshot indicator,
    required IndicatorSeriesDescriptor descriptor,
    required int dataIndex,
    required double? value,
  }) {
    final seriesColor =
        _theme.indicatorColor(indicator.instanceId, descriptor.id);
    if (value == null) return seriesColor;
    return switch (descriptor.colorStrategy) {
      IndicatorColorStrategy.series => seriesColor,
      IndicatorColorStrategy.candleDirection =>
        snapshot.data.data[dataIndex].close >=
                snapshot.data.data[dataIndex].open
            ? _theme.upColor
            : _theme.downColor,
      IndicatorColorStrategy.valueSign =>
        value >= 0 ? _theme.upColor : _theme.downColor,
      IndicatorColorStrategy.pricePosition =>
        value <= snapshot.data.data[dataIndex].close
            ? _theme.upColor
            : _theme.downColor,
    };
  }

  List<_TimeAxisLabel> _timeAxisLabels(
    ChartLayoutModel layout,
    ChartViewport viewport,
  ) {
    if (_data.data.isEmpty) return const [];
    final xTransform = ChartXTransform(viewport: viewport, data: _data);
    final gridColumns = _scrollingGridColumnXs(
      layout: layout,
      viewport: viewport,
      xTransform: xTransform,
    );
    final timeZoneOffset = Duration(minutes: _timeZoneOffsetMinutes);
    return [
      for (final chartX in gridColumns)
        _TimeAxisLabel(
          localX: chartX - layout.mainTimeAxisBounds.left,
          text: _formatAxisTime(
            xTransform.localXToTime(chartX - layout.drawingBounds.left),
            timeZoneOffset,
          ),
          horizontalAnchor: chartX <= layout.drawingBounds.left
              ? 0
              : chartX >= layout.drawingBounds.right
                  ? 1
                  : 0.5,
        ),
    ];
  }

  List<double> _scrollingGridColumnXs({
    required ChartLayoutModel layout,
    required ChartViewport viewport,
    required ChartXTransform xTransform,
  }) {
    final stepItems = math.max(
      1,
      (viewport.visibleItemCapacity / layout.gridColumns).round(),
    );
    final firstAnchor =
        (viewport.visibleLeftDataPosition / stepItems).floor() * stepItems;
    final result = <double>[];
    for (var dataPosition = firstAnchor;
        dataPosition <= viewport.visibleRightDataPosition + stepItems;
        dataPosition += stepItems) {
      final x = xTransform.dataPositionToLocalX(dataPosition.toDouble()) +
          layout.drawingBounds.left;
      if (x >= layout.drawingBounds.left && x <= layout.drawingBounds.right) {
        result.add(x);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final mainIndicatorHeaderHeight =
        _effectiveMainIndicatorHeaderHeight(MediaQuery.sizeOf(context).width);
    final secondaryPanels = _secondaryIndicators.isEmpty
        ? const <ChartPanelSpec>[]
        : _overlaySecondaryIndicators
            ? [
                ChartPanelSpec.secondary(
                    id: 'secondary-overlay',
                    minHeight: _secondaryPanelHeight,
                    headerHeight: _secondaryIndicatorHeaderHeight,
                    gridRows: 2)
              ]
            : [
                for (final id in _secondaryIndicators)
                  ChartPanelSpec.secondary(
                    id: _secondaryPanelId(id),
                    minHeight: _secondaryPanelHeight,
                    headerHeight: _secondaryIndicatorHeaderHeight,
                    gridRows: 2,
                  ),
              ];
    final chartHeight = math.max(
      460.0,
      220 +
          mainIndicatorHeaderHeight +
          secondaryPanels.length *
              (_secondaryPanelHeight + _secondaryIndicatorHeaderHeight) +
          _mainTimeAxisHeight +
          16,
    );
    return Scaffold(
      appBar: widget.fullscreen
          ? null
          : AppBar(
              title: const Text('V2 交易图表'),
              backgroundColor: const Color(0xff075985),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  key: const ValueKey('open-fullscreen-demo'),
                  tooltip: '横屏全屏图表',
                  onPressed: _openFullscreenDemo,
                  icon: const Icon(Icons.fullscreen),
                ),
                IconButton(
                  tooltip: '刷新 Binance 行情',
                  onPressed: _isLoading ? null : _loadCandles,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      backgroundColor: const Color(0xfff8fafc),
      floatingActionButton: widget.fullscreen
          ? FloatingActionButton.small(
              key: const ValueKey('close-fullscreen-demo'),
              tooltip: '退出全屏',
              backgroundColor: const Color(0xcc0f172a),
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(Icons.fullscreen_exit),
            )
          : null,
      body: SafeArea(
        child: ListView(
          key: PageStorageKey(
            widget.fullscreen ? 'v2-chart-fullscreen' : 'v2-chart-standard',
          ),
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
            _MarketSummary(
              key: const ValueKey('market-summary'),
              instrumentId: _instrumentId,
              ticker: _ticker,
              candles: _data.data,
              priceFormatter: _theme.formatMainValue,
            ),
            const SizedBox(height: 8),
            Text(
              _isLoading
                  ? '正在加载 Binance 行情…'
                  : _loadError == null
                      ? 'Binance 公共行情 · ${_data.data.length} 根 K 线'
                      : '已使用离线数据 · $_loadError',
              style: const TextStyle(color: Color(0xff475569)),
            ),
            if (_realtimeStatus case final status?)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  status,
                  key: const ValueKey('binance-realtime-status'),
                  style: const TextStyle(
                    color: Color(0xff0369a1),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!widget.fullscreen) ...[
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
                          labelText: 'Binance 现货交易对',
                          hintText: 'BTCUSDT',
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
              if (_mainIndicators.contains('super')) ...[
                const SizedBox(height: 12),
                _ToolbarSection(
                  title: 'SUPER 样式',
                  children: [
                    _SliderSetting(
                      key: const ValueKey('super-line-width-setting'),
                      label: 'SUPER 线宽',
                      value: _superLineWidth,
                      min: 0.4,
                      max: 3,
                      divisions: 26,
                      valueLabel: _superLineWidth.toStringAsFixed(1),
                      onChanged: (value) => setState(() {
                        _superLineWidth = value;
                        _applySuperStyle();
                      }),
                    ),
                    _SliderSetting(
                      key: const ValueKey('super-area-opacity-setting'),
                      label: 'SUPER 区域不透明度',
                      value: _superAreaOpacity,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      valueLabel: _superAreaOpacity.toStringAsFixed(2),
                      onChanged: (value) => setState(() {
                        _superAreaOpacity = value;
                        _applySuperStyle();
                      }),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _ToolbarSection(
                title: '副图指标',
                children: [
                  for (final option
                      in _indicators.where((item) => !item.isMain))
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
                for (var index = 0;
                    index < _secondaryIndicators.length;
                    index++)
                  _PanelOrderRow(
                    label: _indicator(_secondaryIndicators[index]).label,
                    canMoveUp: index > 0,
                    canMoveDown: index < _secondaryIndicators.length - 1,
                    onMoveUp: () => _moveSecondaryIndicator(
                        _secondaryIndicators[index], -1),
                    onMoveDown: () =>
                        _moveSecondaryIndicator(_secondaryIndicators[index], 1),
                  ),
              ],
              const SizedBox(height: 12),
              _SliderSetting(
                key: const ValueKey('visible-candles-setting'),
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
                key: const ValueKey('secondary-panel-height-setting'),
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
              _SliderSetting(
                key: const ValueKey('main-header-height-setting'),
                label: '主图指标参数区域高度',
                value: _mainIndicatorHeaderHeight,
                min: 0,
                max: 40,
                divisions: 20,
                valueLabel: '${_mainIndicatorHeaderHeight.round()} px',
                onChanged: (value) => setState(() {
                  _mainIndicatorHeaderHeight = value;
                  _advanceRevision();
                }),
              ),
              _SliderSetting(
                key: const ValueKey('secondary-header-height-setting'),
                label: '副图指标参数区域高度',
                value: _secondaryIndicatorHeaderHeight,
                min: 0,
                max: 40,
                divisions: 20,
                valueLabel: '${_secondaryIndicatorHeaderHeight.round()} px',
                onChanged: (value) => setState(() {
                  _secondaryIndicatorHeaderHeight = value;
                  _advanceRevision();
                }),
              ),
              _SliderSetting(
                key: const ValueKey('main-time-axis-height-setting'),
                label: '主图与副图之间的时间区域高度',
                value: _mainTimeAxisHeight,
                min: 0,
                max: 40,
                divisions: 20,
                valueLabel: '${_mainTimeAxisHeight.round()} px',
                onChanged: (value) => setState(() {
                  _mainTimeAxisHeight = value;
                  _advanceRevision();
                }),
              ),
              _ToolbarSection(
                title: '时间显示时区',
                children: [
                  DropdownButton<int>(
                    key: const ValueKey('time-zone-offset'),
                    value: _timeZoneOffsetMinutes,
                    items:
                        const [-8 * 60, 0, 5 * 60 + 30, 8 * 60, 9 * 60, 14 * 60]
                            .map(
                              (minutes) => DropdownMenuItem(
                                value: minutes,
                                child: Text(_formatUtcOffset(minutes)),
                              ),
                            )
                            .toList(growable: false),
                    onChanged: (minutes) {
                      if (minutes == null) return;
                      setState(() {
                        _timeZoneOffsetMinutes = minutes;
                        _localeRevision++;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ToolbarSection(
                title: '数值显示格式（主图与副图独立）',
                children: [
                  DropdownButton<int>(
                    key: const ValueKey('main-value-decimals'),
                    value: _theme.mainValueDecimalPlaces,
                    items: List.generate(
                      7,
                      (places) => DropdownMenuItem(
                        value: places,
                        child: Text('主图 $places 位小数'),
                      ),
                    ),
                    onChanged: (places) {
                      if (places == null) return;
                      setState(() {
                        _theme = _theme.copyWith(
                          mainValueDecimalPlaces: places,
                        );
                        _advanceRevision();
                      });
                    },
                  ),
                  FilterChip(
                    key: const ValueKey('main-value-thousands'),
                    label: const Text('主图千分位'),
                    selected: _theme.mainValueUseThousandsSeparator,
                    onSelected: (enabled) => setState(() {
                      _theme = _theme.copyWith(
                        mainValueUseThousandsSeparator: enabled,
                      );
                      _advanceRevision();
                    }),
                  ),
                  DropdownButton<int>(
                    key: const ValueKey('secondary-value-decimals'),
                    value: _theme.secondaryValueDecimalPlaces,
                    items: List.generate(
                      7,
                      (places) => DropdownMenuItem(
                        value: places,
                        child: Text('副图 $places 位小数'),
                      ),
                    ),
                    onChanged: (places) {
                      if (places == null) return;
                      setState(() {
                        _theme = _theme.copyWith(
                          secondaryValueDecimalPlaces: places,
                        );
                        _advanceRevision();
                      });
                    },
                  ),
                  FilterChip(
                    key: const ValueKey('secondary-value-thousands'),
                    label: const Text('副图千分位'),
                    selected: _theme.secondaryValueUseThousandsSeparator,
                    onSelected: (enabled) => setState(() {
                      _theme = _theme.copyWith(
                        secondaryValueUseThousandsSeparator: enabled,
                      );
                      _advanceRevision();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ToolbarSection(
                title: '交易叠加示例',
                children: [
                  FilterChip(
                    key: const ValueKey('trade-overlay-examples'),
                    label: const Text('显示仓位与订单'),
                    selected: _showTradeOverlayExamples,
                    onSelected: (enabled) => setState(() {
                      _showTradeOverlayExamples = enabled;
                      if (!enabled) {
                        _selectedTradeOverlay = null;
                      }
                      _overlayRevision++;
                    }),
                  ),
                  const Text(
                    '多仓均价 · 强平价 · 买入挂单 · 止盈 · 止损',
                    key: ValueKey('trade-overlay-example-labels'),
                    style: TextStyle(
                      color: Color(0xff475569),
                      fontSize: 12,
                    ),
                  ),
                  if (_tradeOverlayStatus case final status?)
                    Text(
                      status,
                      key: const ValueKey('trade-overlay-status'),
                      style: const TextStyle(
                        color: Color(0xff0369a1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _ToolbarSection(
                title: '模拟实时数据（可与 Binance 实时轮询对照）',
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('simulate-update-latest'),
                    onPressed: _simulateUpdateLatest,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('模拟更新最新 K 线'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('simulate-append-latest'),
                    onPressed: _simulateAppendLatest,
                    icon: const Icon(Icons.add_chart, size: 18),
                    label: const Text('模拟新增 K 线'),
                  ),
                ],
              ),
              if (_simulationMessage case final message?) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  key: const ValueKey('simulation-status'),
                  style: const TextStyle(
                    color: Color(0xff0369a1),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.max(1.0, constraints.maxWidth);
                  final resolvedMainIndicatorHeaderHeight =
                      _effectiveMainIndicatorHeaderHeight(width);
                  final layout = ChartLayoutModel(
                    width: width,
                    height: chartHeight,
                    bottomAxisHeight:
                        secondaryPanels.isEmpty ? _mainTimeAxisHeight : 0,
                    mainTimeAxisHeight:
                        secondaryPanels.isEmpty ? 0 : _mainTimeAxisHeight,
                    panelSpacing: _panelSpacing,
                    gridColumns: 2,
                    mainPanel: ChartPanelSpec.main(
                      minHeight: 220,
                      headerHeight: resolvedMainIndicatorHeaderHeight,
                      gridRows: 4,
                    ),
                    secondaryPanels: secondaryPanels,
                  );
                  final itemExtent = _itemExtent ??
                      layout.drawingBounds.width / _visibleCandles;
                  final legacyViewport = LegacyChartViewportMetrics(
                    itemCount: _data.data.length,
                    width: layout.drawingBounds.width,
                    scaleX: itemExtent / ChartViewport.defaultItemExtent,
                    pointWidth: ChartViewport.defaultItemExtent,
                  );
                  final futurePaddingItems = math.max(
                    0.0,
                    layout.drawingBounds.width / itemExtent -
                        legacyViewport.trailingPaddingItems -
                        1,
                  );
                  final viewport = ChartViewport(
                    itemCount: _data.data.length,
                    width: layout.drawingBounds.width,
                    itemExtent: itemExtent,
                    trailingPaddingItems: legacyViewport.trailingPaddingItems,
                    futurePaddingItems: futurePaddingItems,
                    scrollOffsetItems: _scrollOffsetItems,
                  );
                  _latestViewport = viewport;
                  final tradeOverlays = _tradeOverlays();
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
                      overlays: _overlayRevision,
                      clock: _clockRevision,
                      locale: _localeRevision,
                    ),
                    indicators: _indicatorSnapshots(),
                    priceLines: tradeOverlays.priceLines,
                    mainMode: _mode,
                    timeZoneOffset: Duration(minutes: _timeZoneOffsetMinutes),
                    axisTimeFormatter: _formatAxisTime,
                    crosshairTimeFormatter: _formatRendererCrosshairTime,
                    currentTime: _currentTime,
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
                      overlays: _overlayRevision,
                      clock: _clockRevision,
                      locale: _localeRevision,
                    ),
                    indicators: baseSnapshot.indicators,
                    priceLines: tradeOverlays.priceLines,
                    selection: _selectionFor(baseSnapshot),
                    mainMode: _mode,
                    timeZoneOffset: Duration(minutes: _timeZoneOffsetMinutes),
                    axisTimeFormatter: _formatAxisTime,
                    crosshairTimeFormatter: _formatRendererCrosshairTime,
                    currentTime: _currentTime,
                  );
                  final selectedIndex = _selectedIndex;
                  final selectedCandle =
                      selectedIndex != null && selectedIndex < _data.data.length
                          ? _data.data[selectedIndex]
                          : null;
                  final previousSelectedCandle = selectedIndex != null &&
                          selectedIndex > 0 &&
                          selectedIndex - 1 < _data.data.length
                      ? _data.data[selectedIndex - 1]
                      : null;
                  final indicatorLegendIndex = _indicatorLegendIndex(viewport);
                  final latestPriceHitRegion = latestPriceMarkerHitRegionFor(
                    baseSnapshot,
                    _pipeline.cache,
                  );
                  final mainPanelBounds = layout.panel('main').bounds;
                  final detailsOnRight = snapshot.selection.localX <
                      (mainPanelBounds.left + mainPanelBounds.right) / 2;
                  final detailsLeft = detailsOnRight
                      ? mainPanelBounds.right -
                          _CrosshairDetails.width -
                          _CrosshairDetails.horizontalInset
                      : mainPanelBounds.left +
                          _CrosshairDetails.horizontalInset;
                  return ChartGestureRegion(
                    machine: _interactionMachine,
                    navigationMachine: _navigationMachine,
                    viewport: () => viewport,
                    onIntent: (intent) =>
                        _handleChartIntent(intent, baseSnapshot),
                    onTapUp: (localPosition) =>
                        _selectChartPosition(localPosition, baseSnapshot),
                    semantics: ChartSemanticsConfiguration(
                      label: 'V2 图表 ${_interval.code} ${_modeLabel(_mode)}',
                      value: _chartSemanticValue(selectedCandle),
                      hint: '上调或下调操作可缩放图表；浏览历史时可点击返回最新 K 线',
                      textDirection: Directionality.of(context),
                      liveRegion: selectedCandle != null,
                      onTap: viewport.isAtLatest
                          ? null
                          : () => _returnToLatest(viewport),
                      onIncrease: () => _semanticZoom(
                        viewport,
                        baseSnapshot,
                        scale: 1.25,
                      ),
                      onDecrease: () => _semanticZoom(
                        viewport,
                        baseSnapshot,
                        scale: 0.8,
                      ),
                      increasedValue: '图表已放大',
                      decreasedValue: '图表已缩小',
                    ),
                    tradeOverlayGestures: ChartTradeOverlayGestureCallbacks(
                      hitTest: (localPosition) =>
                          ChartTradeOverlayHitTester.hitTest(
                        snapshot: snapshot,
                        localPosition: localPosition,
                      ),
                      onTap: _handleTradeOverlayTap,
                      onDragStart: _handleTradeOverlayDragStart,
                      onDragUpdate: (hit, localPosition) =>
                          _handleTradeOverlayDragUpdate(
                        hit,
                        localPosition,
                        snapshot,
                      ),
                      onDragEnd: _handleTradeOverlayDragEnd,
                      onDragCancel: _cancelTradeOverlayDrag,
                    ),
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
                        for (final panel in layout.panels)
                          Positioned(
                            key: ValueKey(
                              'panel-indicator-legend-${panel.spec.id}',
                            ),
                            left: panel.headerBounds.left + 8,
                            width: math.max(
                              0,
                              panel.headerBounds.width - 16,
                            ),
                            top: panel.headerBounds.top,
                            height: panel.headerBounds.height,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _PanelIndicatorLegend(
                                  entries: _indicatorLegendEntries(
                                    snapshot,
                                    panelId: panel.spec.id,
                                    dataIndex: indicatorLegendIndex,
                                  ),
                                  valueFormatter:
                                      panel.spec.kind == ChartPanelKind.main
                                          ? _theme.formatMainValue
                                          : _theme.formatSecondaryValue,
                                ),
                              ),
                            ),
                          ),
                        if (layout.secondaryPanels.isNotEmpty)
                          Positioned(
                            left: layout.mainTimeAxisBounds.left,
                            width: layout.mainTimeAxisBounds.width,
                            top: layout.mainTimeAxisBounds.top,
                            height: layout.mainTimeAxisBounds.height,
                            child: IgnorePointer(
                              child: _IntermediateTimeAxis(
                                labels: _timeAxisLabels(layout, viewport),
                              ),
                            ),
                          ),
                        if (selectedCandle != null &&
                            layout.secondaryPanels.isNotEmpty)
                          Positioned(
                            left: layout.mainTimeAxisBounds.left,
                            width: layout.mainTimeAxisBounds.width,
                            top: layout.mainTimeAxisBounds.top,
                            height: layout.mainTimeAxisBounds.height,
                            child: IgnorePointer(
                              child: _SelectedCrosshairTimeLabel(
                                localX: snapshot.selection.localX -
                                    layout.mainTimeAxisBounds.left,
                                text: _formatCrosshairSelectionTime(
                                  selectedCandle,
                                  Duration(
                                    minutes: _timeZoneOffsetMinutes,
                                  ),
                                ),
                                theme: _theme,
                              ),
                            ),
                          ),
                        if (selectedCandle != null)
                          Positioned(
                            key: const ValueKey(
                              'crosshair-details-position',
                            ),
                            left: detailsLeft,
                            top: mainPanelBounds.top + 8,
                            child: IgnorePointer(
                              child: _CrosshairDetails(
                                candle: selectedCandle,
                                previousCandle: previousSelectedCandle,
                                selectedPrice: _selectedPrice,
                                selectedValueIsMain: _selectedPanelId == 'main',
                                theme: _theme,
                                timeZoneOffset: Duration(
                                  minutes: _timeZoneOffsetMinutes,
                                ),
                              ),
                            ),
                          ),
                        if (_selectedTradeOverlay case final selected?)
                          Positioned(
                            key: const ValueKey(
                              'trade-overlay-actions-position',
                            ),
                            right: 8,
                            top: mainPanelBounds.top + 8,
                            child: Material(
                              key: const ValueKey(
                                'trade-overlay-actions',
                              ),
                              color: const Color(0xee0f172a),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_tradeOverlayLabel(selected.id)}  ${_theme.formatMainValue(selected.price)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextButton(
                                      key: const ValueKey(
                                        'trade-overlay-action-cancel',
                                      ),
                                      onPressed: _cancelSelectedTradeOverlay,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xfffda4af,
                                        ),
                                        minimumSize: const Size(52, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      child: const Text('取消'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (latestPriceHitRegion case final region?
                            when region.showsChevron)
                          Positioned.fromRect(
                            rect: region.bounds,
                            child: Semantics(
                              button: true,
                              label: '返回最新 K 线',
                              child: GestureDetector(
                                key: const ValueKey(
                                  'latest-price-return',
                                ),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _returnToLatest(viewport),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '左右滑动查看历史 · 双指缩放 · 点击或长按查看详情',
              style: TextStyle(
                color: Color(0xff334155),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Binance 公共行情接口无需认证；每 2 秒替换或追加最新 K 线，网络不可用时继续展示本地确定性数据。',
              style: TextStyle(color: Color(0xff475569)),
            ),
            const SizedBox(height: 20),
            V2DepthChartDemo(
              referencePrice: _data.data.isEmpty ? 1 : _data.data.last.close,
              theme: _theme,
              version: _revision,
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

/// Compact, real-data-first 24-hour summary for the trading-chart example.
///
/// Binance ticker values take priority. When the public ticker endpoint is
/// temporarily unavailable, the same fields are derived from the visible
/// candle window so the Demo remains useful offline.
class _MarketSummary extends StatelessWidget {
  const _MarketSummary({
    super.key,
    required this.instrumentId,
    required this.ticker,
    required this.candles,
    required this.priceFormatter,
  });

  final String instrumentId;
  final BinanceTicker? ticker;
  final List<Kline> candles;
  final String Function(double value) priceFormatter;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.shrink();
    final fallbackHigh = candles.fold<double>(
      candles.first.high,
      (value, candle) => math.max(value, candle.high),
    );
    final fallbackLow = candles.fold<double>(
      candles.first.low,
      (value, candle) => math.min(value, candle.low),
    );
    final fallbackBaseVolume = candles.fold<double>(
      0,
      (value, candle) => value + candle.baseVolume,
    );
    final fallbackQuoteVolume = candles.fold<double>(
      0,
      (value, candle) => value + candle.quoteVolume,
    );
    final source = ticker;
    final latest = source?.last ?? candles.last.close;
    final opening = source?.open24h ?? candles.first.open;
    final high = source?.high24h ?? fallbackHigh;
    final low = source?.low24h ?? fallbackLow;
    final baseVolume = source?.baseVolume24h ?? fallbackBaseVolume;
    final quoteVolume = source?.quoteVolume24h ?? fallbackQuoteVolume;
    final change = latest - opening;
    final changePercent = opening == 0 ? 0 : change / opening * 100;
    final positive = change >= 0;
    final changeColor =
        positive ? const Color(0xff059669) : const Color(0xffdc2626);
    final quote = _binanceQuoteAsset(instrumentId);

    return Semantics(
      label: '24 小时行情摘要',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffe2e8f0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceFormatter(latest),
                  key: const ValueKey('market-summary-last-price'),
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${positive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  source == null ? 'K 线估算' : 'Binance 24h',
                  style:
                      const TextStyle(color: Color(0xff64748b), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _MarketSummaryMetric('24h 涨跌',
                    '${positive ? '+' : ''}${priceFormatter(change)}'),
                _MarketSummaryMetric('24h 最高', priceFormatter(high)),
                _MarketSummaryMetric('24h 最低', priceFormatter(low)),
                _MarketSummaryMetric('成交量', _compactMarketValue(baseVolume)),
                _MarketSummaryMetric(
                    '成交额', '${_compactMarketValue(quoteVolume)} $quote'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketSummaryMetric extends StatelessWidget {
  const _MarketSummaryMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xff0f172a),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

String _compactMarketValue(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (absolute >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (absolute >= 1000) {
    return '${(value / 1000).toStringAsFixed(2)}K';
  }
  return value.toStringAsFixed(2);
}

String _binanceQuoteAsset(String symbol) {
  const knownQuotes = [
    'USDT',
    'USDC',
    'FDUSD',
    'BUSD',
    'BTC',
    'ETH',
    'BNB',
    'EUR',
    'TRY',
  ];
  return knownQuotes.firstWhere(
    symbol.endsWith,
    orElse: () => symbol.length > 3 ? symbol.substring(symbol.length - 3) : '',
  );
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting(
      {super.key,
      required this.label,
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

class _PanelIndicatorLegend extends StatelessWidget {
  const _PanelIndicatorLegend({
    required this.entries,
    required this.valueFormatter,
  });

  final List<_IndicatorLegendEntry> entries;
  final String Function(double value) valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in entries)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${entry.label}${entry.valueSeparator}',
                  style: TextStyle(
                    color: entry.labelColor ?? entry.color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text:
                      entry.value == null ? '--' : valueFormatter(entry.value!),
                  style: TextStyle(
                    color: entry.color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

final class _IndicatorLegendEntry {
  const _IndicatorLegendEntry({
    required this.label,
    required this.value,
    required this.color,
    this.labelColor,
    this.valueSeparator = ': ',
  });

  final String label;
  final double? value;
  final Color color;
  final Color? labelColor;
  final String valueSeparator;
}

class _IntermediateTimeAxis extends StatelessWidget {
  const _IntermediateTimeAxis({required this.labels});

  final List<_TimeAxisLabel> labels;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (final label in labels)
            Positioned(
              left: label.localX,
              top: 0,
              bottom: 0,
              child: FractionalTranslation(
                translation: Offset(-label.horizontalAnchor, 0),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    label.text,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xff60738e),
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _SelectedCrosshairTimeLabel extends StatelessWidget {
  const _SelectedCrosshairTimeLabel({
    required this.localX,
    required this.text,
    required this.theme,
  });

  final double localX;
  final String text;
  final KChartTheme theme;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final textStyle = TextStyle(
            color: theme.crosshairLabelTextColor,
            fontSize: theme.axisFontSize,
          );
          final painter = TextPainter(
            text: TextSpan(text: text, style: textStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final labelWidth =
              painter.width + theme.crosshairLabelHorizontalPadding * 2;
          final maxLeft = math.max(0, constraints.maxWidth - labelWidth);
          final left = (localX - labelWidth / 2).clamp(0, maxLeft).toDouble();
          return Stack(
            children: [
              Positioned(
                left: left,
                top: 0,
                bottom: 0,
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Container(
                    key: const ValueKey('crosshair-time-label'),
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.crosshairLabelHorizontalPadding,
                      vertical: theme.crosshairLabelVerticalPadding,
                    ),
                    color: theme.crosshairLabelBackgroundColor,
                    child: Text(text, maxLines: 1, style: textStyle),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

final class _TimeAxisLabel {
  const _TimeAxisLabel({
    required this.localX,
    required this.text,
    required this.horizontalAnchor,
  });

  final double localX;
  final String text;
  final double horizontalAnchor;
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
  static const width = 144.0;
  static const horizontalInset = 8.0;

  const _CrosshairDetails({
    required this.candle,
    required this.previousCandle,
    required this.selectedPrice,
    required this.selectedValueIsMain,
    required this.theme,
    required this.timeZoneOffset,
  });

  final Kline candle;
  final Kline? previousCandle;
  final double? selectedPrice;
  final bool selectedValueIsMain;
  final KChartTheme theme;
  final Duration timeZoneOffset;

  @override
  Widget build(BuildContext context) {
    final referenceClose = previousCandle?.close ?? candle.open;
    final change = candle.close - referenceClose;
    final changePercent =
        referenceClose == 0 ? 0.0 : change / referenceClose * 100;
    final amplitude = referenceClose == 0
        ? 0.0
        : (candle.high - candle.low) / referenceClose * 100;
    final changeColor = change >= 0 ? theme.upColor : theme.downColor;
    final selectedValue = selectedPrice == null
        ? null
        : selectedValueIsMain
            ? theme.formatMainValue(selectedPrice!)
            : theme.formatSecondaryValue(selectedPrice!);
    return Container(
      key: const ValueKey('crosshair-details'),
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: theme.crosshairDetailBackgroundColor,
        border: Border.all(color: theme.crosshairDetailBorderColor),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Color(0x1f0f172a), blurRadius: 8),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: theme.crosshairDetailTextColor,
          fontSize: 11,
          height: 1.42,
        ),
        child: Column(
          children: [
            _DetailRow('时间', _formatDetailTime(candle, timeZoneOffset)),
            _DetailRow('开', theme.formatMainValue(candle.open)),
            _DetailRow('高', theme.formatMainValue(candle.high)),
            _DetailRow('低', theme.formatMainValue(candle.low)),
            _DetailRow('收', theme.formatMainValue(candle.close)),
            _DetailRow(
              '涨跌',
              '${change >= 0 ? '+' : ''}${theme.formatMainValue(change)}',
              valueColor: changeColor,
            ),
            _DetailRow(
              '涨跌幅',
              '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
              valueColor: changeColor,
            ),
            _DetailRow('振幅', '${amplitude.toStringAsFixed(2)}%'),
            _DetailRow('量', theme.formatSecondaryValue(candle.baseVolume)),
            _DetailRow('额', theme.formatSecondaryValue(candle.quoteVolume)),
            if (selectedValue != null) _DetailRow('命中值', selectedValue),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 38, child: Text(label)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      );
}

String _formatDetailTime(Kline candle, Duration timeZoneOffset) {
  final time = DateTime.fromMillisecondsSinceEpoch(
    candle.openTime + timeZoneOffset.inMilliseconds,
    isUtc: true,
  );
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  if (candle.interval.code.endsWith('d') ||
      candle.interval.code.endsWith('w') ||
      candle.interval.code.endsWith('M')) {
    return '${twoDigits(time.month)}-${twoDigits(time.day)}';
  }
  return '${twoDigits(time.month)}-${twoDigits(time.day)} '
      '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
}

String _formatCrosshairSelectionTime(
  Kline candle,
  Duration timeZoneOffset,
) =>
    _formatRendererCrosshairTime(
      candle.openTime,
      candle.interval.code,
      timeZoneOffset,
    );

String _formatRendererCrosshairTime(
  int epochMilliseconds,
  String intervalCode,
  Duration timeZoneOffset,
) {
  final time = DateTime.fromMillisecondsSinceEpoch(
    epochMilliseconds + timeZoneOffset.inMilliseconds,
    isUtc: true,
  );
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final date = '${time.year}-${twoDigits(time.month)}-${twoDigits(time.day)}';
  if (intervalCode.endsWith('d') ||
      intervalCode.endsWith('w') ||
      intervalCode.endsWith('M')) {
    return date;
  }
  return '$date ${twoDigits(time.hour)}:${twoDigits(time.minute)}';
}

String _formatUtcOffset(int totalMinutes) {
  if (totalMinutes == 0) return 'UTC';
  final sign = totalMinutes < 0 ? '-' : '+';
  final absoluteMinutes = totalMinutes.abs();
  final hours = absoluteMinutes ~/ Duration.minutesPerHour;
  final minutes = absoluteMinutes % Duration.minutesPerHour;
  return 'UTC$sign${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

String _formatIndicatorParameter(num value) =>
    value.toDouble() == value.toDouble().roundToDouble()
        ? value.toInt().toString()
        : value.toString();

String _formatAxisTime(int epochMilliseconds, Duration timeZoneOffset) {
  final time = DateTime.fromMillisecondsSinceEpoch(
    epochMilliseconds + timeZoneOffset.inMilliseconds,
    isUtc: true,
  );
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${twoDigits(time.month)}-${twoDigits(time.day)} '
      '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
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
        symbol: 'BTCUSDT',
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
  const _IndicatorOption(
    this.id,
    this.label,
    this.definitionId,
    this.isMain,
    this.parameterSummary, {
    this.parameters = const {},
  });

  final String id;
  final String label;
  final String definitionId;
  final bool isMain;
  final String parameterSummary;
  final Map<String, num> parameters;
}

final class _DemoData implements VersionedKlineData {
  const _DemoData(this.data, this.version);
  @override
  final List<Kline> data;
  @override
  final KlineDataVersion version;
}
