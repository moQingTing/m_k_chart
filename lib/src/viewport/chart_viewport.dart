import 'visible_index_range.dart';

/// Immutable navigation state owned by one chart instance.
///
/// Horizontal scrolling is measured in data slots instead of pixels.
/// [scrollOffsetItems] is the distance from the latest edge: zero keeps the
/// newest item at the right edge and positive values move toward history.
/// Pixel/data coordinate conversion is intentionally deferred to P4-02.
final class ChartViewport {
  factory ChartViewport({
    int itemCount = 0,
    double width = 0,
    double itemExtent = defaultItemExtent,
    double minItemExtent = defaultMinItemExtent,
    double maxItemExtent = defaultMaxItemExtent,
    double scrollOffsetItems = 0,
  }) {
    _validate(
      itemCount: itemCount,
      width: width,
      itemExtent: itemExtent,
      minItemExtent: minItemExtent,
      maxItemExtent: maxItemExtent,
      scrollOffsetItems: scrollOffsetItems,
    );
    final boundedExtent = _clamp(itemExtent, minItemExtent, maxItemExtent);
    final maximum = _maximumScrollOffsetItems(
      itemCount: itemCount,
      width: width,
      itemExtent: boundedExtent,
    );
    return ChartViewport._(
      itemCount: itemCount,
      width: width,
      itemExtent: boundedExtent,
      minItemExtent: minItemExtent,
      maxItemExtent: maxItemExtent,
      scrollOffsetItems: _clamp(scrollOffsetItems, 0, maximum),
    );
  }

  const ChartViewport.initial()
      : itemCount = 0,
        width = 0,
        itemExtent = defaultItemExtent,
        minItemExtent = defaultMinItemExtent,
        maxItemExtent = defaultMaxItemExtent,
        scrollOffsetItems = 0;

  const ChartViewport._({
    required this.itemCount,
    required this.width,
    required this.itemExtent,
    required this.minItemExtent,
    required this.maxItemExtent,
    required this.scrollOffsetItems,
  });

  static const double defaultItemExtent = 8;
  static const double defaultMinItemExtent = 2;
  static const double defaultMaxItemExtent = 40;

  final int itemCount;

  /// Available horizontal space in logical pixels.
  final double width;

  /// Logical pixels occupied by one data slot at the current zoom level.
  final double itemExtent;
  final double minItemExtent;
  final double maxItemExtent;

  /// Number of data slots between the visible right edge and the latest edge.
  final double scrollOffsetItems;

  double get visibleItemCapacity => width / itemExtent;

  double get maxScrollOffsetItems => _maximumScrollOffsetItems(
        itemCount: itemCount,
        width: width,
        itemExtent: itemExtent,
      );

  bool get isAtLatest => scrollOffsetItems == 0;
  bool get isAtOldest => scrollOffsetItems == maxScrollOffsetItems;

  VisibleIndexRange get visibleRange {
    if (itemCount == 0 || width == 0) {
      return const VisibleIndexRange.empty();
    }

    final right = itemCount - scrollOffsetItems;
    final left = right - visibleItemCapacity;
    final start = left.floor().clamp(0, itemCount);
    final end = right.ceil().clamp(0, itemCount);
    return VisibleIndexRange(start, end);
  }

  /// Returns a normalized copy after changing any viewport input.
  ChartViewport copyWith({
    int? itemCount,
    double? width,
    double? itemExtent,
    double? minItemExtent,
    double? maxItemExtent,
    double? scrollOffsetItems,
  }) =>
      ChartViewport(
        itemCount: itemCount ?? this.itemCount,
        width: width ?? this.width,
        itemExtent: itemExtent ?? this.itemExtent,
        minItemExtent: minItemExtent ?? this.minItemExtent,
        maxItemExtent: maxItemExtent ?? this.maxItemExtent,
        scrollOffsetItems: scrollOffsetItems ?? this.scrollOffsetItems,
      );

  ChartViewport scrollByItems(double delta) {
    if (!delta.isFinite) {
      throw ArgumentError.value(delta, 'delta', 'Must be finite.');
    }
    return copyWith(scrollOffsetItems: scrollOffsetItems + delta);
  }

  ChartViewport zoomTo(double extent) => copyWith(itemExtent: extent);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartViewport &&
          itemCount == other.itemCount &&
          width == other.width &&
          itemExtent == other.itemExtent &&
          minItemExtent == other.minItemExtent &&
          maxItemExtent == other.maxItemExtent &&
          scrollOffsetItems == other.scrollOffsetItems;

  @override
  int get hashCode => Object.hash(
        itemCount,
        width,
        itemExtent,
        minItemExtent,
        maxItemExtent,
        scrollOffsetItems,
      );

  @override
  String toString() => 'ChartViewport(itemCount: $itemCount, width: $width, '
      'itemExtent: $itemExtent, scrollOffsetItems: $scrollOffsetItems)';
}

void _validate({
  required int itemCount,
  required double width,
  required double itemExtent,
  required double minItemExtent,
  required double maxItemExtent,
  required double scrollOffsetItems,
}) {
  if (itemCount < 0) {
    throw ArgumentError.value(itemCount, 'itemCount', 'Must not be negative.');
  }
  if (!width.isFinite || width < 0) {
    throw ArgumentError.value(
      width,
      'width',
      'Must be finite and non-negative.',
    );
  }
  if (!minItemExtent.isFinite || minItemExtent <= 0) {
    throw ArgumentError.value(
      minItemExtent,
      'minItemExtent',
      'Must be finite and positive.',
    );
  }
  if (!maxItemExtent.isFinite || maxItemExtent < minItemExtent) {
    throw ArgumentError.value(
      maxItemExtent,
      'maxItemExtent',
      'Must be finite and at least minItemExtent.',
    );
  }
  if (!itemExtent.isFinite || itemExtent <= 0) {
    throw ArgumentError.value(
      itemExtent,
      'itemExtent',
      'Must be finite and positive.',
    );
  }
  if (!scrollOffsetItems.isFinite) {
    throw ArgumentError.value(
      scrollOffsetItems,
      'scrollOffsetItems',
      'Must be finite.',
    );
  }
}

double _maximumScrollOffsetItems({
  required int itemCount,
  required double width,
  required double itemExtent,
}) {
  final maximum = itemCount - width / itemExtent;
  return maximum > 0 ? maximum : 0;
}

double _clamp(double value, double minimum, double maximum) {
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return value;
}
