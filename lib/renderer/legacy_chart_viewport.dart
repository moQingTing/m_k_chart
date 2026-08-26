/// Immutable geometry derived from the legacy chart's viewport inputs.
///
/// It has no Canvas or Widget dependency so interaction code can derive scroll
/// bounds and a selected item before a Painter is invoked.
final class LegacyChartViewportMetrics {
  const LegacyChartViewportMetrics._({
    required this.itemCount,
    required this.width,
    required this.scaleX,
    required this.pointWidth,
    required this.marginRight,
    required this.minTranslateX,
  });

  factory LegacyChartViewportMetrics({
    required int itemCount,
    required double width,
    required double scaleX,
    required double pointWidth,
  }) {
    if (itemCount <= 0 || width <= 0 || scaleX <= 0 || pointWidth <= 0) {
      return LegacyChartViewportMetrics._(
        itemCount: itemCount < 0 ? 0 : itemCount,
        width: width < 0 ? 0 : width,
        scaleX: scaleX <= 0 ? 1 : scaleX,
        pointWidth: pointWidth <= 0 ? 1 : pointWidth,
        marginRight: 0,
        minTranslateX: 0,
      );
    }

    var marginRight = (width / 5 - pointWidth) / scaleX;
    final dataLength = itemCount * pointWidth;
    var minTranslateX = -dataLength + width / scaleX - pointWidth / 2;
    minTranslateX = minTranslateX >= 0 ? 0 : minTranslateX;
    final lastCenter = itemCount * pointWidth + pointWidth / 2;
    if (minTranslateX >= 0) {
      if (width / scaleX - lastCenter < marginRight) {
        minTranslateX -= marginRight - width / scaleX + lastCenter;
      } else {
        marginRight = width / scaleX - lastCenter;
      }
    } else {
      minTranslateX -= marginRight;
    }
    minTranslateX = minTranslateX >= 0 ? 0 : minTranslateX;
    return LegacyChartViewportMetrics._(
      itemCount: itemCount,
      width: width,
      scaleX: scaleX,
      pointWidth: pointWidth,
      marginRight: marginRight,
      minTranslateX: minTranslateX,
    );
  }

  final int itemCount;
  final double width;
  final double scaleX;
  final double pointWidth;
  final double marginRight;
  final double minTranslateX;

  double get maxScrollX => minTranslateX.abs();

  double clampScrollX(double value) => value.clamp(0.0, maxScrollX).toDouble();

  int selectedIndex({
    required double localX,
    required double scrollX,
  }) {
    if (itemCount == 0) {
      return 0;
    }
    final translateX = scrollX + minTranslateX;
    final chartX = -translateX + localX / scaleX;
    final index = ((chartX - pointWidth / 2) / pointWidth).round();
    return index.clamp(0, itemCount - 1);
  }

  double localXForIndex(int index, {required double scrollX}) =>
      ((index * pointWidth + pointWidth / 2) +
          (clampScrollX(scrollX) + minTranslateX)) *
      scaleX;
}
