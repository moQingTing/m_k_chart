// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';

import '../support/v2_kline_fixture.dart';

const _runBenchmark =
    bool.fromEnvironment('RUN_ADDITIONAL_INDICATOR_BENCHMARK');

void main() {
  test(
    'records six additional indicators with 10000 Klines',
    () {
      final registry = IndicatorRegistry();
      registerAdditionalIndicatorDefinitions(registry);
      final configs = _configs();
      final store = KlineStore()..replace(buildV2KlineFixture(10000));

      final fullSamples = _samples(20, () {
        for (final config in configs) {
          registry.calculate(store.snapshot, config);
        }
      });
      _metric('six_additional_indicators_full_10000', fullSamples);

      final cache = IndicatorCache(registry);
      for (final config in configs) {
        cache.resolve(store.snapshot, config);
      }
      var close = store.snapshot.lastOrNull!.close;
      final updateSamples = _samples(50, () {
        close += 0.001;
        final last = store.snapshot.lastOrNull!;
        store.update(last.copyWith(close: close));
        for (final config in configs) {
          cache.resolve(store.snapshot, config);
        }
      });
      _metric('six_additional_indicators_last_update_10000', updateSamples);
      for (final config in configs) {
        final singleStore = KlineStore()
          ..replace(buildV2KlineFixture(10000, startIndex: 20000));
        final singleCache = IndicatorCache(registry);
        singleCache.resolve(singleStore.snapshot, config);
        var singleClose = singleStore.snapshot.lastOrNull!.close;
        final singleSamples = _samples(50, () {
          singleClose += 0.001;
          final last = singleStore.snapshot.lastOrNull!;
          singleStore.update(last.copyWith(close: singleClose));
          singleCache.resolve(singleStore.snapshot, config);
        });
        _metric('${config.instanceId}_last_update_10000', singleSamples);
        expect(
          _percentile(singleSamples, 0.95),
          lessThanOrEqualTo(8000),
          reason: '${config.instanceId} update must remain within 8 ms.',
        );
      }
      expect(
        _percentile(updateSamples, 0.95),
        lessThanOrEqualTo(8000),
        reason: 'Combined six-indicator update must remain within 8 ms.',
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

List<IndicatorConfig> _configs() => [
      IndicatorConfig(
        instanceId: 'vwap',
        definitionId: VwapIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'atr',
        definitionId: AtrIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'cci',
        definitionId: CciIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'dmi',
        definitionId: DmiIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'roc',
        definitionId: RocIndicatorDefinition.definitionId,
      ),
      IndicatorConfig(
        instanceId: 'stoch_rsi',
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
