import '../viewport/viewport.dart';
import 'chart_history_paging_state.dart';
import 'chart_ohlc_snapper.dart';

sealed class ChartInteractionIntent {
  const ChartInteractionIntent();
}

/// Immutable crosshair payload stored in the selection state slice.
final class ChartCrosshairState {
  const ChartCrosshairState.visible({
    required this.localX,
    required this.localY,
    this.dataIndex,
    this.price,
    this.ohlcField,
  })  : assert(dataIndex == null || dataIndex >= 0),
        assert(
          (dataIndex == null && price == null && ohlcField == null) ||
              (dataIndex != null && price != null && ohlcField != null),
        ),
        isVisible = true;

  const ChartCrosshairState.hidden()
      : isVisible = false,
        localX = 0,
        localY = 0,
        dataIndex = null,
        price = null,
        ohlcField = null;

  final bool isVisible;
  final double localX;
  final double localY;
  final int? dataIndex;
  final double? price;
  final ChartOhlcField? ohlcField;

  bool get isSnapped => dataIndex != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartCrosshairState &&
          isVisible == other.isVisible &&
          localX == other.localX &&
          localY == other.localY &&
          dataIndex == other.dataIndex &&
          price == other.price &&
          ohlcField == other.ohlcField;

  @override
  int get hashCode =>
      Object.hash(isVisible, localX, localY, dataIndex, price, ohlcField);
}

/// 视口变更的来源。不能通过缩放宽度是否相等推断：首次宽度可能尚未初始化，
/// 而达到缩放边界时，双指焦点移动仍可能只改变滚动偏移。
enum ChartViewportChangeSource { programmatic, pan, scale, inertia }

/// 请求替换不可变视口，同时保留产生此变更的交互语义。
final class ChartViewportIntent extends ChartInteractionIntent {
  const ChartViewportIntent(
    this.viewport, {
    this.source = ChartViewportChangeSource.programmatic,
  });

  final ChartViewport viewport;
  final ChartViewportChangeSource source;

  /// 主动浏览（包括松手后的惯性）取消点击选中；缩放和程序更新由宿主单独处理。
  bool get isHorizontalNavigation =>
      source == ChartViewportChangeSource.pan ||
      source == ChartViewportChangeSource.inertia;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartViewportIntent &&
          viewport == other.viewport &&
          source == other.source;

  @override
  int get hashCode => Object.hash(viewport, source);
}

/// Shows, moves, or hides a crosshair in chart-local coordinates.
final class ChartCrosshairIntent extends ChartInteractionIntent {
  const ChartCrosshairIntent.show({
    required this.localX,
    required this.localY,
    this.dataIndex,
    this.price,
    this.ohlcField,
  })  : assert(dataIndex == null || dataIndex >= 0),
        assert(
          (dataIndex == null && price == null && ohlcField == null) ||
              (dataIndex != null && price != null && ohlcField != null),
        ),
        isActive = true;

  ChartCrosshairIntent.snapped(ChartOhlcSnapResult result)
      : isActive = true,
        localX = result.localX,
        localY = result.localY,
        dataIndex = result.dataIndex,
        price = result.price,
        ohlcField = result.field;

  const ChartCrosshairIntent.hide()
      : isActive = false,
        localX = 0,
        localY = 0,
        dataIndex = null,
        price = null,
        ohlcField = null;

  final bool isActive;
  final double localX;
  final double localY;
  final int? dataIndex;
  final double? price;
  final ChartOhlcField? ohlcField;

  ChartCrosshairState get state => isActive
      ? ChartCrosshairState.visible(
          localX: localX,
          localY: localY,
          dataIndex: dataIndex,
          price: price,
          ohlcField: ohlcField,
        )
      : const ChartCrosshairState.hidden();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartCrosshairIntent &&
          isActive == other.isActive &&
          localX == other.localX &&
          localY == other.localY &&
          dataIndex == other.dataIndex &&
          price == other.price &&
          ohlcField == other.ohlcField;

  @override
  int get hashCode =>
      Object.hash(isActive, localX, localY, dataIndex, price, ohlcField);
}

/// Publishes a loading/no-more/failure transition for historical pagination.
final class ChartHistoryPagingIntent extends ChartInteractionIntent {
  const ChartHistoryPagingIntent(this.state);

  final ChartHistoryPagingState state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartHistoryPagingIntent && state == other.state;

  @override
  int get hashCode => state.hashCode;
}
