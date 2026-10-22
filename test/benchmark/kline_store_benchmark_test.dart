// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';

import '../support/v2_kline_fixture.dart';

const _runBenchmark = bool.fromEnvironment('RUN_KLINE_STORE_BENCHMARK');

void main() {
  test(
    'records 10000 Kline Store timings and RSS baseline',
    () {
      final all = buildV2KlineFixture(10000);

      final replaceSamples = _samples(30, () {
        KlineStore().replace(all);
      });
      _metric('replace_10000', replaceSamples);

      final prependBatch = all.sublist(0, 1000);
      final prependBase = all.sublist(1000);
      final prependSamples = _samples(30, () {
        final store = KlineStore()..replace(prependBase);
        store.prepend(prependBatch);
      });
      _metric('prepend_1000_into_9000', prependSamples);

      final appendBase = all.sublist(0, 9000);
      final appendBatch = all.sublist(9000);
      final appendSamples = _samples(30, () {
        final store = KlineStore()..replace(appendBase);
        store.append(appendBatch);
      });
      _metric('append_1000_into_9000', appendSamples);

      final updateStore = KlineStore()..replace(all);
      var close = updateStore.snapshot.lastOrNull!.close;
      final updateSamples = _samples(100, () {
        close += 0.001;
        final last = updateStore.snapshot.lastOrNull!;
        updateStore.update(
          last.copyWith(close: close, high: close + 1),
        );
      });
      _metric('update_last_of_10000', updateSamples);

      final rssBefore = ProcessInfo.currentRss;
      final memoryStore = KlineStore()
        ..replace(buildV2KlineFixture(10000, startIndex: 20000));
      final rssAfter = ProcessInfo.currentRss;
      expect(memoryStore.snapshot.length, 10000);
      print(
        jsonEncode({
          'metric': 'store_10000_rss_delta',
          'bytes': rssAfter - rssBefore,
          'rssBefore': rssBefore,
          'rssAfter': rssAfter,
          'mode': 'flutter_test_host_debug',
        }),
      );

      expect(
        _percentile(prependSamples, 0.95),
        lessThanOrEqualTo(50000),
        reason: 'Historical prepend P95 must remain within the 50 ms budget.',
      );
      expect(
        _percentile(appendSamples, 0.95),
        lessThanOrEqualTo(50000),
        reason: 'Historical append P95 must remain within the 50 ms budget.',
      );
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
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
