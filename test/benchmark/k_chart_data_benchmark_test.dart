// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_data_coordinator.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

const _runBenchmark = bool.fromEnvironment('RUN_KLINE_DATA_BENCHMARK');

void main() {
  test(
    'records 10000 Kline coordinator tail-update host latency',
    () {
      final candles = buildV2KlineFixture(10000);
      final chart = KChartDataCoordinator(
        series: KlineSeries.fromKline(candles.first),
        initialData: candles,
      );
      addTearDown(chart.dispose);
      final samples = <int>[];
      var close = candles.last.close;
      for (var step = 0; step < 105; step++) {
        close += 0.001;
        final last = chart.value.data.data.last;
        final timer = Stopwatch()..start();
        final result = chart.updateKline(
          last.copyWith(close: close),
          session: chart.session,
          allowClosedCorrection: true,
        );
        timer.stop();
        expect(result.changed, isTrue);
        if (step >= 5) samples.add(timer.elapsedMicroseconds);
      }
      samples.sort();
      print(
        jsonEncode({
          'metric': 'coordinator_tail_update_10000_no_indicators',
          'p50_us': _percentile(samples, 0.50),
          'p95_us': _percentile(samples, 0.95),
          'p99_us': _percentile(samples, 0.99),
          'samples': samples.length,
          'data_points': chart.value.data.data.length,
          'environment': 'flutter_test_host_debug',
        }),
      );
    },
    skip: !_runBenchmark,
  );

  test(
    'records 10000 Kline coordinate transform construction latency',
    () {
      final candles = buildV2KlineFixture(10000);
      final chart = KChartDataCoordinator(
        series: KlineSeries.fromKline(candles.first),
        initialData: candles,
      );
      addTearDown(chart.dispose);
      final viewport = ChartViewport(
        itemCount: 10000,
        width: 1000,
        itemExtent: 8,
      );
      final samples = <int>[];
      var positionSum = 0.0;
      for (var step = 0; step < 110; step++) {
        final timer = Stopwatch()..start();
        for (var repeat = 0; repeat < 10; repeat++) {
          positionSum += ChartXTransform(
            viewport: viewport,
            data: chart.value.data,
          ).timeToDataPosition(candles[5000].openTime);
        }
        timer.stop();
        if (step >= 10) samples.add(timer.elapsedMicroseconds);
      }
      samples.sort();
      expect(positionSum, greaterThan(0));
      print(
        jsonEncode({
          'metric': 'coordinate_transform_construct_10000_x10',
          'p50_us': _percentile(samples, 0.50),
          'p95_us': _percentile(samples, 0.95),
          'p99_us': _percentile(samples, 0.99),
          'samples': samples.length,
          'environment': 'flutter_test_host_debug',
        }),
      );
    },
    skip: !_runBenchmark,
  );

  test(
    'records 10000 Kline selected viewport update latency',
    () {
      final candles = buildV2KlineFixture(10000);
      final viewport = ChartViewport(
        itemCount: candles.length,
        width: 800,
        itemExtent: 8,
      );
      final chart = KChartDataCoordinator(
        series: KlineSeries.fromKline(candles.first),
        initialData: candles,
        initialViewport: viewport,
      );
      addTearDown(chart.dispose);
      chart.select(
        openTime: candles[9000].openTime,
        panelId: 'main',
        price: candles[9000].close,
      );
      final samples = <int>[];
      for (var step = 0; step < 110; step++) {
        final timer = Stopwatch()..start();
        for (var repeat = 0; repeat < 10; repeat++) {
          chart.applyViewport(
            viewport.copyWith(
              scrollOffsetItems: (step * 10 + repeat).isEven ? 1 : 2,
            ),
          );
        }
        timer.stop();
        if (step >= 10) samples.add(timer.elapsedMicroseconds);
      }
      expect(chart.value.selectedIndex, 9000);
      samples.sort();
      print(
        jsonEncode({
          'metric': 'selected_viewport_update_10000_x10',
          'p50_us': _percentile(samples, 0.50),
          'p95_us': _percentile(samples, 0.95),
          'p99_us': _percentile(samples, 0.99),
          'samples': samples.length,
          'environment': 'flutter_test_host_debug',
        }),
      );
    },
    skip: !_runBenchmark,
  );
}

int _percentile(List<int> sorted, double percentile) =>
    sorted[((sorted.length - 1) * percentile).ceil()];
