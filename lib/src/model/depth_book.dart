import 'dart:collection';

enum DepthSide { bid, ask }

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
  factory DepthCurve.fromBook(DepthBook book) {
    final bids = _accumulate(book.bids, DepthSide.bid);
    final asks = _accumulate(book.asks, DepthSide.ask);
    final bidMaximum = bids.isEmpty ? 0.0 : bids.last.cumulativeQuantity;
    final askMaximum = asks.isEmpty ? 0.0 : asks.last.cumulativeQuantity;
    return DepthCurve._(
      book: book,
      bids: UnmodifiableListView(bids),
      asks: UnmodifiableListView(asks),
      maxCumulativeQuantity: bidMaximum > askMaximum ? bidMaximum : askMaximum,
    );
  }

  const DepthCurve._({
    required this.book,
    required this.bids,
    required this.asks,
    required this.maxCumulativeQuantity,
  });

  final DepthBook book;
  final List<DepthCumulativeLevel> bids;
  final List<DepthCumulativeLevel> asks;
  final double maxCumulativeQuantity;

  bool get isEmpty => book.isEmpty;
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
