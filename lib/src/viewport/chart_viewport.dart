import 'visible_index_range.dart';

/// Immutable navigation state owned by one chart instance.
///
/// Horizontal scrolling is measured in data slots instead of pixels.
/// [scrollOffsetItems] is the distance from the latest edge: zero keeps the
/// newest item before the optional [trailingPaddingItems], while positive
/// values move toward history.
/// Pixel/data coordinate conversion is intentionally deferred to P4-02.
final class ChartViewport {
  factory ChartViewport({
    int itemCount = 0,
    double width = 0,
    double itemExtent = defaultItemExtent,
    double minItemExtent = defaultMinItemExtent,
    double maxItemExtent = defaultMaxItemExtent,
    double trailingPaddingItems = 0,
    double scrollOffsetItems = 0,
  }) {
    _validate(
      itemCount: itemCount,
      width: width,
      itemExtent: itemExtent,
      minItemExtent: minItemExtent,
      maxItemExtent: maxItemExtent,
      trailingPaddingItems: trailingPaddingItems,
      scrollOffsetItems: scrollOffsetItems,
    );
    final boundedExtent = _clamp(itemExtent, minItemExtent, maxItemExtent);
    final maximum = _maximumScrollOffsetItems(
      itemCount: itemCount,
      width: width,
      itemExtent: boundedExtent,
      trailingPaddingItems: trailingPaddingItems,
    );
    return ChartViewport._(
      itemCount: itemCount,
      width: width,
      itemExtent: boundedExtent,
      minItemExtent: minItemExtent,
      maxItemExtent: maxItemExtent,
      trailingPaddingItems: trailingPaddingItems,
      scrollOffsetItems: _clamp(scrollOffsetItems, 0, maximum),
    );
  }

  const ChartViewport.initial()
      : itemCount = 0,
        width = 0,
        itemExtent = defaultItemExtent,
        minItemExtent = defaultMinItemExtent,
        maxItemExtent = defaultMaxItemExtent,
        trailingPaddingItems = 0,
        scrollOffsetItems = 0;

  const ChartViewport._({
    required this.itemCount,
    required this.width,
    required this.itemExtent,
    required this.minItemExtent,
    required this.maxItemExtent,
    required this.trailingPaddingItems,
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

  /// Virtual data slots after the newest item.
  ///
  /// This reproduces the legacy chart's `marginRight` behavior without
  /// shrinking the plot, grid, or value-axis geometry.
  final double trailingPaddingItems;

  /// Data-slot distance shifted away from the latest padded alignment.
  final double scrollOffsetItems;

  double get visibleItemCapacity => width / itemExtent;

  /// Continuous data-slot coordinate at the left edge of the viewport.
  double get visibleLeftDataPosition =>
      visibleRightDataPosition - visibleItemCapacity;

  /// Continuous data-slot coordinate at the right edge of the viewport.
  double get visibleRightDataPosition =>
      itemCount + trailingPaddingItems - scrollOffsetItems;

  double get maxScrollOffsetItems => _maximumScrollOffsetItems(
        itemCount: itemCount,
        width: width,
        itemExtent: itemExtent,
        trailingPaddingItems: trailingPaddingItems,
      );

  bool get isAtLatest => scrollOffsetItems == 0;
  bool get isAtOldest => scrollOffsetItems == maxScrollOffsetItems;

  VisibleIndexRange get visibleRange {
    if (itemCount == 0 || width == 0) {
      return const VisibleIndexRange.empty();
    }

    final start = visibleLeftDataPosition.floor().clamp(0, itemCount);
    final end = visibleRightDataPosition.ceil().clamp(0, itemCount);
    return VisibleIndexRange(start, end);
  }

  /// Returns a normalized copy after changing any viewport input.
  ChartViewport copyWith({
    int? itemCount,
    double? width,
    double? itemExtent,
    double? minItemExtent,
    double? maxItemExtent,
    double? trailingPaddingItems,
    double? scrollOffsetItems,
  }) =>
      ChartViewport(
        itemCount: itemCount ?? this.itemCount,
        width: width ?? this.width,
        itemExtent: itemExtent ?? this.itemExtent,
        minItemExtent: minItemExtent ?? this.minItemExtent,
        maxItemExtent: maxItemExtent ?? this.maxItemExtent,
        trailingPaddingItems: trailingPaddingItems ?? this.trailingPaddingItems,
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
          trailingPaddingItems == other.trailingPaddingItems &&
          scrollOffsetItems == other.scrollOffsetItems;

  @override
  int get hashCode => Object.hash(
        itemCount,
        width,
        itemExtent,
        minItemExtent,
        maxItemExtent,
        trailingPaddingItems,
        scrollOffsetItems,
      );

  @override
  String toString() => 'ChartViewport(itemCount: $itemCount, width: $width, '
      'itemExtent: $itemExtent, trailingPaddingItems: $trailingPaddingItems, '
      'scrollOffsetItems: $scrollOffsetItems)';
}

void _validate({
  required int itemCount,
  required double width,
  required double itemExtent,
  required double minItemExtent,
  required double maxItemExtent,
  required double trailingPaddingItems,
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
  if (!trailingPaddingItems.isFinite || trailingPaddingItems < 0) {
    throw ArgumentError.value(
      trailingPaddingItems,
      'trailingPaddingItems',
      'Must be finite and non-negative.',
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
  required double trailingPaddingItems,
}) {
  final maximum = itemCount + trailingPaddingItems - width / itemExtent;
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
