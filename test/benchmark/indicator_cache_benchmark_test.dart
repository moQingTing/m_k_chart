// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/indicator/indicator.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

const _runBenchmark = bool.fromEnvironment('RUN_INDICATOR_CACHE_BENCHMARK');

void main() {
  test(
    'records 10000 Kline indicator cache and last-update timings',
    () {
      final registry = IndicatorRegistry()..register(_CloseIndicator());
      final cache = IndicatorCache(registry);
      final store = KlineStore()..replace(buildV2KlineFixture(10000));
      final config = IndicatorConfig(
        instanceId: 'close-primary',
        definitionId: 'benchmark.close',
      );

      final fullSamples = _samples(30, () {
        IndicatorCache(registry).resolve(store.snapshot, config);
      });
      _metric('indicator_full_10000', fullSamples);

      cache.resolve(store.snapshot, config);
      var close = store.snapshot.lastOrNull!.close;
      final updateSamples = _samples(100, () {
        close += 0.001;
        final last = store.snapshot.lastOrNull!;
        store.update(last.copyWith(close: close));
        cache.resolve(store.snapshot, config);
      });
      _metric('indicator_incremental_last_of_10000', updateSamples);

      final hitSamples = _samples(100, () {
        cache.resolve(store.snapshot, config);
      });
      _metric('indicator_exact_cache_hit_10000', hitSamples);

      final rssBefore = ProcessInfo.currentRss;
      for (var index = 0; index < 6; index++) {
        cache.resolve(
          store.snapshot,
          IndicatorConfig(
            instanceId: 'close-$index',
            definitionId: 'benchmark.close',
          ),
        );
      }
      final rssAfter = ProcessInfo.currentRss;
      print(
        jsonEncode({
          'metric': 'six_single_series_indicators_rss_delta',
          'bytes': rssAfter - rssBefore,
          'rssBefore': rssBefore,
          'rssAfter': rssAfter,
          'mode': 'flutter_test_host_debug',
        }),
      );

      expect(
        _percentile(updateSamples, 0.95),
        lessThanOrEqualTo(8000),
        reason: 'Last Kline indicator update P95 must remain within 8 ms.',
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

final class _CloseIndicator implements IncrementalIndicatorDefinition {
  @override
  String get id => 'benchmark.close';

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.mainChart,
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: 'Close',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) =>
      _result(input, config, input.data.map((item) => item.close));

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      change.kind == IndicatorChangeKind.append ||
      change.kind == IndicatorChangeKind.update;

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final values = List<double?>.of(previous.series.single.values);
    if (values.length < input.data.length) {
      values.length = input.data.length;
    }
    for (var index = change.currentStart; index < input.data.length; index++) {
      values[index] = input.data[index].close;
    }
    return _result(input, config, values);
  }

  IndicatorResult _result(
    VersionedKlineData input,
    IndicatorConfig config,
    Iterable<double?> values,
  ) =>
      IndicatorResult(
        instanceId: config.instanceId,
        definitionId: id,
        dataVersion: input.version,
        length: input.data.length,
        series: [IndicatorSeries(id: 'value', values: values)],
      );
}

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
