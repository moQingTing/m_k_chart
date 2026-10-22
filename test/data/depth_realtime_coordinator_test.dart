import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  test('snapshot then delta inserts updates and deletes price levels', () {
    final coordinator = DepthRealtimeCoordinator();
    final snapshot = coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );
    final result = coordinator.addDelta(
      _delta(
        101,
        102,
        previous: 100,
        bids: [
          DepthLevelUpdate(price: 99, quantity: 5),
          DepthLevelUpdate(price: 98, quantity: 0),
          DepthLevelUpdate(price: 97, quantity: 4),
        ],
        asks: [DepthLevelUpdate(price: 101, quantity: 0)],
      ),
      generation: coordinator.generation,
    );

    expect(snapshot.outcome, DepthMergeOutcome.snapshotApplied);
    expect(result.outcome, DepthMergeOutcome.deltaApplied);
    expect(result.state.lastUpdateId, 102);
    expect(result.state.book.bids.map((level) => level.price), [99, 97]);
    expect(result.state.book.bids.first.quantity, 5);
    expect(result.state.book.asks.map((level) => level.price), [102]);
    expect(result.state.version, DepthBookVersion(2));
  });

  test('stale and duplicate ranges do not change state versions', () {
    final coordinator = DepthRealtimeCoordinator();
    coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );
    final before = coordinator.state;

    final result = coordinator.addDelta(
      _delta(99, 100),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.ignoredStaleDelta);
    expect(identical(result.state, before), isTrue);
  });

  test('first buffered range may bridge the snapshot update id', () {
    final coordinator = DepthRealtimeCoordinator();
    final delta = _delta(
      98,
      102,
      bids: [DepthLevelUpdate(price: 99, quantity: 7)],
    );
    coordinator.addDelta(delta, generation: coordinator.generation);

    final result = coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.snapshotApplied);
    expect(result.replayedEventCount, 1);
    expect(result.state.lastUpdateId, 102);
    expect(result.state.book.bestBid?.quantity, 7);
  });

  test('range gap marks the book out of sync without mutating valid levels',
      () {
    final coordinator = DepthRealtimeCoordinator();
    coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );
    final beforeBook = coordinator.state.book;

    final result = coordinator.addDelta(
      _delta(102, 103),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.outOfSync);
    expect(result.requiresSnapshot, isTrue);
    expect(result.state.status, DepthSyncStatus.outOfSync);
    expect(identical(result.state.book, beforeBook), isTrue);
    expect(result.state.lastUpdateId, 100);
    expect(coordinator.bufferedEventCount, 1);

    final recovered = coordinator.applySnapshot(
      _snapshot(101),
      generation: coordinator.generation,
    );
    expect(recovered.outcome, DepthMergeOutcome.snapshotApplied);
    expect(recovered.replayedEventCount, 1);
    expect(recovered.state.lastUpdateId, 103);
    expect(recovered.state.isSynchronized, isTrue);
  });

  test('exact next range validates previous final update id when supplied', () {
    final coordinator = DepthRealtimeCoordinator();
    coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );

    final result = coordinator.addDelta(
      _delta(101, 102, previous: 99),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.outOfSync);
    expect(result.requiresSnapshot, isTrue);
  });

  test('events buffer before snapshot and stale buffered events are discarded',
      () {
    final coordinator = DepthRealtimeCoordinator();
    expect(
      coordinator
          .addDelta(_delta(90, 95), generation: coordinator.generation)
          .outcome,
      DepthMergeOutcome.buffered,
    );
    coordinator.addDelta(
      _delta(
        101,
        101,
        bids: [DepthLevelUpdate(price: 99, quantity: 8)],
      ),
      generation: coordinator.generation,
    );

    final result = coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.snapshotApplied);
    expect(result.replayedEventCount, 1);
    expect(result.state.lastUpdateId, 101);
    expect(result.state.book.bestBid?.quantity, 8);
    expect(coordinator.bufferedEventCount, 0);
  });

  test('too-old snapshot preserves unresolved events for a newer reload', () {
    final coordinator = DepthRealtimeCoordinator();
    coordinator.addDelta(
      _delta(105, 106),
      generation: coordinator.generation,
    );

    final old = coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );
    final recovered = coordinator.applySnapshot(
      _snapshot(104),
      generation: coordinator.generation,
    );

    expect(old.outcome, DepthMergeOutcome.outOfSync);
    expect(old.requiresSnapshot, isTrue);
    expect(coordinator.bufferedEventCount, 0);
    expect(recovered.outcome, DepthMergeOutcome.snapshotApplied);
    expect(recovered.replayedEventCount, 1);
    expect(recovered.state.lastUpdateId, 106);
    expect(recovered.state.isSynchronized, isTrue);
  });

  test('crossed result is rejected and requests a clean snapshot', () {
    final coordinator = DepthRealtimeCoordinator();
    coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );

    final result = coordinator.addDelta(
      _delta(
        101,
        101,
        bids: [DepthLevelUpdate(price: 103, quantity: 1)],
      ),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.outOfSync);
    expect(result.state.book.bestBid?.price, 99);
  });

  test('different symbols and stale generations cannot change the book', () {
    final coordinator = DepthRealtimeCoordinator();
    coordinator.applySnapshot(
      _snapshot(100),
      generation: coordinator.generation,
    );
    final stale = coordinator.generation;
    final current = coordinator.beginNextGeneration();

    final staleResult = coordinator.addDelta(
      _delta(101, 101),
      generation: stale,
    );
    final wrongSymbol = coordinator.applySnapshot(
      _snapshot(200, symbol: 'ETHUSDT'),
      generation: current,
    );
    final different = coordinator.addDelta(
      _delta(201, 201, symbol: 'BTCUSDT'),
      generation: current,
    );

    expect(staleResult.outcome, DepthMergeOutcome.ignoredStaleGeneration);
    expect(wrongSymbol.outcome, DepthMergeOutcome.snapshotApplied);
    expect(different.outcome, DepthMergeOutcome.rejectedDifferentSymbol);
    expect(coordinator.state.symbol, 'ETHUSDT');
  });

  test('pre-snapshot buffer cannot mix symbols in one generation', () {
    final coordinator = DepthRealtimeCoordinator();
    coordinator.addDelta(
      _delta(1, 1),
      generation: coordinator.generation,
    );

    final result = coordinator.addDelta(
      _delta(2, 2, symbol: 'ETHUSDT'),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.rejectedDifferentSymbol);
    expect(coordinator.bufferedEventCount, 1);
  });

  test('bounded buffering reports overflow and clears unsafe events', () {
    final coordinator = DepthRealtimeCoordinator(maxBufferedEvents: 1);
    coordinator.addDelta(_delta(1, 1), generation: coordinator.generation);

    final result = coordinator.addDelta(
      _delta(2, 2),
      generation: coordinator.generation,
    );

    expect(result.outcome, DepthMergeOutcome.bufferOverflow);
    expect(result.requiresSnapshot, isTrue);
    expect(coordinator.bufferedEventCount, 0);
  });

  test('events validate ids symbols quantities and duplicate prices', () {
    expect(() => DepthGeneration(-1), throwsArgumentError);
    expect(() => DepthBookVersion(-1), throwsArgumentError);
    expect(
      () => DepthRealtimeCoordinator(maxBufferedEvents: 0),
      throwsArgumentError,
    );
    expect(
      () => DepthLevelUpdate(price: 1, quantity: -1),
      throwsArgumentError,
    );
    expect(
      () => DepthDeltaEvent(
        symbol: '',
        firstUpdateId: 2,
        finalUpdateId: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => DepthDeltaEvent(
        symbol: 'BTCUSDT',
        firstUpdateId: 1,
        finalUpdateId: 2,
        bids: [
          DepthLevelUpdate(price: 99, quantity: 1),
          DepthLevelUpdate(price: 99, quantity: 2),
        ],
      ),
      throwsArgumentError,
    );
    final source = <DepthLevelUpdate>[
      DepthLevelUpdate(price: 99, quantity: 1),
    ];
    final immutable = DepthDeltaEvent(
      symbol: 'BTCUSDT',
      firstUpdateId: 1,
      finalUpdateId: 1,
      bids: source,
    );
    source.clear();
    expect(immutable.bids, hasLength(1));
    expect(() => immutable.bids.clear(), throwsUnsupportedError);
  });
}

DepthBookSnapshotEvent _snapshot(
  int updateId, {
  String symbol = 'BTCUSDT',
}) =>
    DepthBookSnapshotEvent(
      symbol: symbol,
      lastUpdateId: updateId,
      bids: [
        DepthLevel(price: 99, quantity: 2),
        DepthLevel(price: 98, quantity: 3),
      ],
      asks: [
        DepthLevel(price: 101, quantity: 1),
        DepthLevel(price: 102, quantity: 4),
      ],
    );

DepthDeltaEvent _delta(
  int first,
  int last, {
  String symbol = 'BTCUSDT',
  int? previous,
  Iterable<DepthLevelUpdate> bids = const [],
  Iterable<DepthLevelUpdate> asks = const [],
}) =>
    DepthDeltaEvent(
      symbol: symbol,
      firstUpdateId: first,
      finalUpdateId: last,
      previousFinalUpdateId: previous,
      bids: bids,
      asks: asks,
    );
