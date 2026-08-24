import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';

import '../support/kline_fixture.dart';

const _runBenchmark = bool.fromEnvironment('RUN_KLINE_BENCHMARK');

void main() {
  test(
    'records full and incremental indicator calculation timings',
    () {
      final style = _createStyle();

      for (final count in [100, 2000, 10000]) {
        final samples = <int>[];
        for (var iteration = 0; iteration < 6; iteration++) {
          final data = buildKlineFixture(count);
          final stopwatch = Stopwatch()..start();
          _calculate(data, style);
          stopwatch.stop();
          if (iteration > 0) {
            samples.add(stopwatch.elapsedMicroseconds);
          }
        }
        _printMetric(
          'full_indicator_calculation',
          _median(samples),
          {'count': count, 'unit': 'microseconds'},
        );
      }

      final liveData = buildKlineFixture(10000);
      _calculate(liveData, style);
      final updateSamples = <int>[];
      for (var iteration = 0; iteration < 100; iteration++) {
        liveData.last.close += iteration.isEven ? 0.01 : -0.01;
        final stopwatch = Stopwatch()..start();
        DataUtil.updateLastData(
          liveData,
          obvPeriod: style.obvPeriod,
          emaConfigs: style.emaConfigs,
          chartStyle: style,
        );
        stopwatch.stop();
        updateSamples.add(stopwatch.elapsedMicroseconds);
      }
      _printMetric(
        'incremental_last_kline_update',
        _median(updateSamples),
        {'count': liveData.length, 'unit': 'microseconds'},
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'records drag repaint timings for the current widget',
    (tester) async {
      final data = buildKlineFixture(2000);
      final style = _createStyle();
      _calculate(data, style);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 390,
              height: 600,
              child: KChartWidget(
                data,
                mainState: MainState.ma,
                secondaryStates: const [
                  SecondaryState.macd,
                  SecondaryState.vol,
                ],
                chartStyle: style,
                chartColors: ChartColors(
                  isDarkMode: true,
                  upColor: Colors.green,
                  downColor: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(220, 300));
      final samples = <int>[];
      for (var iteration = 0; iteration < 60; iteration++) {
        final stopwatch = Stopwatch()..start();
        await gesture.moveBy(const Offset(-3, 0));
        await tester.pump(const Duration(milliseconds: 16));
        stopwatch.stop();
        if (iteration >= 10) {
          samples.add(stopwatch.elapsedMicroseconds);
        }
      }
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());

      _printMetric(
        'drag_move_and_pump',
        _median(samples),
        {
          'count': data.length,
          'visibleSecondaryPanels': 2,
          'unit': 'microseconds',
          'mode': 'flutter_test_host_debug',
        },
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'records pinch zoom repaint timings for the current widget',
    (tester) async {
      final data = buildKlineFixture(2000);
      final style = _createStyle();
      _calculate(data, style);
      await tester.pumpWidget(
        _buildBenchmarkWidget(data, style, compactInfoWindow: true),
      );
      await tester.pump();

      final first = await tester.createGesture(pointer: 1);
      final second = await tester.createGesture(pointer: 2);
      await first.down(const Offset(180, 300));
      await second.down(const Offset(220, 300));
      await tester.pump();

      final samples = <int>[];
      for (var iteration = 0; iteration < 50; iteration++) {
        final distance = iteration.isEven ? 12.0 : 4.0;
        final stopwatch = Stopwatch()..start();
        await first.moveTo(Offset(180 - distance, 300));
        await second.moveTo(Offset(220 + distance, 300));
        final repaintScheduled = tester.binding.hasScheduledFrame;
        await tester.pump(const Duration(milliseconds: 16));
        stopwatch.stop();
        if (iteration >= 10 && repaintScheduled) {
          samples.add(stopwatch.elapsedMicroseconds);
        }
      }
      await first.up();
      await second.up();
      await tester.pumpWidget(const SizedBox.shrink());

      _printMetric(
        'pinch_zoom_move_and_pump',
        _median(samples),
        {
          'count': data.length,
          'sampleCount': samples.length,
          'visibleSecondaryPanels': 2,
          'unit': 'microseconds',
          'mode': 'flutter_test_host_debug',
        },
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'records crosshair repaint timings for the current widget',
    (tester) async {
      final data = buildKlineFixture(2000);
      final style = _createStyle();
      _calculate(data, style);
      await tester.pumpWidget(
        _buildBenchmarkWidget(data, style, compactInfoWindow: true),
      );
      await tester.pump();

      final gesture = await tester.startGesture(const Offset(220, 300));
      await tester.pump(const Duration(milliseconds: 600));
      final samples = <int>[];
      for (var iteration = 0; iteration < 50; iteration++) {
        final stopwatch = Stopwatch()..start();
        await gesture.moveBy(const Offset(-2, 0));
        await tester.pump(const Duration(milliseconds: 16));
        stopwatch.stop();
        if (iteration >= 10) {
          samples.add(stopwatch.elapsedMicroseconds);
        }
      }
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());

      _printMetric(
        'crosshair_move_and_pump',
        _median(samples),
        {
          'count': data.length,
          'visibleSecondaryPanels': 2,
          'unit': 'microseconds',
          'mode': 'flutter_test_host_debug',
        },
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Widget _buildBenchmarkWidget(
  List<KLineEntity> data,
  ChartStyle style, {
  bool compactInfoWindow = false,
}) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: 390,
        height: 600,
        child: KChartWidget(
          data,
          mainState: MainState.ma,
          secondaryStates: const [
            SecondaryState.macd,
            SecondaryState.vol,
          ],
          chartStyle: style,
          chartColors: ChartColors(
            isDarkMode: true,
            upColor: Colors.green,
            downColor: Colors.red,
          ),
          infoWindowBuilder: compactInfoWindow
              ? (context, entity, chartStyle, chartColors) =>
                    const SizedBox.shrink()
              : null,
        ),
      ),
    ),
  );
}

ChartStyle _createStyle() => ChartStyle()
  ..emaConfigs = [
    EMAConfig(period: 5, color: Colors.yellow),
    EMAConfig(period: 10, color: Colors.pink),
    EMAConfig(period: 30, color: Colors.purple),
  ];

void _calculate(List<KLineEntity> data, ChartStyle style) {
  DataUtil.calculate(
    data,
    obvPeriod: style.obvPeriod,
    emaConfigs: style.emaConfigs,
    chartStyle: style,
  );
}

int _median(List<int> samples) {
  final sorted = [...samples]..sort();
  return sorted[sorted.length ~/ 2];
}

void _printMetric(String name, int value, Map<String, Object> dimensions) {
  // A JSON line is intentionally used so CI can collect and compare results.
  // ignore: avoid_print
  print(
    jsonEncode({
      'benchmark': name,
      'median': value,
      ...dimensions,
    }),
  );
}
