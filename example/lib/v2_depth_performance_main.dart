// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:m_k_chart/k_chart_theme.dart';
import 'package:m_k_chart/v2_example_support.dart';

void main() => runApp(const _DepthPerformanceApp());

class _DepthPerformanceApp extends StatefulWidget {
  const _DepthPerformanceApp();

  @override
  State<_DepthPerformanceApp> createState() => _DepthPerformanceAppState();
}

class _DepthPerformanceAppState extends State<_DepthPerformanceApp> {
  static const _warmupTicks = 20;
  static const _sampleTicks = 100;
  static const _updatesPerSide = 8;

  final _coordinator = DepthRealtimeCoordinator();
  final _curveCache = DepthCurveCache(capacity: 2);
  final _samplingPolicy = DepthCurveSamplingPolicy(
    maxRetainedLevelsPerSide: 1000,
    maxRenderedPointsPerSide: 160,
  );
  final _theme = KChartTheme.light();
  final _buildMicros = <double>[];
  final _rasterMicros = <double>[];
  final _mergeMicros = <double>[];
  final _prepareMicros = <double>[];

  Timer? _timer;
  var _tick = 0;
  var _recording = false;
  var _reported = false;

  @override
  void initState() {
    super.initState();
    final book = _book(1000);
    _coordinator.applySnapshot(
      DepthBookSnapshotEvent(
        symbol: 'BTCUSDT',
        lastUpdateId: 1000,
        bids: book.bids,
        asks: book.asks,
      ),
      generation: _coordinator.generation,
    );
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
    _timer = Timer.periodic(const Duration(milliseconds: 100), _advance);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _advance(Timer timer) {
    _tick++;
    if (_tick == _warmupTicks + 1) {
      _recording = true;
      _buildMicros.clear();
      _rasterMicros.clear();
      _mergeMicros.clear();
      _prepareMicros.clear();
    }
    final localId = _coordinator.state.lastUpdateId!;
    final stopwatch = Stopwatch()..start();
    final result = _coordinator.addDelta(
      _delta(
        book: _coordinator.state.book,
        updateId: localId + 1,
        iteration: _tick,
      ),
      generation: _coordinator.generation,
    );
    stopwatch.stop();
    if (result.outcome != DepthMergeOutcome.deltaApplied) {
      throw StateError('Unexpected depth merge result: ${result.outcome}');
    }
    if (_recording) {
      _mergeMicros.add(stopwatch.elapsedMicroseconds.toDouble());
    }
    setState(() {});
    if (_tick >= _warmupTicks + _sampleTicks) {
      timer.cancel();
      Future<void>.delayed(const Duration(seconds: 1), _report);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_recording || _reported) return;
    for (final timing in timings) {
      _buildMicros.add(
        timing.buildDuration.inMicroseconds.toDouble(),
      );
      _rasterMicros.add(
        timing.rasterDuration.inMicroseconds.toDouble(),
      );
    }
  }

  void _report() {
    if (_reported) return;
    _reported = true;
    final state = _coordinator.state;
    print(
      'v2_depth_profile_result ${jsonEncode({
            'deviceScenario': '1000_bids_1000_asks_10hz',
            'warmupTicks': _warmupTicks,
            'sampleTicks': _sampleTicks,
            'updatesPerSide': _updatesPerSide,
            'renderedPointsPerSide': 160,
            'bookLevelsPerSide': state.book.bids.length,
            'synchronized': state.isSynchronized,
            'build': _summary(_buildMicros),
            'raster': _summary(_rasterMicros),
            'merge': _summary(_mergeMicros),
            'curvePrepare': _summary(_prepareMicros),
            'mode': 'flutter_profile',
          })}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final prepareWatch = Stopwatch()..start();
    final snapshot = DepthRenderSnapshot<KChartTheme>(
      book: _coordinator.state.book,
      theme: _theme,
      layout: DepthChartLayout(
        size: const Size(390, 420),
      ),
      version: _coordinator.state.version.value,
      samplingPolicy: _samplingPolicy,
      curveCache: _curveCache,
    );
    prepareWatch.stop();
    if (_recording && !_reported) {
      _prepareMicros.add(prepareWatch.elapsedMicroseconds.toDouble());
    }
    return MaterialApp(
      home: Scaffold(
        backgroundColor: _theme.backgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'V2 深度 10 Hz Profile 门禁',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  '第 $_tick 次更新 · 1,000 买档 + 1,000 卖档 · '
                  '每侧绘制 ${snapshot.curve.bids.length} 点',
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  size: snapshot.layout.size,
                  painter: _DepthPerformancePainter(snapshot),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepthPerformancePainter extends CustomPainter {
  const _DepthPerformancePainter(this.snapshot);

  final DepthRenderSnapshot<KChartTheme> snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    StandardDepthCurveRenderer.paint(canvas: canvas, snapshot: snapshot);
  }

  @override
  bool shouldRepaint(_DepthPerformancePainter oldDelegate) =>
      snapshot.version != oldDelegate.snapshot.version ||
      snapshot.layout != oldDelegate.snapshot.layout ||
      snapshot.theme != oldDelegate.snapshot.theme;
}

DepthBook _book(int count) => DepthBook(
      bids: List<DepthLevel>.generate(
        count,
        (index) => DepthLevel(
          price: 79999.5 - index * 0.5,
          quantity: 1 + index % 17 * 0.1,
        ),
      ),
      asks: List<DepthLevel>.generate(
        count,
        (index) => DepthLevel(
          price: 80000.5 + index * 0.5,
          quantity: 1 + index % 19 * 0.1,
        ),
      ),
    );

DepthDeltaEvent _delta({
  required DepthBook book,
  required int updateId,
  required int iteration,
}) {
  final bids = <DepthLevelUpdate>[];
  final asks = <DepthLevelUpdate>[];
  for (var offset = 0;
      offset < _DepthPerformanceAppState._updatesPerSide;
      offset++) {
    final bidIndex = (iteration * 17 + offset * 71) % book.bids.length;
    final askIndex = (iteration * 19 + offset * 67) % book.asks.length;
    bids.add(
      DepthLevelUpdate(
        price: book.bids[bidIndex].price,
        quantity: 1 + (iteration + offset) % 23 * 0.13,
      ),
    );
    asks.add(
      DepthLevelUpdate(
        price: book.asks[askIndex].price,
        quantity: 1 + (iteration + offset) % 29 * 0.11,
      ),
    );
  }
  return DepthDeltaEvent(
    symbol: 'BTCUSDT',
    firstUpdateId: updateId,
    finalUpdateId: updateId,
    previousFinalUpdateId: updateId - 1,
    bids: bids,
    asks: asks,
  );
}

Map<String, Object> _summary(List<double> values) {
  if (values.isEmpty) {
    return const {'samples': 0};
  }
  final sorted = List<double>.of(values)..sort();
  double percentile(double value) =>
      sorted[((sorted.length - 1) * value).ceil()];
  return {
    'samples': sorted.length,
    'p50_us': percentile(0.50),
    'p95_us': percentile(0.95),
    'p99_us': percentile(0.99),
  };
}
