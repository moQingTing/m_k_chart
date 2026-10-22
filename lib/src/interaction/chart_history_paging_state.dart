import '../viewport/viewport.dart';

enum ChartHistoryPagingPhase {
  idle,
  loading,
  noMore,
  failure,
}

/// Immutable lifecycle for loading candles older than the current snapshot.
final class ChartHistoryPagingState {
  const ChartHistoryPagingState({
    this.phase = ChartHistoryPagingPhase.idle,
    this.requestSerial = 0,
    this.failureCount = 0,
  })  : assert(requestSerial >= 0),
        assert(failureCount >= 0);

  final ChartHistoryPagingPhase phase;
  final int requestSerial;
  final int failureCount;

  bool get isLoading => phase == ChartHistoryPagingPhase.loading;
  bool get hasNoMore => phase == ChartHistoryPagingPhase.noMore;
  bool get canRequest =>
      phase == ChartHistoryPagingPhase.idle ||
      phase == ChartHistoryPagingPhase.failure;

  /// Starts one request when the oldest edge is within [thresholdItems].
  ChartHistoryPagingState requestIfNeeded(
    ChartViewport viewport, {
    double thresholdItems = 2,
  }) {
    _requireNonNegativeFinite(thresholdItems, 'thresholdItems');
    if (!canRequest || viewport.itemCount == 0) {
      return this;
    }
    final distanceFromOldest =
        viewport.maxScrollOffsetItems - viewport.scrollOffsetItems;
    if (distanceFromOldest > thresholdItems) {
      return this;
    }
    return ChartHistoryPagingState(
      phase: ChartHistoryPagingPhase.loading,
      requestSerial: requestSerial + 1,
      failureCount: failureCount,
    );
  }

  ChartHistoryPagingState complete({required bool hasMore}) {
    if (!isLoading) {
      return this;
    }
    return ChartHistoryPagingState(
      phase: hasMore
          ? ChartHistoryPagingPhase.idle
          : ChartHistoryPagingPhase.noMore,
      requestSerial: requestSerial,
      failureCount: failureCount,
    );
  }

  ChartHistoryPagingState fail() {
    if (!isLoading) {
      return this;
    }
    return ChartHistoryPagingState(
      phase: ChartHistoryPagingPhase.failure,
      requestSerial: requestSerial,
      failureCount: failureCount + 1,
    );
  }

  ChartHistoryPagingState reset() => const ChartHistoryPagingState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartHistoryPagingState &&
          phase == other.phase &&
          requestSerial == other.requestSerial &&
          failureCount == other.failureCount;

  @override
  int get hashCode => Object.hash(phase, requestSerial, failureCount);
}

void _requireNonNegativeFinite(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      name,
      'Must be finite and non-negative.',
    );
  }
}
