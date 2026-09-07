import '../model/model.dart';
import 'kline_store.dart';

final class KlineGeneration implements Comparable<KlineGeneration> {
  factory KlineGeneration(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must be non-negative.');
    }
    return KlineGeneration._(value);
  }

  const KlineGeneration._(this.value);

  static const zero = KlineGeneration._(0);

  final int value;

  KlineGeneration next() => KlineGeneration(value + 1);

  @override
  int compareTo(KlineGeneration other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KlineGeneration && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'KlineGeneration($value)';
}

enum KlineMergeOutcome {
  appended,
  updated,
  insertedOutOfOrder,
  ignoredDuplicate,
  ignoredStaleGeneration,
  rejectedClosedCorrection,
  rejectedDifferentSeries,
  rejectedOutsideWindow,
}

final class KlineMergeResult {
  const KlineMergeResult({
    required this.outcome,
    required this.snapshot,
    this.requiresReload = false,
  });

  final KlineMergeOutcome outcome;
  final KlineSnapshot snapshot;
  final bool requiresReload;

  bool get changed => switch (outcome) {
        KlineMergeOutcome.appended ||
        KlineMergeOutcome.updated ||
        KlineMergeOutcome.insertedOutOfOrder =>
          true,
        _ => false,
      };
}

/// Applies realtime events to a strict [KlineStore] with explicit policies.
final class KlineRealtimeCoordinator {
  factory KlineRealtimeCoordinator({
    KlineStore? store,
    int maxOutOfOrderCandles = 2,
  }) {
    if (maxOutOfOrderCandles < 0) {
      throw ArgumentError.value(
        maxOutOfOrderCandles,
        'maxOutOfOrderCandles',
        'Must be non-negative.',
      );
    }
    return KlineRealtimeCoordinator._(
      store ?? KlineStore(),
      maxOutOfOrderCandles,
    );
  }

  KlineRealtimeCoordinator._(this.store, this.maxOutOfOrderCandles);

  final KlineStore store;
  final int maxOutOfOrderCandles;
  KlineGeneration _generation = KlineGeneration.zero;

  KlineGeneration get generation => _generation;

  /// Invalidates outstanding async work and optionally replaces the snapshot.
  KlineGeneration beginNextGeneration({
    Iterable<Kline> replacement = const [],
  }) {
    store.replace(replacement);
    _generation = _generation.next();
    return _generation;
  }

  KlineMergeResult apply(
    Kline incoming, {
    required KlineGeneration generation,
    bool allowClosedCorrection = false,
  }) {
    if (generation != _generation) {
      return _result(KlineMergeOutcome.ignoredStaleGeneration);
    }

    final snapshot = store.snapshot;
    if (snapshot.isEmpty) {
      return _changed(
        KlineMergeOutcome.appended,
        store.append([incoming]),
      );
    }
    if (!snapshot.firstOrNull!.hasSameSeries(incoming)) {
      return _result(KlineMergeOutcome.rejectedDifferentSeries);
    }

    final insertionIndex = _lowerBound(snapshot.data, incoming.openTime);
    if (insertionIndex < snapshot.length &&
        snapshot[insertionIndex].openTime == incoming.openTime) {
      final existing = snapshot[insertionIndex];
      if (existing == incoming) {
        return _result(KlineMergeOutcome.ignoredDuplicate);
      }
      if (existing.isClosed && !allowClosedCorrection) {
        return _result(KlineMergeOutcome.rejectedClosedCorrection);
      }
      return _changed(KlineMergeOutcome.updated, store.update(incoming));
    }

    if (insertionIndex == snapshot.length) {
      return _changed(
        KlineMergeOutcome.appended,
        store.append([incoming]),
      );
    }

    final newerCandleCount = snapshot.length - insertionIndex;
    if (newerCandleCount > maxOutOfOrderCandles) {
      return KlineMergeResult(
        outcome: KlineMergeOutcome.rejectedOutsideWindow,
        snapshot: snapshot,
        requiresReload: true,
      );
    }

    final next = _insertAt(snapshot.data, insertionIndex, incoming);
    return _changed(
      KlineMergeOutcome.insertedOutOfOrder,
      store.replace(next),
    );
  }

  KlineMergeResult _result(KlineMergeOutcome outcome) => KlineMergeResult(
        outcome: outcome,
        snapshot: store.snapshot,
      );

  KlineMergeResult _changed(
    KlineMergeOutcome outcome,
    KlineSnapshot snapshot,
  ) =>
      KlineMergeResult(outcome: outcome, snapshot: snapshot);
}

int _lowerBound(List<Kline> values, int openTime) {
  var low = 0;
  var high = values.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (values[middle].openTime < openTime) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

List<Kline> _insertAt(List<Kline> values, int index, Kline incoming) {
  final result = List<Kline>.filled(
    values.length + 1,
    incoming,
    growable: false,
  );
  result.setRange(0, index, values);
  result[index] = incoming;
  result.setRange(index + 1, result.length, values, index);
  return result;
}
