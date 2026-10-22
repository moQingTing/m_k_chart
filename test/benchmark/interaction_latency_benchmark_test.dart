import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

const _runBenchmark = bool.fromEnvironment('RUN_KLINE_BENCHMARK');
const _hostP95BudgetMicroseconds = 1000.0;

void main() {
  test(
    'records interaction state-to-controller host latency',
    () {
      final metrics = <String, _LatencyMetric>{
        'pan_intent_dispatch': _measurePan(),
        'scale_intent_dispatch': _measureScale(),
        'crosshair_intent_dispatch': _measureCrosshair(),
      };

      for (final entry in metrics.entries) {
        final metric = entry.value;
        // This host-state budget is not an input-to-frame or UI/Raster budget.
        expect(metric.p95, lessThanOrEqualTo(_hostP95BudgetMicroseconds));
        // ignore: avoid_print
        print(
          jsonEncode(<String, Object>{
            'metric': entry.key,
            'p50_us': metric.p50,
            'p95_us': metric.p95,
            'p99_us': metric.p99,
            'samples': metric.samples,
            'mode': 'flutter_test_host_debug_state_pipeline',
          }),
        );
      }
    },
    skip: !_runBenchmark,
  );
}

_LatencyMetric _measurePan() => _measure(() {
      final viewport = _viewport();
      final machine = ChartInteractionMachine()..beginPan(viewport);
      final controller = KChartController();
      final intent = machine.updatePan(1)!;
      controller.dispatchInteraction(intent);
      machine.endPan();
      controller.dispose();
    });

_LatencyMetric _measureScale() => _measure(() {
      final viewport = _viewport();
      final machine = ChartInteractionMachine()
        ..beginScale(viewport: viewport, focalLocalX: 195);
      final controller = KChartController();
      final intent = machine.updateScale(scale: 1.01, focalLocalX: 195)!;
      controller.dispatchInteraction(intent);
      machine.endScale();
      controller.dispose();
    });

_LatencyMetric _measureCrosshair() => _measure(() {
      final machine = ChartInteractionMachine();
      final controller = KChartController();
      final intent = machine.beginCrosshair(localX: 195, localY: 240)!;
      controller.dispatchInteraction(intent);
      machine.endCrosshair();
      controller.dispose();
    });

_LatencyMetric _measure(void Function() operation) {
  for (var index = 0; index < 200; index++) {
    operation();
  }
  final samples = <double>[];
  for (var sample = 0; sample < 200; sample++) {
    final stopwatch = Stopwatch()..start();
    for (var iteration = 0; iteration < 100; iteration++) {
      operation();
    }
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / 100);
  }
  samples.sort();
  return _LatencyMetric(
    p50: _percentile(samples, 0.50),
    p95: _percentile(samples, 0.95),
    p99: _percentile(samples, 0.99),
    samples: samples.length,
  );
}

double _percentile(List<double> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}

ChartViewport _viewport() => ChartViewport(
      itemCount: 2000,
      width: 390,
      itemExtent: 8,
      minItemExtent: 4,
      maxItemExtent: 24,
      scrollOffsetItems: 200,
    );

final class _LatencyMetric {
  const _LatencyMetric({
    required this.p50,
    required this.p95,
    required this.p99,
    required this.samples,
  });

  final double p50;
  final double p95;
  final double p99;
  final int samples;
}
