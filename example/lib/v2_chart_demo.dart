import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'package:m_k_chart/v2_example_support.dart';

/// Runnable V2 renderer example with deterministic data and no network setup.
class V2TradingChartDemo extends StatefulWidget {
  const V2TradingChartDemo({super.key});

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

  late final StandardChartRenderPipeline<KChartTheme> _pipeline;
  final KChartTheme _theme = KChartTheme();
  var _interval = KlineInterval.oneMinute;
  var _mode = ChartMainMode.candlestick;
  var _revision = 0;
  late _DemoData _data;

  @override
  void initState() {
    super.initState();
    _pipeline = StandardChartRenderPipeline<KChartTheme>();
    _data = _createData(_interval, _revision);
  }

  @override
  void dispose() {
    _pipeline.dispose();
    super.dispose();
  }

  void _selectInterval(KlineInterval interval) {
    if (interval == _interval) {
      return;
    }
    setState(() {
      _interval = interval;
      _revision++;
      _data = _createData(interval, _revision);
    });
  }

  void _selectMode(ChartMainMode mode) {
    if (mode == _mode) {
      return;
    }
    setState(() {
      _mode = mode;
      // Main mode is a visual semantic change. Until the public V2 controller
      // owns this state, advance the visual version used by retained Layers.
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('V2 Trading Chart'),
          backgroundColor: const Color(0xff0b0e11),
          foregroundColor: Colors.white,
        ),
        backgroundColor: const Color(0xff0b0e11),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'BTCUSDT · ${_interval.code}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
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
                title: 'Chart type',
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
              const SizedBox(height: 16),
              Semantics(
                label: 'V2 chart ${_interval.code} ${_modeLabel(_mode)}',
                child: SizedBox(
                  height: 390,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.max(1.0, constraints.maxWidth);
                      final layout = ChartLayoutModel(
                        width: width,
                        height: 390,
                        leftPadding: 8,
                        rightPadding: 8,
                        bottomAxisHeight: 24,
                        mainPanel: const ChartPanelSpec.main(minHeight: 180),
                      );
                      final snapshot = RenderSnapshot<KChartTheme>(
                        data: _data,
                        viewport: ChartViewport(
                          itemCount: _data.data.length,
                          width: layout.drawingBounds.width,
                          itemExtent: 9,
                        ),
                        layout: layout,
                        theme: _theme,
                        versions: RenderSnapshotVersions(
                          data: _revision,
                          theme: _revision,
                          layout: _revision,
                        ),
                        mainMode: _mode,
                      );
                      return RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey('v2-chart-canvas'),
                          painter: _DemoPainter(
                            pipeline: _pipeline,
                            snapshot: snapshot,
                          ),
                          size: Size(width, 390),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The toolbar uses local deterministic data so each period and '
                'chart mode can be verified offline.',
                style: TextStyle(color: Color(0xff848e9c)),
              ),
            ],
          ),
        ),
      );
}

class _ToolbarSection extends StatelessWidget {
  const _ToolbarSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xffb7bdc6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      );
}

class _DemoPainter extends CustomPainter {
  const _DemoPainter({required this.pipeline, required this.snapshot});

  final StandardChartRenderPipeline<KChartTheme> pipeline;
  final RenderSnapshot<KChartTheme> snapshot;

  @override
  void paint(Canvas canvas, Size size) => pipeline.paint(
        RenderLayerContext(canvas: canvas, snapshot: snapshot),
      );

  @override
  bool shouldRepaint(covariant _DemoPainter oldDelegate) => true;
}

_DemoData _createData(KlineInterval interval, int revision) {
  final step = interval.duration!.inMilliseconds;
  final seed =
      interval.code.codeUnits.fold<int>(0, (sum, value) => sum + value);
  final values = List<Kline>.generate(96, (index) {
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
      isClosed: index != 95,
    );
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

final class _DemoData implements VersionedKlineData {
  const _DemoData(this.data, this.version);

  @override
  final List<Kline> data;
  @override
  final KlineDataVersion version;
}
