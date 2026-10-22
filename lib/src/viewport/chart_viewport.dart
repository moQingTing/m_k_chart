import 'visible_index_range.dart';

/// 单个图表实例拥有的不可变导航状态。
///
/// 横向滚动以数据槽位而非像素计量。[scrollOffsetItems] 表示距最新边缘的距离：零值使
/// 最新数据保持在可选 [trailingPaddingItems] 之前；正值查看历史；负值展示配置的未来空白区。
///
/// 视口不持有 Widget 或渲染状态。手势层把像素换算为槽位后创建新视口，渲染层再通过
/// [ChartXTransform] 做反向坐标转换，因此缩放、数据刷新与重绘可彼此独立。
final class ChartViewport {
  factory ChartViewport({
    int itemCount = 0,
    double width = 0,
    double itemExtent = defaultItemExtent,
    double minItemExtent = defaultMinItemExtent,
    double maxItemExtent = defaultMaxItemExtent,
    double trailingPaddingItems = 0,
    double futurePaddingItems = 0,
    double scrollOffsetItems = 0,
  }) {
    _validate(
      itemCount: itemCount,
      width: width,
      itemExtent: itemExtent,
      minItemExtent: minItemExtent,
      maxItemExtent: maxItemExtent,
      trailingPaddingItems: trailingPaddingItems,
      futurePaddingItems: futurePaddingItems,
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
      futurePaddingItems: futurePaddingItems,
      scrollOffsetItems: _clamp(
        scrollOffsetItems,
        -futurePaddingItems,
        maximum,
      ),
    );
  }

  const ChartViewport.initial()
      : itemCount = 0,
        width = 0,
        itemExtent = defaultItemExtent,
        minItemExtent = defaultMinItemExtent,
        maxItemExtent = defaultMaxItemExtent,
        trailingPaddingItems = 0,
        futurePaddingItems = 0,
        scrollOffsetItems = 0;

  const ChartViewport._({
    required this.itemCount,
    required this.width,
    required this.itemExtent,
    required this.minItemExtent,
    required this.maxItemExtent,
    required this.trailingPaddingItems,
    required this.futurePaddingItems,
    required this.scrollOffsetItems,
  });

  static const double defaultItemExtent = 8;
  static const double defaultMinItemExtent = 2;
  static const double defaultMaxItemExtent = 40;

  final int itemCount;

  /// 绘图区域可用的水平逻辑像素宽度，不含右侧价格坐标轴。
  final double width;

  /// 当前缩放级别下一条数据槽位占用的逻辑像素。
  final double itemExtent;
  final double minItemExtent;
  final double maxItemExtent;

  /// 最新数据后的虚拟槽位数量。
  ///
  /// 这复现旧图表的 `marginRight` 行为，同时不缩小绘图区、网格或价格坐标轴几何。
  final double trailingPaddingItems;

  /// 允许越过最新边缘继续展示的额外虚拟槽位。
  ///
  /// 与 [trailingPaddingItems] 不同，它不改变默认最新位置；只允许从
  /// `scrollOffsetItems == 0` 继续拖到 [minScrollOffsetItems]，使宿主既能保留正常
  /// 右侧间距，又能让最新 K 线被拖至左侧。
  final double futurePaddingItems;

  /// 相对“带尾部留白的最新位置”的数据槽位偏移。
  final double scrollOffsetItems;

  double get minScrollOffsetItems => -futurePaddingItems;

  double get visibleItemCapacity => width / itemExtent;

  /// 视口左边缘的连续数据槽位坐标。
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
  bool get isAtFutureLimit => scrollOffsetItems == minScrollOffsetItems;
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
    double? futurePaddingItems,
    double? scrollOffsetItems,
  }) =>
      ChartViewport(
        itemCount: itemCount ?? this.itemCount,
        width: width ?? this.width,
        itemExtent: itemExtent ?? this.itemExtent,
        minItemExtent: minItemExtent ?? this.minItemExtent,
        maxItemExtent: maxItemExtent ?? this.maxItemExtent,
        trailingPaddingItems: trailingPaddingItems ?? this.trailingPaddingItems,
        futurePaddingItems: futurePaddingItems ?? this.futurePaddingItems,
        scrollOffsetItems: scrollOffsetItems ?? this.scrollOffsetItems,
      );

  ChartViewport scrollByItems(double delta) {
    if (!delta.isFinite) {
      throw ArgumentError.value(delta, 'delta', 'Must be finite.');
    }
    // 统一走构造函数的边界收敛，调用方无需自行处理历史端或未来端的夹取。
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
          futurePaddingItems == other.futurePaddingItems &&
          scrollOffsetItems == other.scrollOffsetItems;

  @override
  int get hashCode => Object.hash(
        itemCount,
        width,
        itemExtent,
        minItemExtent,
        maxItemExtent,
        trailingPaddingItems,
        futurePaddingItems,
        scrollOffsetItems,
      );

  @override
  String toString() => 'ChartViewport(itemCount: $itemCount, width: $width, '
      'itemExtent: $itemExtent, trailingPaddingItems: $trailingPaddingItems, '
      'futurePaddingItems: $futurePaddingItems, '
      'scrollOffsetItems: $scrollOffsetItems)';
}

void _validate({
  required int itemCount,
  required double width,
  required double itemExtent,
  required double minItemExtent,
  required double maxItemExtent,
  required double trailingPaddingItems,
  required double futurePaddingItems,
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
  if (!futurePaddingItems.isFinite || futurePaddingItems < 0) {
    throw ArgumentError.value(
      futurePaddingItems,
      'futurePaddingItems',
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
