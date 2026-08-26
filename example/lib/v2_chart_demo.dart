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
  late final OkxMarketDataClient _marketData;
  late final IndicatorEngine _indicatorEngine;
  final _instrumentController = TextEditingController(text: 'BTC-USDT');
  final KChartTheme _theme = KChartTheme();
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
  var _loadGeneration = 0;
  var _isLoading = false;
  String? _loadError;
  late _DemoData _data;

  @override
  void initState() {
    super.initState();
    _pipeline = StandardChartRenderPipeline<KChartTheme>();
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
      setState(() => _loadError = 'Use an OKX instrument ID, e.g. BTC-USDT.');
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
        title: const Text('V2 Trading Chart'),
        backgroundColor: const Color(0xff0b0e11),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh OKX market data',
            onPressed: _isLoading ? null : _loadCandles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xff0b0e11),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$_instrumentId · ${_interval.code}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _isLoading
                  ? 'Loading OKX market data…'
                  : _loadError == null
                      ? 'OKX public market data · ${_data.data.length} candles'
                      : 'Offline fallback · $_loadError',
              style: const TextStyle(color: Color(0xff848e9c)),
            ),
            const SizedBox(height: 16),
            _ToolbarSection(
              title: 'Instrument & data window',
              children: [
                SizedBox(
                  width: 210,
                  child: TextField(
                    key: const ValueKey('instrument-input'),
                    controller: _instrumentController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'OKX instrument',
                        hintText: 'BTC-USDT',
                        isDense: true),
                    onSubmitted: (_) => _submitInstrument(),
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('load-instrument'),
                  onPressed: _isLoading ? null : _submitInstrument,
                  child: const Text('Load'),
                ),
                DropdownButton<int>(
                  key: const ValueKey('candle-limit'),
                  value: _candleLimit,
                  dropdownColor: const Color(0xff1e2329),
                  items: const [100, 180, 300]
                      .map((limit) => DropdownMenuItem(
                          value: limit, child: Text('$limit candles')))
                      .toList(growable: false),
                  onChanged: (limit) {
                    if (limit != null) _selectCandleLimit(limit);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ToolbarSection(
              title: 'Period',
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
              title: 'Main chart',
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
              title: 'Main overlays',
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
              title: 'Secondary indicators',
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
              title: const Text(
                  'Overlay selected secondary indicators in one panel',
                  style: TextStyle(color: Color(0xffd9dce1))),
              subtitle: const Text(
                  'Turn off for one adjustable panel per indicator.',
                  style: TextStyle(color: Color(0xff848e9c))),
              value: _overlaySecondaryIndicators,
              onChanged: (value) => setState(() {
                _overlaySecondaryIndicators = value;
                _advanceRevision();
              }),
            ),
            if (!_overlaySecondaryIndicators &&
                _secondaryIndicators.length > 1) ...[
              const SizedBox(height: 4),
              const Text('Secondary panel order',
                  style: TextStyle(
                      color: Color(0xffb7bdc6), fontWeight: FontWeight.w600)),
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
              label: 'Visible candles',
              value: _visibleCandles.toDouble(),
              min: 20,
              max: 300,
              divisions: 28,
              valueLabel: '$_visibleCandles',
              onChanged: (value) => setState(() {
                _visibleCandles = value.round();
                _advanceRevision();
              }),
            ),
            _SliderSetting(
              label: 'Secondary panel minimum height',
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
              label: 'V2 chart ${_interval.code} ${_modeLabel(_mode)}',
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
                    final snapshot = RenderSnapshot<KChartTheme>(
                      data: _data,
                      viewport: ChartViewport(
                        itemCount: _data.data.length,
                        width: layout.drawingBounds.width,
                        itemExtent:
                            layout.drawingBounds.width / _visibleCandles,
                      ),
                      layout: layout,
                      theme: _theme,
                      versions: RenderSnapshotVersions(
                        data: _data.version.value,
                        theme: _revision,
                        layout: _revision,
                      ),
                      indicators: _indicatorSnapshots(),
                      mainMode: _mode,
                    );
                    return RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('v2-chart-canvas'),
                        painter: _DemoPainter(
                            pipeline: _pipeline, snapshot: snapshot),
                        size: Size(width, chartHeight),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'OKX requests are public and unauthenticated. If they are not available, the demo keeps rendering deterministic local data.',
              style: TextStyle(color: Color(0xff848e9c)),
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
                  color: Color(0xffb7bdc6), fontWeight: FontWeight.w600)),
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
              style: const TextStyle(color: Color(0xffb7bdc6))),
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
              child: Text(label, style: const TextStyle(color: Colors.white))),
          IconButton(
              tooltip: 'Move $label panel up',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward)),
          IconButton(
              tooltip: 'Move $label panel down',
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.arrow_downward)),
        ],
      );
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
      ChartMainMode.candlestick => 'Candle',
      ChartMainMode.hollowCandlestick => 'Hollow',
      ChartMainMode.ohlc => 'OHLC',
      ChartMainMode.heikinAshi => 'Heikin-Ashi',
      ChartMainMode.line => 'Line',
      ChartMainMode.area => 'Area',
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
