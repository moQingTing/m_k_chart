import 'dart:collection';

enum DepthSide { bid, ask }

/// Bounds the source levels and cumulative points prepared for depth drawing.
///
/// Trimming always keeps levels nearest to the top of book. Sampling preserves
/// the first and last retained cumulative points, so the displayed outer total
/// remains exact even when intermediate steps are omitted.
final class DepthCurveSamplingPolicy {
  factory DepthCurveSamplingPolicy({
    int? maxRetainedLevelsPerSide,
    int? maxRenderedPointsPerSide,
  }) {
    if (maxRetainedLevelsPerSide != null && maxRetainedLevelsPerSide <= 0) {
      throw ArgumentError.value(
        maxRetainedLevelsPerSide,
        'maxRetainedLevelsPerSide',
        'Must be positive when supplied.',
      );
    }
    if (maxRenderedPointsPerSide != null && maxRenderedPointsPerSide < 2) {
      throw ArgumentError.value(
        maxRenderedPointsPerSide,
        'maxRenderedPointsPerSide',
        'Must be at least two when supplied.',
      );
    }
    return DepthCurveSamplingPolicy._(
      maxRetainedLevelsPerSide: maxRetainedLevelsPerSide,
      maxRenderedPointsPerSide: maxRenderedPointsPerSide,
    );
  }

  const DepthCurveSamplingPolicy.unbounded()
      : maxRetainedLevelsPerSide = null,
        maxRenderedPointsPerSide = null;

  const DepthCurveSamplingPolicy._({
    required this.maxRetainedLevelsPerSide,
    required this.maxRenderedPointsPerSide,
  });

  final int? maxRetainedLevelsPerSide;
  final int? maxRenderedPointsPerSide;

  bool get isUnbounded =>
      maxRetainedLevelsPerSide == null && maxRenderedPointsPerSide == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthCurveSamplingPolicy &&
          maxRetainedLevelsPerSide == other.maxRetainedLevelsPerSide &&
          maxRenderedPointsPerSide == other.maxRenderedPointsPerSide;

  @override
  int get hashCode => Object.hash(
        maxRetainedLevelsPerSide,
        maxRenderedPointsPerSide,
      );
}

/// One immutable positive quantity at an exact order-book price.
final class DepthLevel {
  factory DepthLevel({required double price, required double quantity}) {
    if (!price.isFinite || price <= 0) {
      throw ArgumentError.value(price, 'price', 'Must be finite and positive.');
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Must be finite and positive.',
      );
    }
    return DepthLevel._(price, quantity);
  }

  const DepthLevel._(this.price, this.quantity);

  final double price;
  final double quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthLevel && price == other.price && quantity == other.quantity;

  @override
  int get hashCode => Object.hash(price, quantity);
}

/// Immutable, normalized order book ready for cumulative projection.
///
/// Bids are strictly descending (best bid first), asks strictly ascending
/// (best ask first), and a two-sided book may not be crossed.
final class DepthBook {
  factory DepthBook({
    required Iterable<DepthLevel> bids,
    required Iterable<DepthLevel> asks,
  }) {
    final immutableBids = List<DepthLevel>.unmodifiable(bids);
    final immutableAsks = List<DepthLevel>.unmodifiable(asks);
    _validateOrder(immutableBids, side: DepthSide.bid);
    _validateOrder(immutableAsks, side: DepthSide.ask);
    if (immutableBids.isNotEmpty &&
        immutableAsks.isNotEmpty &&
        immutableBids.first.price >= immutableAsks.first.price) {
      throw ArgumentError('Best bid must be lower than best ask.');
    }
    return DepthBook._(immutableBids, immutableAsks);
  }

  const DepthBook._(this.bids, this.asks);

  final List<DepthLevel> bids;
  final List<DepthLevel> asks;

  bool get isEmpty => bids.isEmpty && asks.isEmpty;
  DepthLevel? get bestBid => bids.isEmpty ? null : bids.first;
  DepthLevel? get bestAsk => asks.isEmpty ? null : asks.first;

  double? get spread {
    final bid = bestBid;
    final ask = bestAsk;
    return bid == null || ask == null ? null : ask.price - bid.price;
  }

  double? get midPrice {
    final bid = bestBid;
    final ask = bestAsk;
    return bid == null || ask == null ? null : (ask.price + bid.price) / 2;
  }

  double? get spreadPercent {
    final value = spread;
    final middle = midPrice;
    return value == null || middle == null ? null : value / middle * 100;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthBook &&
          _listEquals(bids, other.bids) &&
          _listEquals(asks, other.asks);

  @override
  int get hashCode => Object.hash(Object.hashAll(bids), Object.hashAll(asks));
}

/// One source level paired with its best-to-outward cumulative quantity.
final class DepthCumulativeLevel {
  factory DepthCumulativeLevel({
    required DepthSide side,
    required DepthLevel level,
    required double cumulativeQuantity,
  }) {
    if (!cumulativeQuantity.isFinite || cumulativeQuantity < level.quantity) {
      throw ArgumentError.value(
        cumulativeQuantity,
        'cumulativeQuantity',
        'Must be finite and include the source level quantity.',
      );
    }
    return DepthCumulativeLevel._(side, level, cumulativeQuantity);
  }

  const DepthCumulativeLevel._(
    this.side,
    this.level,
    this.cumulativeQuantity,
  );

  final DepthSide side;
  final DepthLevel level;
  final double cumulativeQuantity;

  double get price => level.price;
  double get quantity => level.quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthCumulativeLevel &&
          side == other.side &&
          level == other.level &&
          cumulativeQuantity == other.cumulativeQuantity;

  @override
  int get hashCode => Object.hash(side, level, cumulativeQuantity);
}

/// Cumulative bid/ask series derived once from an immutable [DepthBook].
final class DepthCurve {
  factory DepthCurve.fromBook(
    DepthBook book, {
    DepthCurveSamplingPolicy policy =
        const DepthCurveSamplingPolicy.unbounded(),
  }) {
    final retainedBids = _retainedLevels(book.bids, policy);
    final retainedAsks = _retainedLevels(book.asks, policy);
    final accumulatedBids = _accumulate(retainedBids, DepthSide.bid);
    final accumulatedAsks = _accumulate(retainedAsks, DepthSide.ask);
    final bids = _sample(accumulatedBids, policy);
    final asks = _sample(accumulatedAsks, policy);
    final bidMaximum =
        accumulatedBids.isEmpty ? 0.0 : accumulatedBids.last.cumulativeQuantity;
    final askMaximum =
        accumulatedAsks.isEmpty ? 0.0 : accumulatedAsks.last.cumulativeQuantity;
    return DepthCurve._(
      book: book,
      policy: policy,
      bids: UnmodifiableListView(bids),
      asks: UnmodifiableListView(asks),
      retainedBidLevelCount: retainedBids.length,
      retainedAskLevelCount: retainedAsks.length,
      maxCumulativeQuantity: bidMaximum > askMaximum ? bidMaximum : askMaximum,
    );
  }

  const DepthCurve._({
    required this.book,
    required this.policy,
    required this.bids,
    required this.asks,
    required this.retainedBidLevelCount,
    required this.retainedAskLevelCount,
    required this.maxCumulativeQuantity,
  });

  final DepthBook book;
  final DepthCurveSamplingPolicy policy;
  final List<DepthCumulativeLevel> bids;
  final List<DepthCumulativeLevel> asks;
  final int retainedBidLevelCount;
  final int retainedAskLevelCount;
  final double maxCumulativeQuantity;

  bool get isEmpty => book.isEmpty;
  int get sourceBidLevelCount => book.bids.length;
  int get sourceAskLevelCount => book.asks.length;
  bool get isTrimmed =>
      retainedBidLevelCount < book.bids.length ||
      retainedAskLevelCount < book.asks.length;
  bool get isSampled =>
      bids.length < retainedBidLevelCount ||
      asks.length < retainedAskLevelCount;
}

List<DepthLevel> _retainedLevels(
  List<DepthLevel> levels,
  DepthCurveSamplingPolicy policy,
) {
  final maximum = policy.maxRetainedLevelsPerSide;
  if (maximum == null || levels.length <= maximum) return levels;
  return levels.sublist(0, maximum);
}

List<DepthCumulativeLevel> _sample(
  List<DepthCumulativeLevel> levels,
  DepthCurveSamplingPolicy policy,
) {
  final maximum = policy.maxRenderedPointsPerSide;
  if (maximum == null || levels.length <= maximum) return levels;
  final lastIndex = levels.length - 1;
  final divisor = maximum - 1;
  return List<DepthCumulativeLevel>.generate(
    maximum,
    (index) => levels[index * lastIndex ~/ divisor],
    growable: false,
  );
}

List<DepthCumulativeLevel> _accumulate(
  List<DepthLevel> levels,
  DepthSide side,
) {
  var cumulative = 0.0;
  final result = <DepthCumulativeLevel>[];
  for (final level in levels) {
    cumulative += level.quantity;
    if (!cumulative.isFinite) {
      throw ArgumentError('Cumulative depth quantity must remain finite.');
    }
    result.add(
      DepthCumulativeLevel(
        side: side,
        level: level,
        cumulativeQuantity: cumulative,
      ),
    );
  }
  return result;
}

void _validateOrder(List<DepthLevel> levels, {required DepthSide side}) {
  for (var index = 1; index < levels.length; index++) {
    final previous = levels[index - 1].price;
    final current = levels[index].price;
    final ordered =
        side == DepthSide.bid ? previous > current : previous < current;
    if (!ordered) {
      throw ArgumentError(
        '${side.name} levels must use unique, best-to-outward prices.',
      );
    }
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
