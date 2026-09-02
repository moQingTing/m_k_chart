import '../model/model.dart';

final class DepthGeneration implements Comparable<DepthGeneration> {
  factory DepthGeneration(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must be non-negative.');
    }
    return DepthGeneration._(value);
  }

  const DepthGeneration._(this.value);

  static const zero = DepthGeneration._(0);

  final int value;

  DepthGeneration next() => DepthGeneration(value + 1);

  @override
  int compareTo(DepthGeneration other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthGeneration && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class DepthBookVersion implements Comparable<DepthBookVersion> {
  factory DepthBookVersion(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must be non-negative.');
    }
    return DepthBookVersion._(value);
  }

  const DepthBookVersion._(this.value);

  static const zero = DepthBookVersion._(0);

  final int value;

  DepthBookVersion next() => DepthBookVersion(value + 1);

  @override
  int compareTo(DepthBookVersion other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthBookVersion && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// A delta quantity at one exact price. Zero quantity deletes the level.
final class DepthLevelUpdate {
  factory DepthLevelUpdate({required double price, required double quantity}) {
    if (!price.isFinite || price <= 0) {
      throw ArgumentError.value(price, 'price', 'Must be finite and positive.');
    }
    if (!quantity.isFinite || quantity < 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Must be finite and non-negative.',
      );
    }
    return DepthLevelUpdate._(price, quantity);
  }

  const DepthLevelUpdate._(this.price, this.quantity);

  final double price;
  final double quantity;

  bool get removesLevel => quantity == 0;
}

/// Exchange-neutral REST/order-book snapshot input.
final class DepthBookSnapshotEvent {
  factory DepthBookSnapshotEvent({
    required String symbol,
    required int lastUpdateId,
    required Iterable<DepthLevel> bids,
    required Iterable<DepthLevel> asks,
  }) {
    final normalizedSymbol = _validatedSymbol(symbol);
    _validateUpdateId(lastUpdateId, 'lastUpdateId');
    return DepthBookSnapshotEvent._(
      normalizedSymbol,
      lastUpdateId,
      DepthBook(bids: bids, asks: asks),
    );
  }

  const DepthBookSnapshotEvent._(
    this.symbol,
    this.lastUpdateId,
    this.book,
  );

  final String symbol;
  final int lastUpdateId;
  final DepthBook book;
}

/// Exchange-neutral diff-depth event using an inclusive update-ID range.
final class DepthDeltaEvent {
  factory DepthDeltaEvent({
    required String symbol,
    required int firstUpdateId,
    required int finalUpdateId,
    int? previousFinalUpdateId,
    Iterable<DepthLevelUpdate> bids = const [],
    Iterable<DepthLevelUpdate> asks = const [],
  }) {
    final normalizedSymbol = _validatedSymbol(symbol);
    _validateUpdateId(firstUpdateId, 'firstUpdateId');
    _validateUpdateId(finalUpdateId, 'finalUpdateId');
    if (firstUpdateId > finalUpdateId) {
      throw ArgumentError('firstUpdateId must not exceed finalUpdateId.');
    }
    if (previousFinalUpdateId != null) {
      _validateUpdateId(previousFinalUpdateId, 'previousFinalUpdateId');
      if (previousFinalUpdateId >= finalUpdateId) {
        throw ArgumentError(
          'previousFinalUpdateId must be lower than finalUpdateId.',
        );
      }
    }
    final immutableBids = List<DepthLevelUpdate>.unmodifiable(bids);
    final immutableAsks = List<DepthLevelUpdate>.unmodifiable(asks);
    _validateUniqueUpdatePrices(immutableBids, 'bids');
    _validateUniqueUpdatePrices(immutableAsks, 'asks');
    return DepthDeltaEvent._(
      symbol: normalizedSymbol,
      firstUpdateId: firstUpdateId,
      finalUpdateId: finalUpdateId,
      previousFinalUpdateId: previousFinalUpdateId,
      bids: immutableBids,
      asks: immutableAsks,
    );
  }

  const DepthDeltaEvent._({
    required this.symbol,
    required this.firstUpdateId,
    required this.finalUpdateId,
    required this.previousFinalUpdateId,
    required this.bids,
    required this.asks,
  });

  final String symbol;
  final int firstUpdateId;
  final int finalUpdateId;
  final int? previousFinalUpdateId;
  final List<DepthLevelUpdate> bids;
  final List<DepthLevelUpdate> asks;
}

enum DepthSyncStatus { awaitingSnapshot, synchronized, outOfSync }

/// Immutable current state of one local order book.
final class DepthBookState {
  const DepthBookState._({
    required this.symbol,
    required this.lastUpdateId,
    required this.book,
    required this.version,
    required this.status,
  });

  static final empty = DepthBookState._(
    symbol: null,
    lastUpdateId: null,
    book: DepthBook(bids: const [], asks: const []),
    version: DepthBookVersion.zero,
    status: DepthSyncStatus.awaitingSnapshot,
  );

  final String? symbol;
  final int? lastUpdateId;
  final DepthBook book;
  final DepthBookVersion version;
  final DepthSyncStatus status;

  bool get isSynchronized => status == DepthSyncStatus.synchronized;
  bool get requiresSnapshot => !isSynchronized;
}

enum DepthMergeOutcome {
  snapshotApplied,
  deltaApplied,
  buffered,
  ignoredStaleDelta,
  ignoredStaleGeneration,
  rejectedDifferentSymbol,
  outOfSync,
  bufferOverflow,
}

final class DepthMergeResult {
  const DepthMergeResult({
    required this.outcome,
    required this.state,
    this.replayedEventCount = 0,
  });

  final DepthMergeOutcome outcome;
  final DepthBookState state;
  final int replayedEventCount;

  bool get changed => switch (outcome) {
        DepthMergeOutcome.snapshotApplied ||
        DepthMergeOutcome.deltaApplied ||
        DepthMergeOutcome.outOfSync ||
        DepthMergeOutcome.bufferOverflow =>
          true,
        _ => false,
      };

  bool get requiresSnapshot => state.requiresSnapshot;
}

/// Buffers stream deltas around a REST snapshot and maintains one local book.
final class DepthRealtimeCoordinator {
  factory DepthRealtimeCoordinator({int maxBufferedEvents = 2048}) {
    if (maxBufferedEvents <= 0) {
      throw ArgumentError.value(
        maxBufferedEvents,
        'maxBufferedEvents',
        'Must be positive.',
      );
    }
    return DepthRealtimeCoordinator._(maxBufferedEvents);
  }

  DepthRealtimeCoordinator._(this.maxBufferedEvents);

  final int maxBufferedEvents;
  final List<DepthDeltaEvent> _buffer = [];
  DepthGeneration _generation = DepthGeneration.zero;
  DepthBookState _state = DepthBookState.empty;

  DepthGeneration get generation => _generation;
  DepthBookState get state => _state;
  int get bufferedEventCount => _buffer.length;

  /// Invalidates outstanding snapshot requests and stream events.
  DepthGeneration beginNextGeneration() {
    _generation = _generation.next();
    _buffer.clear();
    _state = DepthBookState._(
      symbol: null,
      lastUpdateId: null,
      book: DepthBook(bids: const [], asks: const []),
      version: _state.version.next(),
      status: DepthSyncStatus.awaitingSnapshot,
    );
    return _generation;
  }

  DepthMergeResult addDelta(
    DepthDeltaEvent event, {
    required DepthGeneration generation,
  }) {
    if (generation != _generation) {
      return _result(DepthMergeOutcome.ignoredStaleGeneration);
    }
    if (_state.status != DepthSyncStatus.synchronized) {
      return _bufferEvent(event);
    }
    final result = _applyDelta(event);
    if (result.outcome == DepthMergeOutcome.outOfSync) {
      if (_buffer.length >= maxBufferedEvents) {
        _buffer.clear();
        return _result(DepthMergeOutcome.bufferOverflow);
      }
      _buffer.add(event);
    }
    return result;
  }

  DepthMergeResult applySnapshot(
    DepthBookSnapshotEvent event, {
    required DepthGeneration generation,
  }) {
    if (generation != _generation) {
      return _result(DepthMergeOutcome.ignoredStaleGeneration);
    }
    if (_buffer.isNotEmpty &&
        _buffer.any((delta) => delta.symbol != event.symbol)) {
      return _result(DepthMergeOutcome.rejectedDifferentSymbol);
    }
    _state = DepthBookState._(
      symbol: event.symbol,
      lastUpdateId: event.lastUpdateId,
      book: event.book,
      version: _state.version.next(),
      status: DepthSyncStatus.synchronized,
    );
    if (_buffer.isEmpty) {
      return _result(DepthMergeOutcome.snapshotApplied);
    }

    final pending = List<DepthDeltaEvent>.of(_buffer, growable: false);
    _buffer.clear();
    var replayed = 0;
    for (var index = 0; index < pending.length; index++) {
      final delta = pending[index];
      final result = _applyDelta(delta);
      if (result.outcome == DepthMergeOutcome.ignoredStaleDelta) {
        continue;
      }
      if (result.outcome == DepthMergeOutcome.deltaApplied) {
        replayed++;
        continue;
      }
      if (result.outcome == DepthMergeOutcome.outOfSync) {
        _buffer.addAll(pending.skip(index));
      }
      return DepthMergeResult(
        outcome: result.outcome,
        state: _state,
        replayedEventCount: replayed,
      );
    }
    return DepthMergeResult(
      outcome: DepthMergeOutcome.snapshotApplied,
      state: _state,
      replayedEventCount: replayed,
    );
  }

  DepthMergeResult _bufferEvent(DepthDeltaEvent event) {
    if (_buffer.isNotEmpty && _buffer.first.symbol != event.symbol) {
      return _result(DepthMergeOutcome.rejectedDifferentSymbol);
    }
    if (_buffer.length >= maxBufferedEvents) {
      _buffer.clear();
      _markOutOfSync();
      return _result(DepthMergeOutcome.bufferOverflow);
    }
    _buffer.add(event);
    return _result(DepthMergeOutcome.buffered);
  }

  DepthMergeResult _applyDelta(DepthDeltaEvent event) {
    final symbol = _state.symbol;
    final localUpdateId = _state.lastUpdateId;
    if (symbol == null || localUpdateId == null) {
      return _bufferEvent(event);
    }
    if (event.symbol != symbol) {
      return _result(DepthMergeOutcome.rejectedDifferentSymbol);
    }
    if (event.finalUpdateId <= localUpdateId) {
      return _result(DepthMergeOutcome.ignoredStaleDelta);
    }
    final expectedUpdateId = localUpdateId + 1;
    final hasRangeGap = event.firstUpdateId > expectedUpdateId;
    final hasPreviousGap = event.firstUpdateId == expectedUpdateId &&
        event.previousFinalUpdateId != null &&
        event.previousFinalUpdateId != localUpdateId;
    if (hasRangeGap || hasPreviousGap) {
      _markOutOfSync();
      return _result(DepthMergeOutcome.outOfSync);
    }

    try {
      final nextBook = _applyUpdates(_state.book, event);
      _state = DepthBookState._(
        symbol: symbol,
        lastUpdateId: event.finalUpdateId,
        book: nextBook,
        version: _state.version.next(),
        status: DepthSyncStatus.synchronized,
      );
      return _result(DepthMergeOutcome.deltaApplied);
    } on ArgumentError {
      _markOutOfSync();
      return _result(DepthMergeOutcome.outOfSync);
    }
  }

  void _markOutOfSync() {
    if (_state.status == DepthSyncStatus.outOfSync) return;
    _state = DepthBookState._(
      symbol: _state.symbol,
      lastUpdateId: _state.lastUpdateId,
      book: _state.book,
      version: _state.version.next(),
      status: DepthSyncStatus.outOfSync,
    );
  }

  DepthMergeResult _result(DepthMergeOutcome outcome) => DepthMergeResult(
        outcome: outcome,
        state: _state,
      );
}

DepthBook _applyUpdates(DepthBook source, DepthDeltaEvent event) {
  final bids = <double, DepthLevel>{
    for (final level in source.bids) level.price: level,
  };
  final asks = <double, DepthLevel>{
    for (final level in source.asks) level.price: level,
  };
  _applySideUpdates(bids, event.bids);
  _applySideUpdates(asks, event.asks);
  final nextBids = bids.values.toList(growable: false)
    ..sort((left, right) => right.price.compareTo(left.price));
  final nextAsks = asks.values.toList(growable: false)
    ..sort((left, right) => left.price.compareTo(right.price));
  return DepthBook(bids: nextBids, asks: nextAsks);
}

void _applySideUpdates(
  Map<double, DepthLevel> levels,
  List<DepthLevelUpdate> updates,
) {
  for (final update in updates) {
    if (update.removesLevel) {
      levels.remove(update.price);
    } else {
      levels[update.price] = DepthLevel(
        price: update.price,
        quantity: update.quantity,
      );
    }
  }
}

String _validatedSymbol(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) {
    throw ArgumentError.value(symbol, 'symbol', 'Must not be empty.');
  }
  return normalized;
}

void _validateUpdateId(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Must be non-negative.');
  }
}

void _validateUniqueUpdatePrices(
  List<DepthLevelUpdate> updates,
  String name,
) {
  final prices = <double>{};
  for (final update in updates) {
    if (!prices.add(update.price)) {
      throw ArgumentError.value(update.price, name, 'Duplicate update price.');
    }
  }
}
