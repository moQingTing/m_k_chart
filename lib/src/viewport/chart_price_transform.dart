/// 价格与图表局部 Y 坐标之间的不可变纵向转换器。
///
/// 局部 Y 向下递增：[maxPrice] 映射到 [top]，[minPrice] 映射到 [bottom]。可见价格范围
/// 外的值仍按比例外推，使调用方在渲染边界统一裁剪覆盖物。
final class ChartPriceTransform {
  factory ChartPriceTransform({
    required double minPrice,
    required double maxPrice,
    required double top,
    required double bottom,
  }) {
    _validateFinite(minPrice, 'minPrice');
    _validateFinite(maxPrice, 'maxPrice');
    _validateFinite(top, 'top');
    _validateFinite(bottom, 'bottom');
    if (maxPrice <= minPrice) {
      throw ArgumentError.value(
        maxPrice,
        'maxPrice',
        'Must be greater than minPrice.',
      );
    }
    if (bottom <= top) {
      throw ArgumentError.value(
        bottom,
        'bottom',
        'Must be greater than top.',
      );
    }
    return ChartPriceTransform._(
      minPrice: minPrice,
      maxPrice: maxPrice,
      top: top,
      bottom: bottom,
    );
  }

  const ChartPriceTransform._({
    required this.minPrice,
    required this.maxPrice,
    required this.top,
    required this.bottom,
  });

  final double minPrice;
  final double maxPrice;
  final double top;
  final double bottom;

  double get height => bottom - top;
  double get priceSpan => maxPrice - minPrice;

  double priceToLocalY(double price) {
    _validateFinite(price, 'price');
    return top + (maxPrice - price) / priceSpan * height;
  }

  double localYToPrice(double localY) {
    _validateFinite(localY, 'localY');
    return maxPrice - (localY - top) / height * priceSpan;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPriceTransform &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          top == other.top &&
          bottom == other.bottom;

  @override
  int get hashCode => Object.hash(minPrice, maxPrice, top, bottom);
}

void _validateFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}
