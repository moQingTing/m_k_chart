// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';

const _runBenchmark = bool.fromEnvironment('RUN_DEPTH_BENCHMARK');
const _eventCount = 600;
const _updatesPerSide = 8;
const _hostFrameBudgetMicroseconds = 16700.0;
const _hostStableRepaintBudgetMicroseconds = 5000.0;

void main() {
  test(
    'records 1000x2 depth levels through a sustained 10 Hz pipeline',
    () {
      final coordinator = DepthRealtimeCoordinator();
      final initialBook = _book(1000);
      coordinator.applySnapshot(
        DepthBookSnapshotEvent(
          symbol: 'BTCUSDT',
          lastUpdateId: 1000,
          bids: initialBook.bids,
          asks: initialBook.asks,
        ),
        generation: coordinator.generation,
      );
      final policy = DepthCurveSamplingPolicy(
        maxRetainedLevelsPerSide: 1000,
        maxRenderedPointsPerSide: 160,
      );
      final cache = DepthCurveCache(capacity: 2);
      final layout = DepthChartLayout(size: const Size(390, 220));
      final theme = DefaultChartRenderStyle();
      final mergeSamples = <double>[];
      final prepareSamples = <double>[];
      final paintSamples = <double>[];
      final totalSamples = <double>[];
      final rssBefore = ProcessInfo.currentRss;

      for (var iteration = 0; iteration < _eventCount + 30; iteration++) {
        final localId = coordinator.state.lastUpdateId!;
        final delta = _delta(
          book: coordinator.state.book,
          updateId: localId + 1,
          iteration: iteration,
        );
        final totalWatch = Stopwatch()..start();
        final mergeWatch = Stopwatch()..start();
        final result = coordinator.addDelta(
          delta,
          generation: coordinator.generation,
        );
        mergeWatch.stop();
        expect(result.outcome, DepthMergeOutcome.deltaApplied);

        final prepareWatch = Stopwatch()..start();
        final snapshot = DepthRenderSnapshot<DefaultChartRenderStyle>(
          book: result.state.book,
          theme: theme,
          layout: layout,
          version: result.state.version.value,
          samplingPolicy: policy,
          curveCache: cache,
        );
        prepareWatch.stop();
        expect(snapshot.curve.bids, hasLength(160));
        expect(snapshot.curve.asks, hasLength(160));

        final paintWatch = Stopwatch()..start();
        _paint(snapshot);
        paintWatch.stop();
        totalWatch.stop();
        if (iteration >= 30) {
          mergeSamples.add(mergeWatch.elapsedMicroseconds.toDouble());
          prepareSamples.add(prepareWatch.elapsedMicroseconds.toDouble());
          paintSamples.add(paintWatch.elapsedMicroseconds.toDouble());
          totalSamples.add(totalWatch.elapsedMicroseconds.toDouble());
        }
      }

      final stableSamples = <double>[];
      final stableBook = coordinator.state.book;
      for (var iteration = 0; iteration < 220; iteration++) {
        final stopwatch = Stopwatch()..start();
        final snapshot = DepthRenderSnapshot<DefaultChartRenderStyle>(
          book: stableBook,
          theme: theme,
          layout: layout,
          version: coordinator.state.version.value,
          samplingPolicy: policy,
          curveCache: cache,
        );
        _paint(snapshot);
        stopwatch.stop();
        if (iteration >= 20) {
          stableSamples.add(stopwatch.elapsedMicroseconds.toDouble());
        }
      }
      final rssAfter = ProcessInfo.currentRss;

      _metric('depth_merge_1000x2_10hz', mergeSamples);
      _metric('depth_curve_prepare_1000x2_to_160x2', prepareSamples);
      _metric('depth_canvas_record_160x2', paintSamples);
      _metric('depth_end_to_end_1000x2_10hz', totalSamples);
      _metric('depth_stable_cached_repaint_160x2', stableSamples);
      print(
        jsonEncode({
          'metric': 'depth_pipeline_rss_delta',
          'bytes': rssAfter - rssBefore,
          'rssBefore': rssBefore,
          'rssAfter': rssAfter,
          'events': _eventCount,
          'mode': 'flutter_test_host_debug',
        }),
      );

      expect(coordinator.state.isSynchronized, isTrue);
      expect(coordinator.state.book.bids, hasLength(1000));
      expect(coordinator.state.book.asks, hasLength(1000));
      expect(
        _percentile(totalSamples, 0.95),
        lessThanOrEqualTo(_hostFrameBudgetMicroseconds),
        reason: 'Host end-to-end P95 must fit one 60 Hz frame budget.',
      );
      expect(
        _percentile(stableSamples, 0.95),
        lessThanOrEqualTo(_hostStableRepaintBudgetMicroseconds),
        reason: 'A cached stable repaint must remain below 5 ms on the host.',
      );
      expect(cache.hitCount, greaterThanOrEqualTo(stableSamples.length));
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
  );
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
  for (var offset = 0; offset < _updatesPerSide; offset++) {
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

void _paint(DepthRenderSnapshot<DefaultChartRenderStyle> snapshot) {
  final recorder = PictureRecorder();
  StandardDepthCurveRenderer.paint(
    canvas: Canvas(recorder),
    snapshot: snapshot,
  );
  recorder.endRecording().dispose();
}

void _metric(String name, List<double> samples) {
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

double _percentile(List<double> samples, double percentile) {
  final sorted = List<double>.of(samples)..sort();
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}
