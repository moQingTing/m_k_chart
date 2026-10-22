// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';

import '../support/v2_kline_fixture.dart';

const _runBenchmark = bool.fromEnvironment('RUN_INDICATOR_ENGINE_BENCHMARK');
const _memoryBudgetBytes = 35 * 1024 * 1024;

void main() {
  test(
    'records six-instance batch update and RSS with 10000 Klines',
    () {
      final registry = IndicatorRegistry();
      registerBuiltInIndicatorDefinitions(registry);
      final engine = IndicatorEngine(registry: registry);
      final store = KlineStore()..replace(buildV2KlineFixture(10000));
      final configs = _configs();

      final rssBefore = ProcessInfo.currentRss;
      final initial = engine.resolveAll(store.snapshot, configs);
      final rssAfter = ProcessInfo.currentRss;
      final rssDelta = rssAfter - rssBefore;
      expect(initial.isSuccessful, isTrue);
      print(
        jsonEncode({
          'metric': 'six_indicator_instances_rss_delta',
          'bytes': rssDelta,
          'rssBefore': rssBefore,
          'rssAfter': rssAfter,
          'mode': 'flutter_test_host_debug',
        }),
      );

      var close = store.snapshot.lastOrNull!.close;
      final updateSamples = _samples(100, () {
        close += 0.001;
        final last = store.snapshot.lastOrNull!;
        store.update(last.copyWith(close: close));
        final batch = engine.resolveAll(store.snapshot, configs);
        if (batch.hasFailures) {
          throw StateError('Unexpected indicator benchmark failure.');
        }
      });
      _metric('six_indicator_instances_last_update_10000', updateSamples);

      expect(
        _percentile(updateSamples, 0.95),
        lessThanOrEqualTo(8000),
        reason: 'Six-instance batch update must remain within 8 ms.',
      );
      expect(
        rssDelta < 0 ? 0 : rssDelta,
        lessThanOrEqualTo(_memoryBudgetBytes),
        reason: 'Coarse six-instance RSS delta must remain within 35 MiB.',
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

List<IndicatorConfig> _configs() => [
      IndicatorConfig(
        instanceId: 'ma',
        definitionId: MovingAverageIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'macd',
        definitionId: MacdIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'rsi',
        definitionId: RsiIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'volume',
        definitionId: VolumeIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'dmi',
        definitionId: DmiIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'stoch-rsi',
        definitionId: StochRsiIndicatorDefinition.definitionId,
      ),
    ];

List<int> _samples(int count, void Function() operation) {
  final samples = <int>[];
  for (var iteration = 0; iteration < count + 5; iteration++) {
    final stopwatch = Stopwatch()..start();
    operation();
    stopwatch.stop();
    if (iteration >= 5) {
      samples.add(stopwatch.elapsedMicroseconds);
    }
  }
  return samples;
}

void _metric(String name, List<int> samples) {
  print(
    jsonEncode({
      'metric': name,
      'sampleCount': samples.length,
      'p50': _percentile(samples, 0.50),
      'p95': _percentile(samples, 0.95),
      'p99': _percentile(samples, 0.99),
      'unit': 'microseconds',
      'mode': 'flutter_test_host_debug',
    }),
  );
}

int _percentile(List<int> samples, double percentile) {
  final sorted = List<int>.of(samples)..sort();
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}
